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

if [[ $# -lt 3 ]] ; then
  echo "Usage: build-package <app-name> <pkg-version> <app-version>"
  exit 1
fi

PKG_NAME=$1
PKG_VERSION=$2
APP_VERSION=$3

APT_LOCAL_ARCHIVE=/usr/local/apt/archives

mkdir -p /usr/local/src/
pushd /usr/local/src/
  apt-get source ${PKG_NAME}=${PKG_VERSION}
  apt-get build-dep ${PKG_NAME}=${PKG_VERSION}
  pushd ${PKG_NAME}-${APP_VERSION}
    dpkg-checkbuilddeps
    dpkg-buildpackage -uc -b -us
  popd
  mv --force --verbose *.deb ${APT_LOCAL_ARCHIVE}

  source update-apt-local-archive.sh ${APT_LOCAL_ARCHIVE}

  apt-get install --yes --no-install-recommends --allow-unauthenticated --fix-broken ${PKG_NAME}=${PKG_VERSION}
popd