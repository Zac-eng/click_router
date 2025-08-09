#!/bin/sh
# Define parameter
CNIC=eth0

# Create Network Namespace
echo Add SrvGW, Server
# sudo ip netns add SrvGW
sudo ip netns add Server

# Connect SrvGW - Server
echo Connect SrvGW - Server 192.168.4.0/24
sudo ip link add ethServer type veth peer name ethSrvGW
# sudo ip link set ethServer netns SrvGW
sudo ip link set ethSrvGW netns Server
#sudo ip netns exec SrvGW ip addr add 192.168.4.1/24 dev ethServer
sudo ip addr add 192.168.4.1/24 dev ethServer
# sudo ip netns exec SrvGW ip link set ethServer up
sudo ip link set ethServer up
sudo ip netns exec Server ip addr add 192.168.4.11/24 dev ethSrvGW
sudo ip netns exec Server ip link set ethSrvGW up
sudo ip netns exec Server ip link set lo up


# Suspend default ip routing in SrvGW and CltGW
# sudo ip netns exec SrvGW ip route del 192.168.4.0/24
sudo ip route del 192.168.4.0/24
# sudo ip netns exec SrvGW ip route add blackhole 192.168.4.0/24
sudo ip route add blackhole 192.168.4.0/24

# ethtool Cheksum off
sudo ip netns exec Server ethtool -K ethSrvGW tx off rx off

# MTU Update (if necessary)
sudo ip netns exec Server ip link set ethSrvGW mtu 1400

# Attach NIC
# echo attach cloud-side nic is $CNIC
# sudo ip link set $CNIC netns SrvGW
# sudo ip netns exec SrvGW ip link set $CNIC up
# sudo ip netns exec SrvGW dhclient $CNIC