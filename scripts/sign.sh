#!/usr/bin/env bash
#
# Copyright (C) 2017 TAQTIQA LLC. <http://www.taqtiqa.com>
# Copyright (C) 2014 Enrico Zimuel
#
#The contents of this file are licensed under a Creative Commons
#Attribution-ShareAlike 4.0 International License.
#See <http://creativecommons.org/licenses/by-sa/4.0/deed.en_US>

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