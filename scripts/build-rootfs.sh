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
#   build-rootfs.sh
#

set -eoux pipefail

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

EOF
# After trusty the GNU packages seem to be in the std Ubuntu repositories
case "${BUILD_RELEASE}" in
  hardy|intrepid|jaunty|karmic|lucid|maverick|natty|oneiric|precise|quantal|raring|saucy|trusty)
    cat << EOF >> ${ROOTFS}/etc/apt/sources.list
# PPA repositories without having to install more cruft
deb http://ppa.launchpad.net/dns/gnu/ubuntu ${BUILD_RELEASE} main
deb-src http://ppa.launchpad.net/dns/gnu/ubuntu ${BUILD_RELEASE} main
EOF
    ;;
  *)
    echo "Do not append GNU PPA repository to /etc/apt/sources.list"
    ;;
esac

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

  # Do not mount dev/pts until this issue is resolved
  # ISSUE:
  # https://github.com/travis-ci/travis-ci/issues/8187
  #
  #dev/pts should be mounted last
  for i in dev proc sys
  do
      mount -o bind /${i} ${ROOTFS}/${i}
  done
  if [[ ${BUILD_RELEASE} == 'karmic' ]]; then
    # See https://bugs.launchpad.net/ubuntu/+source/dbus/+bug/441100
    mount --bind /var/run/dbus/ ${ROOTFS}/var/run/dbus/
  fi
  if [[ ${CI} == 'false' ]]; then
    # We are on a desktop so can mount dev/pts
    mount -o bind /${i} ${ROOTFS}/dev/pts
  fi
  chroot ${ROOTFS} /bin/bash -c "echo 'rkt-base' > /etc/hostname"
  chroot ${ROOTFS} echo 'debconf debconf/frontend select Noninteractive' | chroot ${ROOTFS} debconf-set-selections
  chroot ${ROOTFS} dpkg-reconfigure debconf
  chroot ${ROOTFS} /bin/bash -c "echo 'en_US.UTF-8 UTF-8' >>/etc/locale.gen"
  chroot ${ROOTFS} usermod --login taqtiqa --home /home/taqtiqa --comment "TAQTIQA" --move-home ubuntu
  chroot ${ROOTFS} groupmod --new-name taqtiqa ubuntu
  chroot ${ROOTFS} userdel --force ubuntu
  chroot ${ROOTFS} groupdel ubuntu
  chroot ${ROOTFS} rm -rf /home/ubuntu
  chroot ${ROOTFS} dpkg-reconfigure locales
  chroot ${ROOTFS} apt-key adv --keyserver keyserver.ubuntu.com --recv-keys B187F352479B857B
  chroot ${ROOTFS} apt-get -qq update
  chroot ${ROOTFS} apt-get install --yes ${BUILD_GUEST_ENHANCED_PACKAGES}
  chroot ${ROOTFS} apt-get -y -f -V dist-upgrade
  chroot ${ROOTFS} update-ca-certificates --verbose --fresh
  chroot ${ROOTFS} apt-get --purge -y autoremove
  chroot ${ROOTFS} apt-get clean
#  chroot ${ROOTFS} usermod --login taqtiqa --home /home/taqtiqa --comment "TAQTIQA" --move-home ubuntu
#  chroot ${ROOTFS} groupmod --new-name taqtiqa ubuntu
#  chroot ${ROOTFS} userdel --force ubuntu
#  chroot ${ROOTFS} groupdel ubuntu
#  chroot ${ROOTFS} rm -rf /home/ubuntu
  chroot ${ROOTFS} rm -rf /tmp/*
  chroot ${ROOTFS} rm -f /etc/resolv.conf
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
fi

echo "Finished ${BUILD_RELEASE} rootfs build."
