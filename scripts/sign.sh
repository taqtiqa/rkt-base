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
# Travis is the CI environment setup to support this encrypted environment variables.
#
# Sign a file with a private key and password using OpenSSL
# Encode the signature in Base64 format
#
# Usage: sign <file> <private_key>
#
# NOTE: to generate a public/private key use the following commands:
#
# openssl rand -base64 32 | sha1sum | sed 's/ .*//' >./secret
# openssl genrsa -aes128 -passout file:./secret -out private.pem 4096
# openssl rsa -in private.pem -passin file:./secret -pubout -out public.pem
# rm -f ./secret
#
# where ./secret contains the passphrase to be used.

filename=$1
privatekey=$2

if [[ $# -lt 2 ]] ; then
  echo "Usage: sign <file> <private_key>"
  exit 1
fi

openssl dgst -sha256 -sign $privatekey -passin env:ACI_SECRET -out /tmp/$filename.sha256.bin $filename
openssl base64 -in /tmp/$filename.sha256.bin -out $filename.sha256
rm /tmp/$filename.sha256.bin