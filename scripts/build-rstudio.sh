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

set -exuo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "This script uses functionality which requires root privileges"
  exit 1
fi

if [[ $# -lt 1 ]] ; then
  echo "Usage: build-rstudio.sh <version>"
  exit 1
fi

PKG_VERSION=$1
#1.0.153
PKG_NAME="rstudio-server"
RSTUDIO_URL="http://download2.rstudio.org/${PKG_NAME}-${PKG_VERSION}-amd64.deb"
RSTUDIO_DEB=$(basename ${RSTUDIO_URL})

APT_LOCAL_ARCHIVE=/usr/local/apt/archives

pushd /tmp
  busybox wget --output-document ${RSTUDIO_DEB} ${RSTUDIO_URL}
  mv --force --verbose *.deb ${APT_LOCAL_ARCHIVE}

  source update-apt-local-archive.sh ${APT_LOCAL_ARCHIVE}

  apt-get install --yes --allow-unauthenticated --fix-broken ${PKG_NAME}=${PKG_VERSION}

  echo server-app-armor-enabled=0 >>/etc/rstudio/rserver.conf

  source post-install-rstudio.sh

  rm -rf ${RSTUDIO_DEB}
popd
