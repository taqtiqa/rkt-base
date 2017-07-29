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

DEBOOTSTRAP=/usr/sbin/debootstrap

ACI_ARCH='amd64'
ACI_AUTHOR='TAQTIQA LLC'
ACI_RELEASE='hardy' # NB: Lower case - this is case sensitive
ACI_EMAIL='coders@taqtiqa.com'

CI_PACKAGE_MIRROR='http://old-releases.ubuntu.com/ubuntu' # http://archive.ubuntu.com/ubuntu

CI_ARTIFACTS_DIR="/tmp/${ACI_RELEASE}"

DEFAULT_BUILD_ARCH='amd64'
DEFAULT_BUILD_VERSION='0.0.0-0'
DEFAULT_COMPONENTS='main,universe,multiverse,restricted'
DEFAULT_GUEST_PACKAGES='apt-utils,language-pack-en,ubuntu-keyring,debian-archive-keyring'
DEFAULT_GUEST_PACKAGE_MIRROR='http://archive.ubuntu.com/ubuntu' #'http://old-releases.ubuntu.com/ubuntu'
DEFAULT_HOST_PACKAGE_MIRROR='http://archive.ubuntu.com/ubuntu'
DEFAULT_VARIANT='minbase'
DEFAULT_ROOTFS='/tmp/rootfs'
DEFAULT_RELEASE='hardy'
DEFAULT_BUILD_ARTIFACTS_DIR=${CI_ARTIFACTS_DIR:-'/tmp/artifacts'}
DEFAULT_SLUG=${CI_SLUG:-'example.com/image-name'}
DEFAULT_ORG=$(dirname ${DEFAULT_SLUG})
DEFAULT_ACI_NAME=$(basename ${DEFAULT_SLUG})  #: r,littler,rserver no packages installed rkt-rrr-tidy: r,littler,rserver recommends and tidy packages, rkt-rrr-devel: r,littler,rserver recommends and tidy devel environment
DEFAULT_BUILD_ARTIFACTS_DIR=${CI_ARTIFACTS_DIR:-'/tmp/release'}
DEFAULT_BUILD_EMAIL='no-reply@example.com'
DEFAULT_BUILD_AUTHOR='Example LLC'

ROOTFS=${1:-${DEFAULT_ROOTFS}}
CI_BUILD_VERSION=${TRAVIS_TAG:-${DEFAULT_BUILD_VERSION}}
CI_SLUG=${TRAVIS_REPO_SLUG:-${DEFAULT_SLUG}}

ACI_NAME=$(basename ${CI_SLUG})  #: r,littler,rserver no packages installed rkt-rrr-tidy: r,littler,rserver recommends and tidy packages, rkt-rrr-devel: r,littler,rserver recommends and tidy devel environment
ACI_ORG=$(dirname ${CI_SLUG})

BUILD_ARCH=${ACI_ARCH:-${DEFAULT_BUILD_ARCH}}
BUILD_ACI_NAME=${ACI_NAME:-${DEFAULT_ACI_NAME}}
BUILD_ARTIFACTS_DIR=${CI_ARTIFACTS_DIR:-${DEFAULT_BUILD_ARTIFACTS_DIR}}
BUILD_AUTHOR=${ACI_AUTHOR:-${DEFAULT_BUILD_AUTHOR}}
BUILD_COMPONENTS=${ACI_COMPONENTS:-${DEFAULT_COMPONENTS}}
BUILD_EMAIL=${ACI_EMAIL:-${DEFAULT_BUILD_EMAIL}}
BUILD_ORG=${ACI_ORG:-${DEFAULT_ORG}}
BUILD_RELEASE=${ACI_RELEASE:-${DEFAULT_RELEASE}}
BUILD_GUEST_PACKAGES=${ACI_PACKAGES:-${DEFAULT_GUEST_PACKAGES}}
BUILD_GUEST_PACKAGE_MIRROR=${CI_PACKAGE_MIRROR:-${DEFAULT_GUEST_PACKAGE_MIRROR}}
BUILD_VERSION=${CI_BUILD_VERSION:-${DEFAULT_BUILD_VERSION}}
BUILD_DATE=${BUILD_DATE:-$(date --utc +%FT%TZ)} # ISO8601
BUILD_SLUG=${DEFAULT_SLUG}
BUILD_VARIANT=${ACI_VARIANT:-${DEFAULT_VARIANT}}
BUILD_RELEASE=${ACI_RELEASE:-${DEFAULT_RELEASE}}

BUILD_FILE=${BUILD_ACI_NAME}-${BUILD_VERSION}-linux-${BUILD_ARCH}.aci
BUILD_ARTIFACTS_DIR='.'
BUILD_ARTIFACT=${BUILD_ARTIFACTS_DIR}/${BUILD_FILE}

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LANG=C  # https://serverfault.com/questions/350876/setlocale-error-with-chroot
export TERM=linux
export DEBIAN_FRONTEND='noninteractive'

ACBUILD='/bin/acbuild --debug'
ACBUILD_RUN="/bin/acbuild-chroot --chroot ${ROOTFS} --working-dir /tmp"

BUILD_NAME="${BUILD_ORG}/${BUILD_ACI_NAME}"

function buildend() {
  export EXIT=$?
  buildcleanup
  #${ACBUILD}  end
  exit $EXIT
}

function buildcleanup() {
  # Dismount order matters
  rry=("${ROOTFS}/dev/pts" "${ROOTFS}/dev" "${ROOTFS}/proc" "${ROOTFS}/sys")
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

trap buildend EXIT

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
  for i in dev proc sys dev/pts
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
  #chroot ${ROOTFS} echo 'debconf debconf/frontend select Teletype' | chroot ${ROOTFS} debconf-set-selections
  #chroot ${ROOTFS} dpkg-reconfigure debconf
  # Cleanup as ACBuild expects.  Otherwise $ACBUILD begin ${ROOTFS} complains:
  #   $ begin: build already in progress in this working dir
  # See:
  # - https://github.com/containers/build/issues/167
  # - https://askubuntu.com/questions/551195/scripting-chroot-how-to
  for i in dev/pts proc sys dev
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