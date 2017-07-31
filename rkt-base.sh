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

export DEBOOTSTRAP=/usr/sbin/debootstrap

export ACI_ARCH='amd64'
export ACI_AUTHOR='TAQTIQA LLC'
export ACI_RELEASE='hardy' # NB: Lower case - this is case sensitive
export ACI_EMAIL='coders@taqtiqa.com'

export CI_PACKAGE_MIRROR='http://old-releases.ubuntu.com/ubuntu' # http://archive.ubuntu.com/ubuntu

export CI_ARTIFACTS_DIR="/tmp/${ACI_RELEASE}"

export DEFAULT_BUILD_ARCH='amd64'
export DEFAULT_BUILD_VERSION='0.0.0-0'
export DEFAULT_COMPONENTS='main,universe,multiverse,restricted'
export DEFAULT_GUEST_PACKAGES='apt-utils,language-pack-en,ubuntu-keyring,debian-archive-keyring'
export DEFAULT_GUEST_PACKAGE_MIRROR='http://archive.ubuntu.com/ubuntu' #'http://old-releases.ubuntu.com/ubuntu'
export DEFAULT_HOST_PACKAGE_MIRROR='http://archive.ubuntu.com/ubuntu'
export DEFAULT_VARIANT='minbase'
export DEFAULT_ROOTFS='/tmp/rootfs'
export DEFAULT_RELEASE='hardy'
export DEFAULT_BUILD_ARTIFACTS_DIR=${CI_ARTIFACTS_DIR:-'/tmp/artifacts'}
export DEFAULT_SLUG='example.com/image-name'
export DEFAULT_ORG=$(dirname ${DEFAULT_SLUG})
export DEFAULT_ACI_NAME=$(basename ${DEFAULT_SLUG})  #: r,littler,rserver no packages installed rkt-rrr-tidy: r,littler,rserver recommends and tidy packages, rkt-rrr-devel: r,littler,rserver recommends and tidy devel environment
export DEFAULT_BUILD_ARTIFACTS_DIR=${CI_ARTIFACTS_DIR:-'/tmp/release'}
export DEFAULT_BUILD_EMAIL='no-reply@example.com'
export DEFAULT_BUILD_AUTHOR='Example LLC'

export ROOTFS=${1:-${DEFAULT_ROOTFS}}

export CI_BUILD_VERSION=${TRAVIS_TAG:-${DEFAULT_BUILD_VERSION}}
export CI_SLUG=${TRAVIS_REPO_SLUG:-${DEFAULT_SLUG}}

export ACI_NAME=$(basename ${CI_SLUG})  #: r,littler,rserver no packages installed rkt-rrr-tidy: r,littler,rserver recommends and tidy packages, rkt-rrr-devel: r,littler,rserver recommends and tidy devel environment
export ACI_ORG=$(dirname ${CI_SLUG})

export BUILD_ARCH=${ACI_ARCH:-${DEFAULT_BUILD_ARCH}}
export BUILD_ACI_NAME=${ACI_NAME:-${DEFAULT_ACI_NAME}}
export BUILD_ARTIFACTS_DIR=${CI_ARTIFACTS_DIR:-${DEFAULT_BUILD_ARTIFACTS_DIR}}
export BUILD_AUTHOR=${ACI_AUTHOR:-${DEFAULT_BUILD_AUTHOR}}
export BUILD_COMPONENTS=${ACI_COMPONENTS:-${DEFAULT_COMPONENTS}}
export BUILD_EMAIL=${ACI_EMAIL:-${DEFAULT_BUILD_EMAIL}}
export BUILD_ORG=${ACI_ORG:-${DEFAULT_ORG}}
export BUILD_RELEASE=${ACI_RELEASE:-${DEFAULT_RELEASE}}
export BUILD_GUEST_PACKAGES=${ACI_PACKAGES:-${DEFAULT_GUEST_PACKAGES}}
export BUILD_GUEST_PACKAGE_MIRROR=${CI_PACKAGE_MIRROR:-${DEFAULT_GUEST_PACKAGE_MIRROR}}
export BUILD_VERSION=${CI_BUILD_VERSION:-${DEFAULT_BUILD_VERSION}}
export BUILD_DATE=${BUILD_DATE:-$(date --utc +%FT%TZ)} # ISO8601
export BUILD_SLUG=${DEFAULT_SLUG}
export BUILD_VARIANT=${ACI_VARIANT:-${DEFAULT_VARIANT}}
export BUILD_RELEASE=${ACI_RELEASE:-${DEFAULT_RELEASE}}

export BUILD_FILE=${BUILD_ACI_NAME}-${BUILD_VERSION}-linux-${BUILD_ARCH}.aci
export BUILD_ARTIFACTS_DIR='.'
export BUILD_ARTIFACT=${BUILD_ARTIFACTS_DIR}/${BUILD_FILE}

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LANG=C  # https://serverfault.com/questions/350876/setlocale-error-with-chroot
export TERM=linux
export DEBIAN_FRONTEND='noninteractive'

export ACBUILD='/bin/acbuild --debug'
export ACBUILD_RUN="/bin/acbuild-chroot --chroot ${ROOTFS} --working-dir /tmp"

export BUILD_NAME="${BUILD_ORG}/${BUILD_ACI_NAME}"

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
  #${ACBUILD}  end
  #[[ $? -ne 0 ]] && exit $? # Exit if non-zero exit code
}

function buildcleanup() {
  # Dismount order matters
  rry=("${ROOTFS}/dev/pts" "${ROOTFS}/proc" "${ROOTFS}/sys" "${ROOTFS}/dev" )
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

do_first () {
  echo "Prove..."
  trap "do_third" EXIT
  source ./scripts/build-rootfs.sh
  do_third
}
#do_second () {
#  echo "ho lanciato il secondo"
#  trap "do_third" EXIT
#  source ./third.sh
#  do_third
#}
do_third () {
  trap "buildend" EXIT
  #trap - EXIT
  echo "... we get here?"
}

trap "buildend" ERR

#if [[ -d ${ROOTFS} ]]; then
#  echo "Remove existing rootfs directory"
#  rm -rf ${ROOTFS}
#fi

if [ "$EUID" -ne 0 ]; then
  echo "This script uses functionality which requires root privileges"
  exit 1
fi

type ${DEBOOTSTRAP} >/dev/null
if [ $? -ne 0 ]; then
  echo "debootstrap not installed"
  exit 1
fi

#(source ./scripts/build-rootfs.sh)
#do_first
if [[ ! -d ${ROOTFS} ]]; then
  ${DEBOOTSTRAP} --include ${BUILD_GUEST_PACKAGES} --components ${BUILD_COMPONENTS} --variant ${BUILD_VARIANT} ${BUILD_RELEASE} ${ROOTFS} ${BUILD_GUEST_PACKAGE_MIRROR}

  cat << EOF > ${ROOTFS}/etc/apt/sources.list
## Uncomment the following two lines to fetch updated software from the network
deb ${BUILD_GUEST_PACKAGE_MIRROR} ${BUILD_RELEASE} main restricted
deb-src ${BUILD_GUEST_PACKAGE_MIRROR} ${BUILD_RELEASE} main restricted

deb ${BUILD_GUEST_PACKAGE_MIRROR} ${BUILD_RELEASE}-updates main restricted
deb-src ${BUILD_GUEST_PACKAGE_MIRROR} ${BUILD_RELEASE}-updates main restricted

deb ${BUILD_GUEST_PACKAGE_MIRROR} ${BUILD_RELEASE} universe
deb-src ${BUILD_GUEST_PACKAGE_MIRROR} ${BUILD_RELEASE} universe

deb ${BUILD_GUEST_PACKAGE_MIRROR} ${BUILD_RELEASE}-security main restricted
deb-src ${BUILD_GUEST_PACKAGE_MIRROR} ${BUILD_RELEASE}-security main restricted

deb ${BUILD_GUEST_PACKAGE_MIRROR} ${BUILD_RELEASE}-security universe
deb-src ${BUILD_GUEST_PACKAGE_MIRROR} ${BUILD_RELEASE}-security universe

deb ${BUILD_GUEST_PACKAGE_MIRROR} ${BUILD_RELEASE} multiverse
deb-src ${BUILD_GUEST_PACKAGE_MIRROR} ${BUILD_RELEASE} multiverse

deb ${BUILD_GUEST_PACKAGE_MIRROR} ${BUILD_RELEASE}-backports main restricted universe multiverse

# PPA repositories without having to install more cruft
deb http://ppa.launchpad.net/dns/gnu/ubuntu ${BUILD_RELEASE} main
deb-src http://ppa.launchpad.net/dns/gnu/ubuntu ${BUILD_RELEASE} main
EOF

  cat << EOF > ${ROOTFS}/etc/apt/apt.conf.d/01lean
APT::Install-Suggests "0";
APT::Install-Recommends "0";
APT::AutoRemove::SuggestsImportant "false";
APT::AutoRemove::RecommendsImportant "false";
APT::Get::Assume-Yes "true";
APT::Get::Show-Upgraded "true";
APT::Quiet "true";
DPkg::Options {"--force-confdef";"--force-confmiss";"--force-confold"};
DPkg::Pre-Install-Pkgs {"/usr/sbin/dpkg-preconfigure --apt";};
Dir::Etc::SourceList "/etc/apt/sources.list";
EOF

  # Consider using schroot if build trouble persists
  # https://github.com/neurodebian/travis-chroots/blob/master/tools/travis_chroot
  ##if [[ ! -z "${CI}" ]]; then
  #  echo "Mounting /proc in chroot... "
  #  if [ ! -d "${ROOTFS}/proc" ] ; then
  #      mkdir -p ${ROOTFS}/proc
  #      echo "Created ${ROOTFS}/proc"
  #  fi
  #  mount -t proc -o nosuid,noexec,nodev proc ${ROOTFS}/proc
  #  echo "OK"
  #  echo "Mounting /sys in chroot... "
  #  if [ ! -d "${ROOTFS}/sys" ] ; then
  #      mkdir -p ${ROOTFS}/sys
  #      echo "Created ${ROOTFS}/sys"
  #  fi
  #  mount -t sysfs -o nosuid,noexec,nodev sysfs ${ROOTFS}/sys
  #  echo "OK"
  #  echo "Mounting /dev/ and /dev/pts in chroot... "
  #    mkdir -p -m 755 ${ROOTFS}/dev/pts
  #    mount -t devtmpfs -o mode=0755,nosuid devtmpfs ${ROOTFS}/dev
  #    mount -t devpts -o gid=5,mode=620 devpts ${ROOTFS}/dev/pts
  #  echo "OK"
  ##fi

  # Do not mount dev/pts until to this issue is resolved
  # ISSUE:
  # https://github.com/travis-ci/travis-ci/issues/8187
  #
  #dev/pts should be mounted last
  for i in dev proc sys
  do
      mount -o bind /$i ${ROOTFS}/$i
  done
  chroot ${ROOTFS} echo 'debconf debconf/frontend select Noninteractive' | chroot ${ROOTFS} debconf-set-selections
  chroot ${ROOTFS} dpkg-reconfigure debconf
  chroot ${ROOTFS} echo "en_US.UTF-8 UTF-8" >>/etc/locale.gen
  chroot ${ROOTFS} dpkg-reconfigure locales
  chroot ${ROOTFS} apt-key adv --keyserver keyserver.ubuntu.com --recv-keys B187F352479B857B
  chroot ${ROOTFS} apt-get -qq update
  chroot ${ROOTFS} apt-get -y dist-upgrade
  chroot ${ROOTFS} apt-get --purge -y autoremove
  chroot ${ROOTFS} apt-get --purge -y autoremove
  chroot ${ROOTFS} apt-get clean
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
  for i in proc sys dev
  do
      if mountpoint -q "${ROOTFS}/${i}"; then
        echo "${ROOTFS}/${i} is a mountpoint"
        umount -lf ${ROOTFS}/$i
        #rm -rf ${ROOTFS}/$i
      else
        echo "${ROOTFS}/${i} is not a mountpoint"
      fi
  done
fi

echo "Finished ${BUILD_RELEASE} rootfs build."

echo 'Display installed acbuild version'
${ACBUILD} version

# Start the build with ACI bootstrapped above
${ACBUILD} begin ${ROOTFS}

# Name the ACI
${ACBUILD} set-name ${BUILD_NAME}

# Based on TAQTIQA Linux base image of Ubuntu (~53 MB)
# rkt trust --prefix=taqtiqa.io/rkt-base
#${ACBUILD} dep add taqtiqa.io/rkt-base:0.0.0-0

${ACBUILD} label add version ${BUILD_VERSION}
${ACBUILD} label add arch amd64
${ACBUILD} label add os linux
${ACBUILD} annotation add authors "${BUILD_AUTHOR} <${BUILD_EMAIL}>"

${ACBUILD} set-user 0
${ACBUILD} set-group 0
${ACBUILD} environment add OS_VERSION ${BUILD_RELEASE}

echo "Write the Container Image..."
${ACBUILD} write --overwrite ${BUILD_ARTIFACT}
echo "Created Container Image ${BUILD_ARTIFACT}."

echo "Sign the Container Image..."
./scripts/sign.sh ${BUILD_ARTIFACT}
echo "Signed the Container Image..."

${ACBUILD} end