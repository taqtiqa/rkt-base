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
# Travis is the CI environment setup to support this encrypted environment variables.
#
# Encrypt a string with a public key using OpenSSL
# Encode the encrypted string in Base64 format
#
# Usage: travis-encrypt <public_key> <string>
#
#

PUBLICKEY=$1
STRING=$2

if [[ $# -lt 2 ]] ; then
  echo "Usage: travis-encrypt <public_key> <string>"
  exit 1
fi

SEKRET_ENC=$(echo "${STRING}" | openssl pkeyutl -encrypt -pubin -inkey ${PUBLICKEY} | base64 --wrap 0)

echo "Local: $(date +%F_%T%Z)  UTC: $(date --utc +%F_%T)" >>./travis-todo.yml
echo "global:" >>./travis-todo.yml
echo "  - secure: ${SEKRET_ENC}" >>./travis-todo.yml

echo "Raw: ${STRING}"
echo "Encrypted: ${SEKRET_ENC}"