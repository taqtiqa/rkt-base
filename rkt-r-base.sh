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

export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

set -eoux pipefail

#export TRAVIS_TAG=16.4.2.5

source scripts/build-env.sh

# References:
# https://mark911.wordpress.com/2016/02/06/how-to-compile-and-install-wget-and-rstudio-server-from-source-code-via-github-in-ubuntu-14-04-lts-64-bit/
# https://github.com/rocker-org/rocker-versioned/blob/master/r-ver/3.4.1/Dockerfile#L44
# https://www.stephenrlang.com/2017/03/setting-up-the-old-releases-repo-for-ubuntu/
# https://www.warpconduit.net/2011/07/31/apt-repository-for-old-ubuntu-releases/
# https://coderwall.com/p/3n6xka/fix-apt-on-old-unsupported-ubuntu-releases

if [[ ${CI} == 'true' ]]; then
  if [[ ${TRAVIS} == 'true' ]];then
    chown travis:travis ~/.gnupg/gpg.conf
    chgrp -R travis ~/.gnupg
    chmod 0600 ~/.gnupg/gpg.conf
  fi
fi

if [ "$EUID" -ne 0 ]; then
    echo "This script uses functionality which requires root privileges"
    exit 1
fi

# In the event of the script exiting, end the build
acbuildend() {
    export EXIT=$?
    $ACBUILD end
    exit $EXIT
}
function check_tool {
if ! which $1; then
    echo "Get $1 and put it in your \$PATH" >&2;
    exit 1;
fi
}

trap acbuildend EXIT

export R_VERSION='3.2.3'
export R_DEB_VERSION="${R_VERSION}-4"
export LITTLER_VERSION='0.3.2'
export RSTUDIO_VERSION='1.0.153'


export BUILD_DEP_NAME='rkt-base'
export BUILD_DEP_VERSION=$(cat ./VERSION)

export BUILD_ACI_NAME='rkt-base-r'

export BUILD_FILE=${BUILD_ACI_NAME}-${BUILD_VERSION}-linux-${BUILD_ARCH}
export BUILD_ARTIFACTS_DIR='.'
export BUILD_ARTIFACT=${BUILD_ARTIFACTS_DIR}/${BUILD_FILE}.aci


BUILDDEPS="build-essential fakeroot dpkg-dev devscripts"

# Built on TAQTIQA Linux base image of Ubuntu (~53 MB)
./scripts/rkt-trust.sh "${BUILD_ORG}/${BUILD_DEP_NAME}"

${ACBUILD} begin
${ACBUILD} dep add "${BUILD_ORG}/${BUILD_DEP_NAME}:${BUILD_DEP_VERSION}"

${ACBUILD} set-name ${BUILD_NAME}

${ACBUILD} label add version ${BUILD_VERSION}
${ACBUILD} label add arch amd64
${ACBUILD} label add os linux
${ACBUILD} annotation add authors "${BUILD_AUTHOR} <${BUILD_EMAIL}>"
${ACBUILD} annotation add created "$( date --rfc-3339=seconds | sed 's/ /T/' )"

#
# Setup RServer users
#
${ACBUILD} run -- groupadd -g 1000 rstudio
${ACBUILD} run -- useradd -u 1000 -g 1000 -d / -M rstudio
${ACBUILD} set-user 1000
${ACBUILD} set-group 1000

# Add a port for the RServer
${ACBUILD} port add rserver tcp 8787

${ACBUILD} run -- apt-get update
${ACBUILD} run -- apt-get install --yes ${BUILDDEPS}
${ACBUILD} copy-to-dir scripts/build-packages.sh scripts/build-local-repo.sh scripts/update-apt-local-archive.sh scripts/build-littler.sh scripts/build-rstudio.sh scripts/post-install-rstudio.sh /usr/local/bin
${ACBUILD} run -- /bin/bash -c "eval /usr/local/bin/build-local-repo.sh"
${ACBUILD} run -- /bin/bash -c "eval /usr/local/bin/build-packages.sh r-base ${R_DEB_VERSION} ${R_VERSION}"
${ACBUILD} run -- /bin/bash -c "eval /usr/local/bin/build-littler.sh ${LITTLER_VERSION}"
${ACBUILD} run -- /bin/bash -c "eval /usr/local/bin/build-rstudio.sh ${RSTUDIO_VERSION}"

#Configure RServer and RSession
# https://support.rstudio.com/hc/en-us/articles/200552316-Configuring-the-Server
# Set the working directory the app will run in inside the container

# Cleanup build dependencies
# ${ACBUILD} run -- apt-get purge --assume-yes ${BUILDDEPS}
# $ACBUILD run -- aptitude purge --assume-yes $BUILDDEPS

${ACBUILD} run -- apt-get purge --assume-yes ${BUILDDEPS}

# Some recurrences have been known
${ACBUILD} run -- apt-get autoremove --purge -y
${ACBUILD} run -- apt-get autoremove --purge -y
${ACBUILD} run -- apt-get clean
${ACBUILD} run -- rm -rf /tmp/*

# ${ACBUILD} run --  rstudio-server verify-installation
# Run RStudio Server
# ${ACBUILD} set-exec -- nohup rstudio-server start
${ACBUILD} set-exec -- systemctl start rstudio-server.service

echo "Write the Container Image..."
${ACBUILD} write --overwrite ${BUILD_ARTIFACT}
echo "Created Container Image ${BUILD_ARTIFACT}."
${ACBUILD} end

echo "Sign the Container Image..."
./scripts/sign.sh ${BUILD_ARTIFACT}
echo "Signed the Container Image..."
