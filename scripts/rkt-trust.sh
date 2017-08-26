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

#
# Usage: rkt-trust <rkt-prefix>
#
# Example:
# $ ./rkt-trust.sh taqtiqa.io/rkt-base
#
set -exuo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "This script uses functionality which requires root privileges"
  exit 1
fi

if [[ $# -lt 1 ]] ; then
  echo "Usage: rkt-trust <rkt-prefix>"
  exit 1
fi

RKT_PREFIX=$1

PUBLIC_KEY_URL='https://raw.githubusercontent.com/taqtiqa/rkt-base/gh-pages/keyrings/rkt-base-publickeys.asc'
PUBLIC_KEY=$(basename ${PUBLIC_KEY_URL})
TMP_PUBLIC_KEYRING='./pubkeys.gpg'
RKT_KEY_ROOT='/etc/rkt/trustedkeys/prefix.d'

pushd /tmp
  wget ${PUBLIC_KEY_URL}
  gpg --no-tty --no-default-keyring --no-auto-check-trustdb --with-colons --keyring ${TMP_PUBLIC_KEYRING} --import ./${PUBLIC_KEY}
  KEY_ID=$(gpg --no-tty --no-default-keyring --no-auto-check-trustdb --keyring ${TMP_PUBLIC_KEYRING} --list-keys --with-colons 2>/dev/null|grep pub|cut -d':' -f5)
  gpg --no-default-keyring --no-auto-check-trustdb --list-keys --with-fingerprint --with-colons --keyring ${TMP_PUBLIC_KEYRING} ${KEY_ID}
  KEY_FPR=$(gpg --no-tty --no-default-keyring --no-auto-check-trustdb --list-keys --with-fingerprint --with-colons --keyring ${TMP_PUBLIC_KEYRING} ${KEY_ID} 2>/dev/null|grep fpr|cut -d':' -f10| tr '[:upper:]' '[:lower:]')
  mkdir -p ${RKT_KEY_ROOT}/${RKT_PREFIX}
  cat ./${PUBLIC_KEY} >"${RKT_KEY_ROOT}/${RKT_PREFIX}/${KEY_FPR}"
popd
