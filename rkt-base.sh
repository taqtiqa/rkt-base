#!/usr/bin/env bash
#
# http://ben-collins.blogspot.com.au/2011/06/stripping-ubuntu-system-to-just-basics.html
#

set -ex
set -euo pipefail

SUITE=${STRAP_SUITE:-hardy} # Case sensitive

DEFAULT_PACKAGES=language-pack-en-base
DEFAULT_COMPONENTS=main,universe,multiverse,restricted
DEBOOTSTRAP=/usr/sbin/debootstrap
DEFAULT_MIRROR=http://old-releases.ubuntu.com/ubuntu
DEFAULT_VARIANT=minbase
DEFAULT_ROOTFS=/tmp/rootfs

MIRROR=${STRAP_MIRROR:-$DEFAULT_MIRROR}
ROOTFS=${1:-$DEFAULT_ROOTFS}
PACKAGES=${STRAP_PACKAGES:-$DEFAULT_PACKAGES}
COMPONENTS=${STRAP_COMPONENTS:-$DEFAULT_COMPONENTS}
VARIANT=${STRAP_VARIANT:-$DEFAULT_VARIANT}

buildend() {
    export EXIT=$?
    umount $ROOTFS/proc && exit $EXIT
}

trap buildend EXIT

type $DEBOOTSTRAP >/dev/null
if [ $? -ne 0 ]; then
    echo "debootstrap not installed"
    exit 1
fi

if [ "x$ROOTFS" == "x" ]; then
    echo "Usage: $0 <path_to_root>"
    exit 1
fi

$DEBOOTSTRAP --include $PACKAGES --components $COMPONENTS --variant $VARIANT $SUITE $ROOTFS $MIRROR

echo "do we get here..."
cat > ${ROOTFS}/etc/apt/sources.list << EOF
deb $MIRROR $SUITE ${COMPONENTS//,/ }
deb $MIRROR $SUITE-updates ${COMPONENTS//,/ }
deb $MIRROR $SUITE-security ${COMPONENTS//,/ }
EOF

cat > ${ROOTFS}/tmp/mark_auto.sh << EOF
#!/bin/bash

arch=\$(dpkg --print-architecture)
dpkg --get-selections | awk '{print \$1}' | \
(while read pkg; do
        echo "Package: \$pkg"
        echo "Architecture: \$arch"
        echo "Auto-Installed: 1"
        echo
done)
EOF

PKG_LIST="apt \
base-files \
base-passwd \
bash \
bsdutils \
coreutils \
dash \
debconf \
debian-archive-keyring \
debianutils \
diffutils \
dpkg \
e2fslibs \
e2fsprogs \
findutils \
gcc-4.9-base \
gnupg \
gpgv \
grep \
gzip \
hostname \
initscripts \
insserv \
libacl1 \
libapt-pkg4.12 \
libattr1 \
libaudit-common \
libaudit1 \
libblkid1 \
libbz2-1.0 \
libc-bin \
libc6 \
libcomerr2 \
libdb5.3 \
libdebconfclient0 \
libgcc1 \
libgcrypt20 \
libgpg-error0 \
liblzma \
libmount1 \
libncurses \
libpam-modules-bin \
libpam-modules \
libpam-runtime \
libpam0g \
libpcre3 \
libreadline6 \
libselinux1 \
libsemanage-common \
libsemanage1 \
libsepol1 \
libslang2 \
libsmartcols1 \
libss2 \
libstdc++6 \
libsystemd0 \
libtinfo5 \
libusb-0.1-4 \
libustr-1.0-1 \
libuuid1 \
login \
lsb-base \
mawk \
mount \
multiarch-support \
passwd \
perl-base \
python-apt \
readline-common \
sed \
sensible-utils \
startpar \
sysv-rc \
sysvinit-utils \
tar \
tzdata \
util-linux \
zlib1g"

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

#cp /tmp/sources.list ${ROOTFS}/etc/apt/sources.list

chroot $ROOTFS mount -t proc /proc /proc
chroot $ROOTFS apt-get update
#chroot $ROOTFS cp /var/lib/apt/extended_states /var/lib/apt/extended_states.bak
chroot $ROOTFS bash -c '/tmp/mark_auto.sh | tee /var/lib/apt/extended_states > /dev/null 2>&1'
# chroot $ROOTFS apt-mark auto '*'
chroot $ROOTFS apt-get install ${PKG_LIST}
chroot $ROOTFS apt-get --purge autoremove
#chroot $ROOTFS apt-get update
#chroot $ROOTFS apt-get dist-upgrade -y
umount $ROOTFS/proc
echo "Finished rootfs build."