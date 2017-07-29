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
