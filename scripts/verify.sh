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

# Verify a file with a public key using OpenSSL
# Decode the signature from Base64 format
#
# Usage: verify <file> <signature> <public_key>
#
# NOTE: to generate a public/private key use the following commands:
#
# openssl genrsa -aes128 -passout file:./secret -out private.pem 2048
# openssl rsa -in private.pem -passin file:./secret -pubout -out public.pem
#
# where <passphrase> is the passphrase to be used.

filename=$1
signature=$2
publickey=$3

if [[ $# -lt 3 ]] ; then
  echo "Usage: verify <file> <signature> <public_key>"
  exit 1
fi

openssl base64 -d -in $signature -out /tmp/$filename.sha256.bin
openssl dgst -sha256 -verify $publickey -signature /tmp/$filename.sha256.bin $filename
rm /tmp/$filename.sha256.bin