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

DEPLOY_DIR='./gh-pages'
GH_REF=github.com/${TRAVIS_REPO_SLUG}.git

rm -rf ${DEPLOY_DIR} || exit 0;
mkdir -p "${DEPLOY_DIR}/keyrings";

setup_git() {
  pushd ${DEPLOY_DIR}
    git init
    git config user.name "TAQTIQA LLC Automation"
    git config user.email "no-reply@taqtiqa.com"
  popd
}

commit_files() {
  pushd ${DEPLOY_DIR}
    git add .
    git commit --message "Travis build: $TRAVIS_BUILD_NUMBER"
  popd
}

upload_files() {
  pushd ${DEPLOY_DIR}
    git push --force --quiet "https://${GH_PA_TOKEN}@${GH_REF}" master:${1} > /dev/null 2>&1
  popd
}

setup_git
./scripts/deploy-keyrings.sh
commit_files
upload_files gh-pages