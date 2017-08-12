#!/usr/bin/env bash

set -eoux pipefail

export DEBOOTSTRAP=/usr/sbin/debootstrap

export ACI_ORG='taqtiqa.io'
export ACI_AUTHOR='TAQTIQA LLC'
export ACI_EMAIL='coders@taqtiqa.com'
export ACI_ARCH='amd64'

export CI_PACKAGE_MIRROR='http://old-releases.ubuntu.com/ubuntu' # http://archive.ubuntu.com/ubuntu

# In Travis-CI we have a detached HEAD - The branch name the tag is on is not available.
export ACI_RELEASE=$(cat ./RELEASE)
export ACI_RELEASE=$(cat ./RELEASE)

export CI_ARTIFACTS_DIR="/tmp/${ACI_RELEASE}"

export DEFAULT_BUILD_ARCH='amd64'
export DEFAULT_BUILD_VERSION='0.0.0-0'
export DEFAULT_CI='false'
export DEFAULT_COMPONENTS='main,universe,multiverse,restricted'
export DEFAULT_GUEST_PACKAGES='gnupg,dirmngr,busybox,network-manager,apt-utils,language-pack-en,ubuntu-keyring,debian-archive-keyring'
export DEFAULT_GUEST_PACKAGE_MIRROR='http://archive.ubuntu.com/ubuntu' #'http://old-releases.ubuntu.com/ubuntu'
export DEFAULT_HOST_PACKAGE_MIRROR='http://archive.ubuntu.com/ubuntu'
export DEFAULT_VARIANT='minbase'
export DEFAULT_ROOTFS='/tmp/rootfs'
export DEFAULT_RELEASE='master'
export DEFAULT_BUILD_ARTIFACTS_DIR=${CI_ARTIFACTS_DIR:-'/tmp/artifacts'}
export DEFAULT_ACI_NAME=$(basename $(git remote show -n origin | grep Fetch | cut -d: -f2-) .git)  #: r,littler,rserver no packages installed rkt-rrr-tidy: r,littler,rserver recommends and tidy packages, rkt-rrr-devel: r,littler,rserver recommends and tidy devel environment
export DEFAULT_SLUG="example.com/${DEFAULT_ACI_NAME}"
export DEFAULT_ORG=$(dirname ${DEFAULT_SLUG})
export DEFAULT_BUILD_ARTIFACTS_DIR=${CI_ARTIFACTS_DIR:-'/tmp/release'}
export DEFAULT_BUILD_EMAIL='no-reply@example.com'
export DEFAULT_BUILD_AUTHOR='Example LLC'

export ROOTFS=${1:-${DEFAULT_ROOTFS}}

export CI_BUILD_VERSION=${TRAVIS_TAG:-${DEFAULT_BUILD_VERSION}}
export CI_SLUG=${TRAVIS_REPO_SLUG:-${DEFAULT_SLUG}}
export CI=${CI:-${DEFAULT_CI}}

export ACI_NAME=$(basename ${CI_SLUG})  #: r,littler,rserver no packages installed rkt-rrr-tidy: r,littler,rserver recommends and tidy packages, rkt-rrr-devel: r,littler,rserver recommends and tidy devel environment

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

REPO_VERSION=$(cat ./VERSION)
if [[ ${CI_BUILD_VERSION} != ${REPO_VERSION} ]]; then
  msg "The CI tag version number and the content of the VERSION file do not match"
  exit 1
fi

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LANG=C  # https://serverfault.com/questions/350876/setlocale-error-with-chroot
export TERM=linux
export DEBIAN_FRONTEND='noninteractive'

export ACBUILD='/bin/acbuild --debug'
export ACBUILD_CHROOT="/bin/acbuild-chroot --chroot ${ROOTFS} --working-dir /tmp"

export BUILD_NAME="${BUILD_ORG}/${BUILD_ACI_NAME}"
