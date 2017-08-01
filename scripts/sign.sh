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

# NOTE:
# This script relies on an environment variable for the pass phrase.
# Travis is the CI environment setup supporting encrypted environment variables.
#
# Sign a file with a private GPG keyring and password.
#
# Usage: sign <file>
#

set -exuo pipefail

FILENAME_TO_SIGN=$1

if [[ $# -lt 1 ]] ; then
  echo "Usage: sign <file>"
  exit 1
fi

SIGNATURE="${FILENAME_TO_SIGN}.asc"
TMP_GPG_HOME=$( mktemp -d -t 'XXXX' )

if [ -f ${SIGNATURE} ]; then
  echo "${SIGNATURE} exists. Exiting."
  exit 1
fi

if [ ! -f ${FILENAME_TO_SIGN} ]; then
  echo "${FILENAME_TO_SIGN} does not exist.  Nothing to sign. Exiting."
  exit 1
fi

WORKING_DIR=$(cd -P -- "$(dirname -- "$0")" && pwd -P)

GIT_URL=`git config --get remote.origin.url`
GIT_NAME=$(basename $GIT_URL .git)
GIT_OWNER=$(basename $(dirname $GIT_URL))

TMP_PRIVATE_KEYRING="${TMP_GPG_HOME}/${GIT_NAME}-privatekeys.gpg"
TMP_PUBLIC_KEYRING="${TMP_GPG_HOME}/${GIT_NAME}-publickeys.gpg"

PRIVATE_KEY="./$(basename ${TMP_PRIVATE_KEYRING} .gpg).asc"
PUBLIC_KEY="./$(basename ${TMP_PUBLIC_KEYRING} .gpg).asc"

PRIVATE_KEY_ENC="${PRIVATE_KEY}.enc"

function signend() {
    export EXIT=$?
    if [[ $EXIT != 0 ]]; then
      echo "Abnormal end."
    fi
    rm -f ./travis-ca.cert
    rm -f ${TMP_PRIVATE_KEYRING}
    rm -f ${TMP_PUBLIC_KEYRING}
    exit $EXIT
}

trap signend EXIT

pushd ${WORKING_DIR}
  pushd ../
    if [ -f ${PRIVATE_KEY} ]; then
      if [ ! -f ${PRIVATE_KEY_ENC} ]; then
        echo "The encrypted private keyring is missing - somehow!"
        # Encrypt for Travis private key and keyring if unencrypted.
        ./scripts/travis-encrypt-file.sh ${PRIVATE_KEY}
      fi
      echo "The decrypted GPG private key ${PRIVATE_KEY} found!"
      gpg --no-tty --no-default-keyring --with-colons --secret-keyring ${TMP_PRIVATE_KEYRING} --keyring ${TMP_PUBLIC_KEYRING} --import ${PRIVATE_KEY}
      KEY_ID=$(gpg --no-tty --no-default-keyring --secret-keyring ${TMP_PRIVATE_KEYRING} --keyring ${TMP_PUBLIC_KEYRING} --no-auto-check-trustdb --list-keys --with-colons|grep pub|cut -d':' -f5)
      echo -e "trust\n5\ny\n" | gpg --no-tty --no-default-keyring --trust-model always --command-fd 0 --keyring ${TMP_PUBLIC_KEYRING} --edit-key ${KEY_ID}
      # Sign file using GPG private keyring
      echo -e "rkt\n"|gpg --no-tty --passphrase-fd 0 --trust-model always --no-default-keyring --armor --secret-keyring ${TMP_PRIVATE_KEYRING} --keyring ${TMP_PUBLIC_KEYRING} --output ${SIGNATURE} --detach-sig ${FILENAME_TO_SIGN}
      # Verify file
      gpg --no-tty --no-default-keyring --trust-model always \
      --secret-keyring ${TMP_PRIVATE_KEYRING} --keyring ${TMP_PUBLIC_KEYRING} \
      --verify ${SIGNATURE} ${FILENAME_TO_SIGN}
    else
      if [ -f ${PRIVATE_KEY_ENC} ]; then
        echo "The secret key exists, but has not been decrypted in the CI environment."
        exit 1
      fi
      echo "The decrypted GPG secret key ${PRIVATE_KEY} NOT found!."
      # If no GPG keyring to sign with create one
      ./scripts/gpg-init.sh ${TMP_PRIVATE_KEYRING} ${TMP_PUBLIC_KEYRING}
      # Encrypt for Travis private key and keyring if unencrypted.
      ./scripts/travis-encrypt-file.sh ${TMP_PRIVATE_KEYRING}
      ./scripts/travis-encrypt-file.sh ${PRIVATE_KEY}
      echo "A private keyring NOW exists and needs decryption in the CI environment."
      exit 1
    fi
  popd
popd