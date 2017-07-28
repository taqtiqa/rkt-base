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
# This script relies on an environment variable for the version number.
# Travis is the CI environment setup supporting encrypted environment variables.
#
# Sign a file with a private GPG keyring and password.
#
# Usage: deploy-keyrings.sh <deploy-dir>
#

set -exuo pipefail

if [[ $# -lt 1 ]] ; then
  echo "Usage: deploy-keyrings.sh"
  exit 1
fi

DEPLOY_DIR=$1

mkdir -p "${DEPLOY_DIR}/keyrings"

WORKING_DIR=$(cd -P -- "$(dirname -- "$0")" && pwd -P)

GIT_URL=`git config --get remote.origin.url`
GIT_NAME=$(basename $GIT_URL .git)
#GIT_OWNER=$(basename $(dirname $GIT_URL))

PUBLIC_KEYRING="./${GIT_NAME}-publickeys.gpg"

function deployend() {
    export EXIT=$?
    if [[ $EXIT != 0 ]]; then
      echo "Abnormal end."
    fi
    rm -f ./travis-ca.cert
    exit $EXIT
}

trap deployend EXIT

if [[ ! $CI == "true" ]]; then
  echo "Not in a CI environment. Do not Deploy."
  exit 1
fi

if [[ $TRAVIS == "true" ]]; then
  pushd ${WORKING_DIR}
    # Copy PUBLIC_KEYRING to gh=pages folder ready to be deployed
    if [ -f ${PUBLIC_KEYRING} ]; then
      # Make a versioned backup of public keyrings - in case of emergency
      cp --force "${PUBLIC_KEYRING}" "${DEPLOY_DIR}/keyrings/$(basename ${PUBLIC_KEYRING} .gpg)-${TRAVIS_TAG}.gpg"
      # Only replace the existing public keyring if it is changed.
      rsync --checksum "${PUBLIC_KEYRING}" "${DEPLOY_DIR}/keyrings/$(basename ${PUBLIC_KEYRING})"
      echo "A GPG public keyring is ready to deploy to GitHub Pages."
    else
      echo "A GPG public keyring ${PUBLIC_KEYRING} NOT found!."
      exit 1
    fi
  popd
fi