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
# This script relies on the public key for this repo created by Travis.
# Travis is the CI environment supporting encrypted an file.
# Only one file can be encrypted.  Archive multiple files.
#
# Encrypt a file with a public key using OpenSSL
# Encode the encrypted string in Base64 format
#
# Usage: travis-encrypt-file <file>
#
#

filename=$1

if [[ $# -lt 1 ]] ; then
  echo "Usage: travis-encrypt-file <file>"
  exit 1
fi

function travisencryptfileend() {
    export EXIT=$?
    if [[ $EXIT != 0 ]]; then
      echo "Abnormal end."
    fi
    rm -f ./travis-ca.cert
    #unset ACI_SECRET
    exit $EXIT
}

trap travisencryptfileend EXIT

GIT_URL=`git config --get remote.origin.url`
GIT_NAME=$(basename $GIT_URL .git)
GIT_OWNER=$(basename $(dirname $GIT_URL))


TRAVIS_PUBLIC_KEY_PREFIX="./${GIT_NAME}-traviskey-public"
TRAVIS_PUBLIC_KEY="${TRAVIS_PUBLIC_KEY_PREFIX}.pem"
TRAVIS_JSON_FILE="${TRAVIS_PUBLIC_KEY}.json"

WORKING_DIR=$(cd -P -- "$(dirname -- "$0")" && pwd -P)

function json_value() {
  KEY=${1-'key'}
  num=${2-''}
  awk -F"[,:}]" '{for(i=1;i<=NF;i++){if($i~/'${KEY}'\042/){print $(i+1)}}}' | tr -d '"' | sed 's/\\n/\n/g' | sed -n ${num}p
}

pushd ${WORKING_DIR}
  pushd ../
    if [ ! -f ${TRAVIS_PUBLIC_KEY} ]; then
      echo "Travis public key needs to be downloaded and GPG signed."
      echo "Downloading..."
      ./scripts/travis.sh
      echo "GPG signing..."
      ./scripts/sign-once.sh ${TRAVIS_PUBLIC_KEY_PREFIX} ${TRAVIS_PUBLIC_KEY}
    fi
    if [ ! -f ${filename}.enc ]; then
      echo "Encrypted file ${filename}.enc not found!"

      # Generate the secret to encrypt and store in the .travis.yml
      # - used to encrypt/decrypt private part of the signing key
      # - used to sign files
      openssl rand -base64 1000 | sha512sum | sed 's/ .*//' > ./${GIT_NAME}-secret
      export ACI_SECRET=`cat ./${GIT_NAME}-secret`
      #rm -f ./${GIT_NAME}-secret
      SEKRET_ENV_VAR="ACI_SECRET=${ACI_SECRET}"

      # encrypt given file using secret password
      openssl aes-256-cbc -pass env:ACI_SECRET -in ${filename} -out ${filename}.enc -a
      chmod 400 ${filename}.enc

      SEKRET_ENV_VAR_ENC=$(echo "${SEKRET_ENV_VAR}" | openssl pkeyutl -encrypt -pubin -inkey "${TRAVIS_PUBLIC_KEY}" | base64 --wrap 0)

      # Insert encrypted environment variable in your .travis.yml like so
      echo "Local: $(date +%F_%T%Z)  UTC: $(date --utc +%F_%T)" >>./travis-todo.yml
      echo "# Env variable ACI_SECRET=<s3Kr3t> for ${filename}" >>./travis-todo.yml
      echo "env:" >>./travis-todo.yml
      echo "  - secure: ${SEKRET_ENV_VAR_ENC}" >>./travis-todo.yml

      # Decode the encrypted private key:
      echo "# In Travis, use the following line and it will output a decrypted file" >>./travis-todo.yml
      echo "before_script:" >>./travis-todo.yml
      echo "  - openssl aes-256-cbc -pass env:ACI_SECRET -in ${filename}.enc -out ${filename} -d -a" >>./travis-todo.yml
    else
      echo "Encrypted file ${filename}.enc found!"
    fi
  popd
popd