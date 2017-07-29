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

# Sign a file with a single use private key and password using GPG 1
#
# Usage: gpg-init <private-keyring> <public-keyring>
#
# FEATURES:
# - Signatures use one off private key, public key is a build artifact.
#
# NOTE: to generate a public/private key use the following commands:
#

set -exuo pipefail

PRIVATE_KEYRING=$1
PUBLIC_KEYRING=$2
PRIVATE_KEY="$(basename ${PRIVATE_KEYRING} .gpg).asc"
PUBLIC_KEY="$(basename ${PUBLIC_KEYRING} .gpg).asc"

if [[ $# -lt 2 ]] ; then
  echo "Usage: gpg-init <private-keyring> <public-keyring>"
  exit 1
fi

function gpginitcleanup {
  rm -f ${TMP_PRIVATE_KEYRING}
  rm -f ${TMP_PUBLIC_KEYRING}
}
function gpginitend {
    export EXIT=$?
    if [[ $EXIT != 0 ]]; then
      gpginitcleanup
    fi
    exit $EXIT
}

trap gpginitend EXIT

TMP_PRIVATE_KEYRING='./scripts/rkt.sec'
TMP_PUBLIC_KEYRING='./scripts/rkt.pub'

WORKING_DIR=$(cd -P -- "$(dirname -- "$0")" && pwd -P)

if [ ! -f ${PRIVATE_KEY} ] || [ ! -f ${PRIVATE_KEYRING} ]; then
  echo "Signing GPG secret keyring ${PRIVATE_KEYRING} or secret key ${PRIVATE_KEY} NOT found!"
  gpginitcleanup
  echo "Creating GPG secret keyring ${PRIVATE_KEYRING} and secret key ${PRIVATE_KEY}."
  pushd ${WORKING_DIR}
    pushd ..
      # Create secret and public key
      gpg --no-tty --batch --gen-key ./scripts/gpg-batch
      # Amend KEY_ID selection to use --with-colon
      #KEY_ID=`gpg --no-tty --no-default-keyring --secret-keyring ${TMP_PRIVATE_KEYRING} --import ${TMP_PRIVATE_KEYRING} --allow-secret-key-import  2>&1 | awk 'NR==1 { sub(/:/,"",$3) ; print $3 }'`
      KEY_ID=`gpg --no-tty --no-default-keyring --keyring ${TMP_PUBLIC_KEYRING} --import ${TMP_PUBLIC_KEYRING} 2>&1 | awk 'NR==1 { sub(/:/,"",$3) ; print $3 }'`
      echo -e "trust\n5\ny\n" | gpg --no-tty --no-default-keyring --trust-model always --command-fd 0 --keyring ${TMP_PUBLIC_KEYRING} --edit-key ${KEY_ID}
      # Export secret key as armored text
      gpg --no-tty --no-default-keyring --armor --secret-keyring ${TMP_PRIVATE_KEYRING} --keyring ${TMP_PUBLIC_KEYRING} --export-secret-key ${KEY_ID} >${PRIVATE_KEY}
      # Export public key as armored text
      gpg --no-tty --no-default-keyring --armor --secret-keyring ${TMP_PRIVATE_KEYRING} --keyring ${TMP_PUBLIC_KEYRING} --export ${KEY_ID} >${PUBLIC_KEY}
      gpg --no-tty --no-default-keyring --armor --export-ownertrust > ownertrust-gpg.txt
      # Provide keyrings as requested
      mv ${TMP_PRIVATE_KEYRING} ${PRIVATE_KEYRING}
      mv ${TMP_PUBLIC_KEYRING} ${PUBLIC_KEYRING}
      chmod 400 ${PRIVATE_KEYRING}
      chmod 400 ${PUBLIC_KEYRING}
      chmod 400 ${PRIVATE_KEY}
      chmod 400 ${PUBLIC_KEY}
    popd
  popd
fi