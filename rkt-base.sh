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

set -eoux pipefail

ACI_SUITE='hardy' # NB: Lower case - this is case sensitive
ACI_ARTIFACTS_DIR=/tmp/${ACI_SUITE}

DEFAULT_PACKAGES=language-pack-en-base,language-pack-en,ubuntu-keyring,debian-archive-keyring
DEFAULT_COMPONENTS=main,universe,multiverse,restricted
DEBOOTSTRAP=/usr/sbin/debootstrap
DEFAULT_MIRROR=http://old-releases.ubuntu.com/ubuntu
DEFAULT_VARIANT=minbase
DEFAULT_ROOTFS=/tmp/rootfs
DEFAULT_SUITE='xenial'
DEFAULT_BUILD_ARTIFACTS_DIR=/tmp/artifacts

MIRROR=${ACI_MIRROR:-$DEFAULT_MIRROR}
ROOTFS=${1:-$DEFAULT_ROOTFS}
PACKAGES=${ACI_PACKAGES:-$DEFAULT_PACKAGES}
COMPONENTS=${ACI_COMPONENTS:-$DEFAULT_COMPONENTS}
VARIANT=${ACI_VARIANT:-$DEFAULT_VARIANT}
SUITE=${ACI_SUITE:-$DEFAULT_SUITE}

R_VERSION=${R_VERSION:-3.4.1}
version="${R_VERSION}.1"
ACI_NAME_SUFFIX="base"
ACI_NAME="rkt-${ACI_NAME_SUFFIX}" #: r,littler,rserver no packages installed rkt-rrr-tidy: r,littler,rserver recommends and tidy packages, rkt-rrr-devel: r,littler,rserver recommends and tidy devel environment
dist="hardy"
arch="amd64"
mirror="http://archive.ubuntu.com/ubuntu"
out=/tmp/r-aci #$(mktemp -d)

BUILD_AUTHOR="TAQTIQA LLC"
BUILD_EMAIL="coders@taqtiqa.com"
BUILD_ORG="taqtiqa.io"
BUILD_DATE=${BUILD_DATE:-}
BUILD_ARTIFACTS_DIR=${ACI_ARTIFACTS_DIR:-$DEFAULT_BUILD_ARTIFACTS_DIR}
ACI_PREFIX="${BUILD_ORG}/${ACI_NAME}"

LC_ALL=en_US.UTF-8
LANG=en_US.UTF-8
TERM=xterm

ACBUILD='/bin/acbuild --debug'
ACBUILD_RUN="/bin/acbuild-chroot --chroot ${ROOTFS} --working-dir '/tmp'"
MODIFY=${MODIFY:-""}
FLAGS=${FLAGS:-""}
IMG_NAME="${BUILD_ORG}/${ACI_NAME}"
IMG_VERSION=${version}
# ACI format: {name}-{version}-{os}-{arch}.{ext}
ACI_FILE=${ACI_NAME}-${version}-linux-${arch}.aci
ARTIFACTS_DIR='./'
ACI_ARTIFACT=${ARTIFACTS_DIR}/${ACI_FILE}

PRIVATE_KEY="./${ACI_NAME}-signingkey.pem"
PUBLIC_KEY="./${ACI_NAME}-signingkey-public.pem"
ACI_SIG="${ARTIFACTS_DIR}/${ACI_FILE}.sha256"

function buildend() {
    export EXIT=$?
    umount $ROOTFS/proc
    umount $ROOTFS/dev
    exit $EXIT
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

if [ "$EUID" -ne 0 ]; then
    echo "This script uses functionality which requires root privileges"
    exit 1
fi

type $DEBOOTSTRAP >/dev/null
if [ $? -ne 0 ]; then
    echo "debootstrap not installed"
    exit 1
fi

$DEBOOTSTRAP --include $PACKAGES --components $COMPONENTS --variant $VARIANT $SUITE $ROOTFS $MIRROR

cat << EOF > ${ROOTFS}/etc/apt/sources.list
## Uncomment the following two lines to fetch updated software from the network
deb http://old-releases.ubuntu.com/ubuntu ${SUITE} main restricted
deb-src http://old-releases.ubuntu.com/ubuntu ${SUITE} main restricted

## Uncomment the following two lines to fetch major bug fix updates produced
## after the final release of the distribution.
deb http://old-releases.ubuntu.com/ubuntu ${SUITE}-updates main restricted
deb-src http://old-releases.ubuntu.com/ubuntu ${SUITE}-updates main restricted

## Uncomment the following two lines to add software from the 'universe'
## repository.
## N.B. software from this repository is ENTIRELY UNSUPPORTED by the Ubuntu
## team, and may not be under a free licence. Please satisfy yourself as to
## your rights to use the software. Also, please note that software in
## universe WILL NOT receive any review or updates from the Ubuntu security
## team.
deb http://old-releases.ubuntu.com/ubuntu ${SUITE} universe
deb-src http://old-releases.ubuntu.com/ubuntu ${SUITE} universe

deb http://old-releases.ubuntu.com/ubuntu ${SUITE}-security main restricted
deb-src http://old-releases.ubuntu.com/ubuntu ${SUITE}-security main restricted

deb http://old-releases.ubuntu.com/ubuntu ${SUITE}-security universe
deb-src http://old-releases.ubuntu.com/ubuntu ${SUITE}-security universe

deb http://old-releases.ubuntu.com/ubuntu ${SUITE} multiverse
deb-src http://old-releases.ubuntu.com/ubuntu ${SUITE} multiverse

deb http://old-releases.ubuntu.com/ubuntu ${SUITE}-backports main restricted universe multiverse

#
# PPA repositories without having to install more cruft
deb http://ppa.launchpad.net/dns/gnu/ubuntu ${SUITE} main
deb-src http://ppa.launchpad.net/dns/gnu/ubuntu ${SUITE} main
EOF

cat << EOF > ${ROOTFS}/etc/apt/apt.conf.d/01lean
APT::Install-Suggests "0";
APT::Install-Recommends "0";
APT::AutoRemove::SuggestsImportant "false";
APT::AutoRemove::RecommendsImportant "false";
EOF

# Consider using schroot if build troubles persist
# https://github.com/neurodebian/travis-chroots/blob/master/tools/travis_chroot

export LANG=C  # https://serverfault.com/questions/350876/setlocale-error-with-chroot
chroot $ROOTFS mount -t proc /proc /proc
chroot $ROOTFS echo "en_US.UTF-8 UTF-8" >>/etc/locale.gen
chroot $ROOTFS dpkg-reconfigure locales
chroot $ROOTFS apt-key adv --keyserver keyserver.ubuntu.com --recv-keys B187F352479B857B
chroot $ROOTFS apt-get -qq update
chroot $ROOTFS apt-get -y dist-upgrade
chroot $ROOTFS apt-get --purge -y autoremove
chroot $ROOTFS apt-get --purge -y autoremove
chroot $ROOTFS apt-get clean
umount $ROOTFS/proc

echo "Finished ${SUITE} rootfs build."

# Start the build with ACI bootstrapped above
$ACBUILD begin /tmp/rootfs

# Name the ACI
$ACBUILD set-name ${IMG_NAME}

# Based on TAQTIQA Linux base image of Ubuntu (12 MB)
# rkt trust --prefix=taqtiqa.io/rkt-base
#$ACBUILD dep add taqtiqa.io/rkt-base:0.0.1.1

$ACBUILD label add version ${version}
$ACBUILD label add arch amd64
$ACBUILD label add os linux
$ACBUILD annotation add authors "${BUILD_AUTHOR} <${BUILD_EMAIL}>"

$ACBUILD set-user 0
$ACBUILD set-group 0
$ACBUILD environment add OS_VERSION ${dist}

# Some recurrences have been known
$ACBUILD_RUN --cmd 'apt-get' --args '--purge -y autoremove'
$ACBUILD_RUN --cmd 'apt-get' --args 'clean'

f [ -z "$MODIFY" ]; then
  # Save the ACI
  $ACBUILD write --overwrite ${ACI_ARTIFACT}
fi


if [ -f ./${ACI_NAME}-privatekeys.gpg ]; then
  # Sign ACI
  ./script/sign.sh ${ACI_ARTIFACT}
fi

if [ -e ${out}/tmp/ ]; then
  rm -rf ${out}/tmp/*
fi

$ACBUILD end