#!/usr/bin/env bash
#
# Copyright (C) 2017 TAQTIQA LLC. <http://www.taqtiqa.com>
#
#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU Affero General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.
#
#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#
#You should have received a copy of the GNU Affero General Public License v3
#along with this program.
#If not, see <https://www.gnu.org/licenses/agpl-3.0.en.html>.
#

# Usage:
#   rkt-base.sh </rootfs/path>
#

set -eoux pipefail

source scripts/build-env.sh

case "${BUILD_RELEASE}" in
  master)
    echo "Do not build ACI release images from ${BUILD_RELEASE}"
    exit 1
    ;;
  hardy|intrepid|jaunty|karmic|lucid|maverick|natty|oneiric|precise|quantal|raring|saucy|trusty|utopic|vivid|wily|xenial|yakkety|zesty|artful )
    echo "Building ACI release ${BUILD_VERSION} from branch: ${BUILD_RELEASE}"
    ;;
  travis)
    echo "Building ACI release ${BUILD_VERSION} from detached head (so no branch information)."
    ;;
  *)
    echo "Do not build ACI release images from unknown branches"
    exit 1
    ;;
esac

case "${BUILD_RELEASE}" in
  trusty|vivid|wily|xenial|yakkety|zesty|artful)
    BUILD_GUEST_PACKAGE_MIRROR='http://archive.ubuntu.com/ubuntu'
    echo "Ubuntu mirror changed via BUILD_GUEST_PACKAGE_MIRROR=${BUILD_GUEST_PACKAGE_MIRROR}"
    ;;
  *)
    echo "Do not build ACI release images from unknown branches"
    ;;
esac


if [[ ${CI} == 'true' ]]; then
  if [[ ${TRAVIS} == 'true' ]];then
    chown travis:travis ~/.gnupg/gpg.conf
    chgrp -R travis ~/.gnupg
    chmod 0600 ~/.gnupg/gpg.conf
  fi
fi

function buildend() {
  export EXIT=$?
  buildcleanup
}

function buildcleanup() {
  # Do not mount dev/pts until to this issue is resolved
  # ISSUE:
  # https://github.com/travis-ci/travis-ci/issues/8187
  # "${ROOTFS}/dev/pts" Dismount order matters

  # Cleanup by dismounting as ACBuild expects us to have.
  # Otherwise $ACBUILD begin ${ROOTFS} complains:
  #
  #  $ begin: build already in progress in this working dir
  #
  # See:
  # - https://github.com/containers/build/issues/167
  # - https://askubuntu.com/questions/551195/scripting-chroot-how-to
  #
  # Do not mount dev/pts until to this issue is resolved
  # ISSUE:
  # https://github.com/travis-ci/travis-ci/issues/8187
  #
  # dev/pts should be dismounted first
  if [[ ${CI} == 'false' ]]; then
    # We are on a desktop so can dismount dev/pts
    if mountpoint -q "${ROOTFS}/dev/pts"; then
      echo "${ROOTFS}/dev/pts is a mountpoint"
      umount -lf ${ROOTFS}/dev/pts
    else
      echo "${ROOTFS}/dev/pts is not a mountpoint"
    fi
  fi
  for i in proc sys dev
  do
      if mountpoint -q "${ROOTFS}/${i}"; then
        echo "${ROOTFS}/${i} is a mountpoint"
        umount -lf ${ROOTFS}/${i}
      else
        echo "${ROOTFS}/${i} is not a mountpoint"
      fi
  done
  rry=( "${ROOTFS}/proc" "${ROOTFS}/sys" "${ROOTFS}/dev" )
  for mp in "${rry[@]}"
  do
    if mountpoint -q "${mp}"; then
      echo "$mp is a mountpoint"
      umount -lf "${mp}"
    else
      echo "${mp} is not a mountpoint"
    fi
  done
}

function check_citool() {
  if hash travis 2>/dev/null; then
    CITOOL=travis
  elif hash circleci 2>/dev/null; then
    CITOOL=cirleci
  else
    echo 'WARNING: No CI tool.  ACI image will not be signed.'
  fi
}

trap "buildend" ERR

if [ "$EUID" -ne 0 ]; then
  echo "This script uses functionality which requires root privileges"
  exit 1
fi

source 'scripts/build-rootfs.sh'

echo 'Display installed acbuild version'
${ACBUILD} version

# Start the build with ACI bootstrapped above
${ACBUILD} begin ${ROOTFS}

# Name the ACI
${ACBUILD} set-name ${BUILD_NAME}

${ACBUILD} label add version ${BUILD_VERSION}
${ACBUILD} label add arch amd64
${ACBUILD} label add os linux
${ACBUILD} annotation add authors "${BUILD_AUTHOR} <${BUILD_EMAIL}>"
${ACBUILD} annotation add created "$( date --rfc-3339=seconds | sed 's/ /T/' )"

${ACBUILD} set-user 0
${ACBUILD} set-group 0
${ACBUILD} environment add OS_VERSION ${BUILD_RELEASE}

echo "Write the Container Image..."
${ACBUILD} write --overwrite ${BUILD_ARTIFACT}
echo "Created Container Image ${BUILD_ARTIFACT}."
${ACBUILD} end

echo "Sign the Container Image..."
./scripts/sign.sh ${BUILD_ARTIFACT}
echo "Signed the Container Image..."

source 'scripts/build-iso.sh'

rm -rf image