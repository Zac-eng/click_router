#!/bin/sh

# Create Network Namespace
echo Add Client, CltGWsudo ip netns add Client
sudo ip netns add Client


# Connect Client - CltGW
echo Connect Client - CltGW 192.168.4.0/24
sudo ip link add ethCltGW type veth peer name ethClient
sudo ip link set ethCltGW netns Client
sudo ip netns exec Client ip addr add 192.168.4.10/24 dev ethCltGW
sudo ip netns exec Client ip link set ethCltGW up
sudo ip netns exec Client ip link set lo up
sudo ip addr add 192.168.4.1/24 dev ethClient
sudo ip link set ethClient up

# Suspend default ip routing in SrvGW and CltGW
sudo ip route del 192.168.4.0/24
sudo ip route add blackhole 192.168.4.0/24

# ethtool Cheksum off
sudo ip netns exec Client ethtool -K ethCltGW tx off rx off

# MTU Update (if necessary)
sudo ip netns exec Client ip link set ethCltGW mtu 1400