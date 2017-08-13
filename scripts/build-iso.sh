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

TMP_PRIVATE_KEYRING="./rkt.sec"
TMP_PUBLIC_KEYRING="./rkt.pub"

if [ "${RKT_BUILD_ENV}" -ne 'true' ]; then
  echo 'This script requires environment variables setup by build-env.sh'
  exit 1
fi

if [[ ! -f ${ROOTFS}/etc/apt/sources.list ]]; then
  echo "This script requires a populated/build chroot environment in ${ROOTFS}"
  exit 1
fi

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

cp /etc/hosts ${ROOTFS}/etc/hosts
cp /etc/resolv.conf ${ROOTFS}/etc/resolv.conf

# Make a backup copy of /sbin/initctl
chroot ${ROOTFS} /bin/bash -x <<'EOF'
if [[ -d /sbin/initctl ]]; then
  cp /sbin/initctl /sbin/initctl.bak
else
  echo 'No /init/initctl'
fi
EOF
chroot ${ROOTFS} apt-get install --yes dbus
chroot ${ROOTFS} dbus-uuidgen > /var/lib/dbus/machine-id
chroot ${ROOTFS} dpkg-divert --local --rename --add /sbin/initctl
# There is a current (for Karmic, Lucid, ..., Precise) issue with services
# running in a chroot:
# https://bugs.launchpad.net/ubuntu/+source/upstart/+bug/430224.
case "${BUILD_RELEASE}" in
  hardy|intrepid|jaunty|karmic|lucid|maverick|natty|oneiric|precise|quantal|raring|saucy)
    chroot ${ROOTFS} ln -s /bin/true /sbin/initctl
    ;;
  *)
    echo "Do not disable services"
    ;;
esac
chroot ${ROOTFS} apt-get install --yes ubuntu-standard casper lupin-casper
# Before Maverick, discover was named discover1.
case "${BUILD_RELEASE}" in
  hardy|intrepid|jaunty|karmic)
    chroot ${ROOTFS} apt-get install --yes discover1
    ;;
  lucid)
    chroot ${ROOTFS} apt-get install --yes discover1 grub2 plymouth-x11
    ;;
  xenial|zesty|artful)
    chroot ${ROOTFS} apt-get install --yes discover
    ;;
  *)
    chroot ${ROOTFS} apt-get install --yes discover
    ;;
esac
chroot ${ROOTFS} apt-get install --yes laptop-detect os-prober
chroot ${ROOTFS} apt-get install --yes linux-generic

# Install Rkt specific packages and configuration
chroot ${ROOTFS} apt-get install --yes cgroup-lite
#chroot ${ROOTFS} gpg --no-tty --no-default-keyring --batch --with-colons --secret-keyring ${TMP_PRIVATE_KEYRING} --keyring ${TMP_PUBLIC_KEYRING} --keyserver pgp.mit.edu --recv-key 18AD5014C99EF7E3BA5F6CE950BDD3E0FC8A365E
chroot ${ROOTFS} wget https://github.com/rkt/rkt/releases/download/${RKT_VERSION_URI}/rkt_${RKT_VERSION}_amd64.deb
#chroot ${ROOTFS} wget https://github.com/rkt/rkt/releases/download/${RKT_VERSION_URI}/rkt_${RKT_VERSION}_amd64.deb.asc
#chroot ${ROOTFS} ( gpg --no-tty --no-default-keyring --secret-keyring ${TMP_PRIVATE_KEYRING} --keyring ${TMP_PUBLIC_KEYRING} --verify rkt_${RKT_VERSION}_amd64.deb.asc ) && dpkg -i rkt_${RKT_VERSION}_amd64.deb
chroot ${ROOTFS} dpkg -i rkt_${RKT_VERSION}_amd64.deb
case "${BUILD_RELEASE}" in
  hardy|lucid|precise|trusty|xenial)
    echo 'Nothing installed'
    ;;
  *)
    echo 'Nothing installed'
    ;;
esac
chroot ${ROOTFS} $( id -u ubuntu &>/dev/null || useradd ubuntu -s /bin/bash -p '*' )
chroot ${ROOTFS} $( $(getent group rkt) || groupadd rkt )
chroot ${ROOTFS} gpasswd --add root rkt
chroot ${ROOTFS} gpasswd --add ubuntu rkt
chroot ${ROOTFS} ./dist/scripts/setup-data-dir.sh
# Manually add the key from taqtiqa.io
fpr=$(gpg --no-tty --no-default-keyring --no-auto-check-trustdb --with-colons --with-fingerprint ./${BUILD_ACI_NAME}-publickeys.asc 2>/dev/null |grep fpr|cut -d':' -f10| tr '[:upper:]' '[:lower:]')
chroot ${ROOTFS} mkdir -p /etc/rkt/trustedkeys/prefix.d/${BUILD_ORG}/${BUILD_ACI_NAME}
chroot ${ROOTFS} mv ${BUILD_ACI_NAME}-publickeys.asc /etc/rkt/trustedkeys/prefix.d/${BUILD_ORG}/${BUILD_ACI_NAME}/${fpr}

chroot ${ROOTFS} rm -f /var/lib/dbus/machine-id
# NOTE:  The following are required prior to leaving the chroot area to prepare
#        the chroot environment as a Live ISO
chroot ${ROOTFS} rm -f /sbin/initctl
chroot ${ROOTFS} dpkg-divert --local --remove /sbin/initctl
# For the necessity of installing upstart see:
# https://bugs.launchpad.net/ubuntu/+source/upstart/+bug/430224#18
case "${BUILD_RELEASE}" in
  hardy|intrepid|jaunty|karmic|lucid)
    chroot ${ROOTFS} apt-get install --reinstall upstart
    ;;
  *)
    echo 'No need to reinstall upstart after lucid'
    ;;
esac
#Restore any backup copy of /sbin/initctl
chroot ${ROOTFS} /bin/bash -x <<'EOF'
if [[ -d /sbin/initctl ]] ; then
  cp /sbin/initctl.bak /sbin/initctl
else echo 'No /init/initctl'
fi
ls /boot/vmlinuz-**-generic > list.txt
sum=$(cat list.txt | grep '[^ ]' | wc -l)
if [ $sum -gt 1 ]; then
  dpkg -l 'linux-*' | sed '/^ii/!d;/'"$(uname -r | sed "s/\(.*\)-\([^0-9]\+\)/\1/")"'/d;s/^[^ ]* [^ ]* \([^ ]*\).*/\1/;/[0-9]/!d' | xargs sudo apt-get -y purge
fi
rm -f list.txt
apt-get clean
rm -rf /tmp/*
rm -f /etc/resolv.conf
EOF

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

# Create the Cd Image Directory and Populate it
mkdir -p image/{casper,isolinux,install}
cp ${ROOTFS}/boot/vmlinuz-**-generic image/casper/vmlinuz
case "${BUILD_RELEASE}" in
  hardy|intrepid|jaunty)
    cp ${ROOTFS}/boot/initrd.img-**-generic image/casper/initrd.gz
    ;;
  *)
    echo 'No need to reinstall upstart after jaunty use lz format'
    cp ${ROOTFS}/boot/initrd.img-**-generic image/casper/initrd.lz
    ;;
esac

case "${DISTRIB_CODENAME}" in
  xenial)
    echo 'Xenial | Zesty locations for isolinux.bin are different.'
    cp /usr/lib/ISOLINUX/isolinux.bin image/isolinux/
    cp /usr/lib/syslinux/modules/bios/menu.c32 image/isolinux/
    cp /usr/lib/syslinux/modules/bios/hdt.c32 image/isolinux/
    cp /usr/lib/syslinux/modules/bios/ldlinux.c32 image/isolinux/
    cp /usr/lib/syslinux/modules/bios/libutil.c32 image/isolinux/
    cp /usr/lib/syslinux/modules/bios/libmenu.c32 image/isolinux/
    cp /usr/lib/syslinux/modules/bios/libcom32.c32 image/isolinux/
    cp /usr/lib/syslinux/modules/bios/libgpl.c32 image/isolinux/
    ;;
  trusty)
    cp /usr/lib/syslinux/isolinux.bin image/isolinux/
    cp /usr/lib/syslinux/menu.c32 image/isolinux/
    cp /usr/share/live/images/standard/config/bootloaders/isolinux/hdt.c32 image/isolinux/
    #cp /usr/share/live/images/standard/config/bootloaders/isolinux/ldlinux.c32 image/isolinux/
    #cp /usr/share/live/images/standard/config/bootloaders/isolinux/libutil.c32 image/isolinux/
    #cp /usr/lib/syslinux/libmenu.c32 image/isolinux/
    #cp /usr/share/live/images/standard/config/bootloaders/isolinux/libcom32.c32 image/isolinux/
    #cp /usr/lib/syslinux/libgpl.c32 image/isolinux/
    ;;
  *)
    echo 'Building on an unknown host environment.'
    exit 1
    ;;
esac

cp /usr/share/misc/pci.ids image/isolinux/
cp /boot/memtest86+.bin image/install/memtest

cat << EOF > image/isolinux/isolinux.txt
splash.rle
*******************************************************************************

Ubuntu Remix Live ISO by:

########  ###     #######  ######## ####  #######     ###        ####  #######
   ##    ## ##   ##     ##    ##     ##  ##     ##   ## ##        ##  ##     ##
   ##   ##   ##  ##     ##    ##     ##  ##     ##  ##   ##       ##  ##     ##
   ##  ##     ## ##     ##    ##     ##  ##     ## ##     ##      ##  ##     ##
   ##  ######### ##  ## ##    ##     ##  ##  ## ## #########      ##  ##     ##
   ##  ##     ## ##    ##     ##     ##  ##    ##  ##     ## ###  ##  ##     ##
   ##  ##     ##  ##### ##    ##    ####  ##### ## ##     ## ### ####  #######

For the default live system, enter "live".  For memtest86+, enter "memtest".
For hardware detection tool, enter "hdt".  For ISO defect check, enter "check".
To boot from the first hard disk, enter "hd".

*******************************************************************************
EOF

case "${BUILD_RELEASE}" in
  hardy|intrepid|jaunty)
    cat << EOF > image/isolinux/isolinux.cfg
DEFAULT live
LABEL live
  menu label ^Start or install Ubuntu Remix
  kernel /casper/vmlinuz
  append  file=/cdrom/preseed/ubuntu.seed boot=casper persistent initrd=/casper/initrd.gz quiet splash --
LABEL check
  menu label ^Check CD for defects
  kernel /casper/vmlinuz
  append  boot=casper integrity-check initrd=/casper/initrd.gz quiet splash --
LABEL hdt
  menu label ^Hardware Detection Tool (HDT)
  kernel hdt.c32
  text help
  HDT displays low-level information about the systems hardware.
  endtext
LABEL memtest
  menu label ^Memory test
  kernel /casper/memtest
  append -
LABEL hd
  menu label ^Boot from first hard disk
  localboot 0x80
  append -
DISPLAY isolinux.txt
TIMEOUT 300
PROMPT 1

#prompt flag_val
#
# If flag_val is 0, display the "boot:" prompt
# only if the Shift or Alt key is pressed,
# or Caps Lock or Scroll lock is set (this is the default).
# If  flag_val is 1, always display the "boot:" prompt.
#  http://linux.die.net/man/1/syslinux   syslinux manpage
EOF
    ;;
  *)
    echo 'After jaunty use lz format'
    cat << EOF > image/isolinux/isolinux.cfg
DEFAULT live
LABEL live
  menu label ^Start or install Ubuntu Remix
  kernel /casper/vmlinuz
  append  file=/cdrom/preseed/ubuntu.seed boot=casper persistent initrd=/casper/initrd.gz quiet splash --
LABEL check
  menu label ^Check CD for defects
  kernel /casper/vmlinuz
  append  boot=casper integrity-check initrd=/casper/initrd.lz quiet splash --
LABEL hdt
  menu label ^Hardware Detection Tool (HDT)
  kernel hdt.c32
  text help
  HDT displays low-level information about the systems hardware.
  endtext
LABEL memtest
  menu label ^Memory test
  kernel /install/memtest
  append -
LABEL hd
  menu label ^Boot from first hard disk
  localboot 0x80
  append -
DISPLAY isolinux.txt
TIMEOUT 300
PROMPT 1

#prompt flag_val
#
# If flag_val is 0, display the "boot:" prompt
# only if the Shift or Alt key is pressed,
# or Caps Lock or Scroll lock is set (this is the default).
# If  flag_val is 1, always display the "boot:" prompt.
#  http://linux.die.net/man/1/syslinux   syslinux manpage
EOF
    ;;
esac

# Create manifest:
chroot ${ROOTFS} dpkg-query -W --showformat='${Package} ${Version}\n' | tee image/casper/filesystem.manifest
cp -v image/casper/filesystem.manifest image/casper/filesystem.manifest-desktop
REMOVE='ubiquity ubiquity-frontend-gtk ubiquity-frontend-kde casper lupin-casper live-initramfs user-setup discover1 discover xresprobe os-prober libdebian-installer4'
for i in $REMOVE; do
  sed -i "/${i}/d" image/casper/filesystem.manifest-desktop
done
# This image is 'only' meant as a LiveCD so the /boot folder can be excluded
# to reduce iso image size.
# The live system boots from outside the chroot and so the /boot folder is not used.
mksquashfs ${ROOTFS} image/casper/filesystem.squashfs -e boot

# Create diskdefines
cat << EOF > image/README.diskdefines
#define DISKNAME  TAQTIQA.IO Ubuntu Remix
#define TYPE  binary
#define TYPEbinary  1
#define ARCH  amd64
#define ARCHamd64  1
#define DISKNUM  1
#define DISKNUM1  1
#define TOTALNUM  0
#define TOTALNUM0  1
EOF

# Recognition as an Ubuntu Remix
touch image/ubuntu
mkdir -p image/.disk
cd image/.disk
  touch base_installable
  echo 'full_cd/single' > cd_type
  echo "Ubuntu Remix by TAQTIQA.IO ${BUILD_VERSION}" > info  # Update version number to match your OS version
  echo "https://taqtiqa.io/posts/${BUILD_ACI_NAME}" > release_notes_url
  find . -type f -print0 | xargs -0 md5sum | grep -v "\./md5sum.txt" > md5sum.txt
cd ../..

# Calculate  of everything except the file md5sum.txt
cd image
  find . -type f -print0 | xargs -0 md5sum | grep -v "\./md5sum.txt" > md5sum.txt
  # Create ISO Image for a LiveCD from the image directory using the command-line
  mkisofs -r -V "${BUILD_FILE}" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o ../${BUILD_FILE}.iso .
cd ..

#genisoimage \
#    -rational-rock \
#    -volid "Debian Live" \
#    -cache-inodes \
#    -joliet \
#    -hfs \
#    -full-iso9660-filenames \
#    -b isolinux/isolinux.bin \
#    -c isolinux/boot.cat \
#    -no-emul-boot \
#    -boot-load-size 4 \
#    -boot-info-table \
#    -output $HOME/live_boot/debian-live.iso \
#    $HOME/live_boot/image