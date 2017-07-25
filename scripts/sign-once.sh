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
# Usage: sign-once <pub-key-prefix> <file>
#
# FEATURES:
# - Signatures use one off private key, public key is a build artifact.
#
# NOTE: to generate a public/private key use the following commands:
#

set -exuo pipefail

prefix=$1
filename=$2

if [[ $# -lt 2 ]] ; then
  echo "Usage: sign-once <pub-key-prefix> <file>"
  exit 1
fi

function signonceend() {
    export EXIT=$?
    if [[ $EXIT != 0 ]]; then
      rm -f ${publickey}
      rm -f ${signature}
    fi
    rm -f ${privatekeyring}
    rm -f ${publickeyring}
    exit $EXIT
}

trap signonceend EXIT

publickey=./${prefix}-signoncekey-public.gpg
privatekeyring=./scripts/rkt.sec
publickeyring=./scripts/rkt.pub
signature=${filename}.asc

dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)

pushd ${dir}
  pushd ..
    # Create private and public keys
    gpg --batch --gen-key ./scripts/gpg-batch
    id=`gpg --import ${publickeyring} 2>&1 | awk 'NR==1 { sub(/:/,"",$3) ; print $3 }'`
    echo -e "trust\n5\ny\n" | gpg --command-fd 0 --edit-key ${id}

    # Export public key
    gpg --no-default-keyring --armor \
    --secret-keyring ${privatekeyring} --keyring ${publickeyring} \
    --export ${id} >${publickey}

#    # Export public key
#    gpg --no-default-keyring --armor \
#    --secret-keyring ${privatekeyring} --keyring ${publickeyring} \
#    --export ${id} >${publickey}

    # Sign file
    echo -e "rkt\n"|gpg --passphrase-fd 0 --trust-model always --no-default-keyring --armor --secret-keyring ${privatekeyring} --keyring ${publickeyring} --output ${signature} --detach-sig ${filename}

    # Verify file
    gpg --trust-model always --no-default-keyring \
    --secret-keyring ${privatekeyring} --keyring ${publickeyring} \
    --verify ${signature} ${filename}

    rm -f ${privatekeyring}
    rm -f ${publickeyring}
  popd
popd