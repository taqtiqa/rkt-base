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

#
# This script sets up keys for signing ACI artifacts built on Travis CI
#

set -exuo pipefail

BUILD_EMAIL=${BUILD_EMAIL:-$DEFAULT_BUILD_EMAIL}

GIT_URL=`git config --get remote.origin.url`
GIT_NAME=$(basename $GIT_URL .git)
GIT_OWNER=$(basename $(dirname $GIT_URL))

FILE='./traviskey-public.pem.json'

PRIVATE_KEY="./${GIT_NAME}-signingkey.pem"
PUBLIC_KEY="./${GIT_NAME}-signingkey-public.pem"

function json_value() {
  KEY=${1-'key'}
  num=${2-''}
  awk -F"[,:}]" '{for(i=1;i<=NF;i++){if($i~/'$KEY'\042/){print $(i+1)}}}' | tr -d '"' | sed 's/\\n/\n/g' | sed -n ${num}p
}


if [ ! -f ./${PRIVATE_KEY}.enc ]; then
  echo "Encrypted signing key ./${PRIVATE_KEY}.enc not found!"
  # CI tool independent way to encrypt a signing key
  # https://gist.github.com/kzap/5819745
  CA_CERTIFICATE="-----BEGIN CERTIFICATE-----
MIIENjCCAx6gAwIBAgIBATANBgkqhkiG9w0BAQUFADBvMQswCQYDVQQGEwJTRTEU
MBIGA1UEChMLQWRkVHJ1c3QgQUIxJjAkBgNVBAsTHUFkZFRydXN0IEV4dGVybmFs
IFRUUCBOZXR3b3JrMSIwIAYDVQQDExlBZGRUcnVzdCBFeHRlcm5hbCBDQSBSb290
MB4XDTAwMDUzMDEwNDgzOFoXDTIwMDUzMDEwNDgzOFowbzELMAkGA1UEBhMCU0Ux
FDASBgNVBAoTC0FkZFRydXN0IEFCMSYwJAYDVQQLEx1BZGRUcnVzdCBFeHRlcm5h
bCBUVFAgTmV0d29yazEiMCAGA1UEAxMZQWRkVHJ1c3QgRXh0ZXJuYWwgQ0EgUm9v
dDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALf3GjPm8gAELTngTlvt
H7xsD821+iO2zt6bETOXpClMfZOfvUq8k+0DGuOPz+VtUFrWlymUWoCwSXrbLpX9
uMq/NzgtHj6RQa1wVsfwTz/oMp50ysiQVOnGXw94nZpAPA6sYapeFI+eh6FqUNzX
mk6vBbOmcZSccbNQYArHE504B4YCqOmoaSYYkKtMsE8jqzpPhNjfzp/haW+710LX
a0Tkx63ubUFfclpxCDezeWWkWaCUN/cALw3CknLa0Dhy2xSoRcRdKn23tNbE7qzN
E0S3ySvdQwAl+mG5aWpYIxG3pzOPVnVZ9c0p10a3CitlttNCbxWyuHv77+ldU9U0
WicCAwEAAaOB3DCB2TAdBgNVHQ4EFgQUrb2YejS0Jvf6xCZU7wO94CTLVBowCwYD
VR0PBAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8wgZkGA1UdIwSBkTCBjoAUrb2YejS0
Jvf6xCZU7wO94CTLVBqhc6RxMG8xCzAJBgNVBAYTAlNFMRQwEgYDVQQKEwtBZGRU
cnVzdCBBQjEmMCQGA1UECxMdQWRkVHJ1c3QgRXh0ZXJuYWwgVFRQIE5ldHdvcmsx
IjAgBgNVBAMTGUFkZFRydXN0IEV4dGVybmFsIENBIFJvb3SCAQEwDQYJKoZIhvcN
AQEFBQADggEBALCb4IUlwtYj4g+WBpKdQZic2YR5gdkeWxQHIzZlj7DYd7usQWxH
YINRsPkyPef89iYTx4AWpb9a/IfPeHmJIZriTAcKhjW88t5RxNKWt9x+Tu5w/Rw5
6wwCURQtjr0W4MHfRnXnJK3s9EK0hZNwEGe6nQY1ShjTK3rMUUKhemPR5ruhxSvC
Nr4TDea9Y355e6cJDUCrat2PisP29owaQgVR1EX1n6diIWgVIEM8med8vSTYqZEX
c4g/VhsxOBi0cQ+azcgOno4uG+GMmIPLHzHxREzGBHNJdmAPx/i9F4BrLunMTA5a
mnkPIAou1Z5jJh5VkpTYghdae9C8x49OhgQ=
-----END CERTIFICATE-----
"
  # Prepare Travis CI certificate file. Extract Travis-CI public key:
  echo -n "$CA_CERTIFICATE" >./travis-ca.cert
  curl --cacert ./travis-ca.cert -s -X GET https://api.travis-ci.org/repos/${GIT_OWNER}/${GIT_NAME}/key | json_value key >./${GIT_NAME}-traviskey-public.pem
  chmod 400 ./${GIT_NAME}-traviskey-public.pem

  # Generate the secret to encrypt and store in the .travis.yml
  # - used to encrypt/decrypt private part of the signing key
  # - used to sign files
  openssl rand -base64 1000 | sha1sum | sed 's/ .*//' > ./${GIT_NAME}-secret
  export ACI_SECRET=`cat ./${GIT_NAME}-secret`
  rm -f ./${GIT_NAME}-secret
  SEKRET_ENV_VAR="ACI_SECRET=${ACI_SECRET}"

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
  rm ./travis-ca.cert
else
  echo "Encrypted signing key ./${PRIVATE_KEY}.enc found!"
fi