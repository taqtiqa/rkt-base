# rkt-base
Rkt Base Ubuntu

## Build steps
````bash
$ RKT_IMAGE='rkt-base'
$ RKT_IMAGE_BRANCH='8.04'
$ git clone --depth=1 https://github.com/taqtiqa/${RKT_IMAGE}.git --branch ${RKT_IMAGE_BRANCH} --single-branch
$ pushd ${RKT_IMAGE}
$ sudo ./rkt-base.sh
````
