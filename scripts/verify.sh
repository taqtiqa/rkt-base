#!/usr/bin/env bash
#
# Copyright (C) 2017 TAQTIQA LLC. <http://www.taqtiqa.com>
# Copyright (C) 2014 Enrico Zimuel
#
#The contents of this file are licensed under a Creative Commons
#Attribution-ShareAlike 4.0 International License.
#See <http://creativecommons.org/licenses/by-sa/4.0/deed.en_US>

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