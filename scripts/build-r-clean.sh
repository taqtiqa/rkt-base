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

if [[ $# -gt 0 ]] ; then
  echo "Usage: build-r-init.sh"
  exit 1
fi

export DEFAULT_GUEST_TEMP_PACKAGES='build-essential,fakeroot,dpkg-dev,devscripts'

apt-get purge --assume-yes ${BUILD_GUEST_TEMP_PACKAGES}
apt-get autoremove --purge -y
apt-get autoremove --purge -y
apt-get clean
rm -rf /tmp/*

