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
# Usage: sign-once <file> <private_key>
#
# FEATURES:
# - Signatures use one off private key, public key is a build artifact.
# - Use `openssl genpkey ...` over `openssl genrsa ... && openssl rsa ...`
# - No password hashing required, because no private key is retained.
# - Per SafeCurves.cr.yp.to, use EC X25519 available from openssl 1.1 (https://github.com/openssl/openssl/issues/309)
#
# NOTE: to generate a public/private key use the following commands:
#
# *SHA-1 was officially deprecated by NIST in 2011
#
# openssl rand -base64 32 | sha1sum | sed 's/ .*//' >./secret
# openssl genrsa -aes128 -passout file:./secret -out private.pem 4096
# openssl rsa -in private.pem -passin file:./secret -pubout -out public.pem
# rm -f ./secret
#
# where ./secret contains the passphrase to be used.

filename=$1


if [[ $# -lt 1 ]] ; then
  echo "Usage: sign <file> <private_key>"
  exit 1
fi

privatekey=test-private.pem
publickey=test-public.pem
openssl genpkey -algorithm RSA -outform PEM -out key.pem -aes-256-cbc -pkeyopt rsa_keygen_bits:4096 -pkeyopt rsa_keygen_pubexp:${RSA_EXP} -text

openssl genpkey -genparam -algorithm ec -out ec_test.prm -pkeyopt ec_paramgen_curve:secp521r1
openssl genpkey -paramfile ec_test.prm -out ec_test.key

#create private key
openssl genpkey -algorithm X25519 -outform PEM -out ${privatekey}

# Create public key
openssl pkey -in ${privatekey} -pubout -out ${publickey}

# sign file
openssl dgst -ecdsa-with-SHA256 -sign ${privatekey} openssl-1.1.0f.tar.gz > signature.bin

# verify file
openssl dgst -ecdsa-with-SHA1 -verify public.pem -signature signature.bin test.pdf


openssl genrsa -aes256 -passout env:ACI_SECRET -out ${PRIVATE_KEY} 4096
openssl rsa -passin env:ACI_SECRET -in ${PRIVATE_KEY} -pubout -out ${PUBLIC_KEY}
chmod 400 ${PUBLIC_KEY}

# encrypt your private key using secret password
openssl aes-256-cbc -pass env:ACI_SECRET -in ${PRIVATE_KEY} -out ${PRIVATE_KEY}.enc -a
chmod 400 ${PRIVATE_KEY}.enc

SEKRET_ENV_VAR_ENC=$(echo "${SEKRET_ENV_VAR}" | openssl pkeyutl -encrypt -pubin -inkey "./${GIT_NAME}-traviskey-public.pem" | base64 --wrap 0)

# Insert encrypted environment variable in your .travis.yml like so
echo "env:" >./travis-todo.yml
echo "  - secure: ${SEKRET_ENV_VAR_ENC}" >>./travis-todo.yml

# Decode the encrypted private key:
# In Travis, use the following line and it will output a decrypted my_key file
echo "before_script:" >>./travis-todo.yml
echo "  - openssl aes-256-cbc -pass env:ACI_SECRET -in ${PRIVATE_KEY}.enc -out ${PRIVATE_KEY} -d -a" >>./travis-todo.yml

# Remove unencrypted keys and scratch files
rm ${PRIVATE_KEY}

openssl dgst -sha256 -sign $privatekey -passin env:ACI_SECRET -out /tmp/$filename.sha256.bin $filename
openssl base64 -in /tmp/$filename.sha256.bin -out $filename.sha256
rm /tmp/$filename.sha256.bin