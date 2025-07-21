#!/bin/bash

# run this script only from inside of fastclick directory like ../configure.sh

./configure \
  --enable-multithread \
  --disable-linuxmodule \
  --enable-intel-cpu \
  --enable-user-multithread \
  --verbose CFLAGS="-g -O3" CXXFLAGS="-g -std=gnu++11 -O3" \
  --disable-dynamic-linking \
  --enable-poll \
  --enable-bound-port-transfer \
  --disable-dpdk \
  --enable-batch \
  --enable-auto-batch \
  --with-netmap=no \
  --enable-zerocopy \
  --disable-dpdk-pool \
  --disable-dpdk-packet \
  --enable-ipsec \
  --enable-ip \
  --enable-local \
  --enable-userlevel \
  --enable-flow \
  --enable-ctx \
  --enable-research
  # --enable-ip6 \

sudo make
