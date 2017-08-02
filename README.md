# rkt-base
Rkt Base Ubuntu

## Build steps
````bash
$ RKT_IMAGE='rkt-base'
$ RKT_IMAGE_BRANCH='hardy'
$ git clone --depth=1 https://github.com/taqtiqa/${RKT_IMAGE}.git --branch ${RKT_IMAGE_BRANCH} --single-branch
$ pushd ${RKT_IMAGE}
$ sudo ./rkt-base.sh
````

## Run rkt Container: Remote download
If the rkt conatiner is built on a desktop - rather than in the Travis-CI
build environment the image name will be `./image-name-0.0.0-0-linux-amd64.aci`
````bash
sudo rkt trust --prefix=taqtiqa.io/rkt-base
rkt fetch taqtiqa.io/rkt-base:8.4.4+0
sudo rkt run taqtiqa.io/rkt-base:8.4.4+0
sudo rkt run --interactive taqtiqa.io/rkt-base:8.4.4+0 --exec bash
````
or 
````bash
sudo rkt run --net=host --insecure-options=image --interactive ./image-name-0.0.0-0-linux-amd64.aci --exec bash
````
or
````bash
sudo rkt run --dns 8.8.8.8 --net=host --insecure-options=image --interactive ./image-name-0.0.0-0-linux-amd64.aci --exec bash
````

## Run rkt Container: Local download
If the rkt conatiner is built on a desktop - rather than in the Travis-CI
build environment the image name will be `./image-name-0.0.0-0-linux-amd64.aci`
````bash
sudo rkt run --insecure-options=image --interactive ./image-name-0.0.0-0-linux-amd64.aci --exec bash
````
or 
````bash
sudo rkt run --net=host --insecure-options=image --interactive ./image-name-0.0.0-0-linux-amd64.aci --exec bash
````
or
````bash
sudo rkt run --dns 8.8.8.8 --net=host --insecure-options=image --interactive ./image-name-0.0.0-0-linux-amd64.aci --exec bash
````
