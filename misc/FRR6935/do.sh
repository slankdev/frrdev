#!/bin/sh -xe

function create_container() {
  if [ $# -ne 5 ]; then
          echo "invalid command syntax" 1>&2
          echo "Usage: $0 <image> <name-prefix> <mem> <mem-swap> <mem-swappiness>" 1>&2
          exit 1
  fi
  NAME=$2-$3-$4-$5
  docker run -td --privileged \
    --memory=$3 \
    --memory-swap=$4 \
    --memory-swappiness=$5 \
    -v /tmp/$NAME-tmp:/tmp \
    --name $2-$3-$4-$5 \
    --hostname $2-$3-$4-$5 \
    $1
}

function route_scale_test() {
  if [ $# -ne 3 ]; then
          echo "invalid command syntax" 1>&2
          echo "Usage: $0 <container-name> <base-commit> <size>" 1>&2
          exit 1
  fi

  docker exec $1 bash -c '
    git clone -b slankdev-debug-topotest https://github.com/slankdev/frr /frr && \
    cd /frr && \
    ./bootstrap.sh && \
    ./configure \
      --prefix=/usr \
      --localstatedir=/var/run/frr \
      --sbindir=/usr/lib/frr \
      --sysconfdir=/etc/frr \
      --enable-vtysh \
      --enable-pimd \
      --enable-sharpd \
      --enable-multipath=64 \
      --enable-user=frr \
      --enable-group=frr \
      --enable-vty-group=frrvty \
      --with-pkg-extra-version=-zapi-nexthop-hacks
  '

  docker exec $1 bash -c '
    cd /frr && \
    make -j8 && \
    make -j8 install
  '

  docker exec $1 bash -c '
    cd /frr/tests/topotests/route-scale && \
    ./test_route_scale.py
  '

  docker stop $1
}
export -f route_scale_test

create_container slankdev/frr-dev:ubuntu-16.04-i386  ubuntu1604-i386  2000mb 2000Mb 0
create_container slankdev/frr-dev:ubuntu-16.04-amd64 ubuntu1604-amd64 2000mb 2000Mb 0
create_container slankdev/frr-dev:ubuntu-18.04-amd64 ubuntu1804-amd64 2000mb 2000Mb 0

nohup bash -c "route_scale_test ubuntu1604-i386-2000mb-2000Mb-0  xx xx" > ubuntu1604-i386-2000mb-2000Mb-0.log  &
nohup bash -c "route_scale_test ubuntu1604-amd64-2000mb-2000Mb-0 xx xx" > ubuntu1604-amd64-2000mb-2000Mb-0.log &
nohup bash -c "route_scale_test ubuntu1804-amd64-2000mb-2000Mb-0 xx xx" > ubuntu1804-amd64-2000mb-2000Mb-0.log &
