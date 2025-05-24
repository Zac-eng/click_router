#! /bin/bash

LAN_INTF=enx6c1ff71a039b
LAN_IP=192.168.32.1
LAN_MAC=6c:1f:f7:1a:03:9b
LAN_SUBN="192.168.32.0\/24"
WAN0_INTF=enp1s0
WAN0_IP=192.168.11.1
WAN0_MAC=e8:ff:1e:d8:1f:8c
WAN0_SUBN="192.168.11.0\/24"
WAN0_TARGET=192.168.11.2
WAN1_INTF=enp2s0
WAN1_IP=10.0.2.1
WAN1_MAC=e8:ff:1e:d8:1f:8b
WAN1_SUBN="10.0.2.0\/24"
WAN1_TARGET=10.0.2.2

TARGET_FILE=bounding_router.click
TEMPLATE_FILE=$TARGET_FILE.template

# env | awk -F= '{print "s/${"$1"}/"$2"/g"}' | sed -f $TEMPLATE_FILE > $TARGET_FILE
# env | sed -E 's/([\/&])/\\\1/g' | awk -F= '{print "s/${" $1 "}/" $2 "/g"}' | sed -f - $TEMPLATE_FILE >> $TARGET_FILE
sed "s/LAN_INTF/$LAN_INTF/g" $TEMPLATE_FILE \
  | sed "s/LAN_IP/$LAN_IP/g" \
  | sed "s/LAN_MAC/$LAN_MAC/g" \
  | sed "s/LAN_SUBN/$LAN_SUBN/g" \
  | sed "s/WAN0_INTF/$WAN0_INTF/g" \
  | sed "s/WAN0_IP/$WAN0_IP/g" \
  | sed "s/WAN0_MAC/$WAN0_MAC/g" \
  | sed "s/WAN0_SUBN/$WAN0_SUBN/g" \
  | sed "s/WAN0_TARGET/$WAN0_TARGET/g" \
  | sed "s/WAN1_INTF/$WAN1_INTF/g" \
  | sed "s/WAN1_IP/$WAN1_IP/g" \
  | sed "s/WAN1_MAC/$WAN1_MAC/g" \
  | sed "s/WAN1_SUBN/$WAN1_SUBN/g" \
  | sed "s/WAN1_TARGET/$WAN1_TARGET/g" > $TARGET_FILE