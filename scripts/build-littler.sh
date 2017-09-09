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
  echo "Usage: build-littler.sh <version>"
  exit 1
fi

PKG_VERSION=$1
#0.1.0
LITTLER_URL="http://dirk.eddelbuettel.com/code/littler/littler_${PKG_VERSION}.tar.gz"
LITTLER_GZ=$(basename ${LITTLER_URL})
pushd /tmp
  busybox wget --output-document ${LITTLER_GZ} ${LITTLER_URL}
  tar --extract --gunzip --file ${LITTLER_GZ}
  R CMD INSTALL ${LITTLER_GZ}
  echo 'options(repos = c(CRAN = "https://cran.rstudio.com/"), download.file.method = "libcurl")' >> /etc/R/Rprofile.site \
  echo 'source("/etc/R/Rprofile.site")' >> /etc/littler.r \
	ln -s /usr/share/doc/littler/examples/install.r /usr/local/bin/install.r \
	ln -s /usr/share/doc/littler/examples/install2.r /usr/local/bin/install2.r \
	ln -s /usr/share/doc/littler/examples/installGithub.r /usr/local/bin/installGithub.r \
	ln -s /usr/share/doc/littler/examples/testInstalled.r /usr/local/bin/testInstalled.r \
	install.r docopt \
popd
rm -rf /tmp/${LITTLER_GZ}