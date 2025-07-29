define(
  $LAN_INTF    ethServer,
  $LAN_IP      192.168.4.1,
  $LAN_MAC     5a:cc:15:4a:bd:36,
  $LAN_SUBN    192.168.4.0/24,
  $WAN0_INTF   enx3897a475d974,
  $WAN0_IP     10.0.0.3,
  $WAN0_MAC    38:97:a4:75:d9:74,
  $WAN0_SUBN   10.0.0.0/24,
  $WAN0_TARGET 10.0.0.2,
  $WAN1_INTF   eth0,
  $WAN1_IP     10.0.3.2,
  $WAN1_MAC    e4:5f:01:ef:0a:90,
  $WAN1_SUBN   10.0.0.0/24,
  $WAN1_TARGET 10.0.3.3,
)

// 12/0806 -> ARP, 12/0800 -> IPv4, 20/1 -> ARP request, 20/2 -> ARP reply
cl :: Classifier(12/0806 20/0001,
                  12/0806 20/0002,
                  12/0800,
                  -);
c0 :: Classifier(12/0806 20/0001,
                  12/0806 20/0002,
                  12/0800 23/32,
                  -);
c1 :: Classifier(12/0806 20/0001,
                  12/0806 20/0002,
                  12/0800 23/32,
                  -);
cl[3] -> Discard();
c0[3] -> Discard();
c1[3] -> Discard();

FromDevice($LAN_INTF) -> [0]cl;
FromDevice($WAN0_INTF) -> [0]c0;
FromDevice($WAN1_INTF) -> [0]c1;

outl :: Queue(1024) -> ToDevice($LAN_INTF);
out0 :: Queue(1024) -> ToDevice($WAN0_INTF);
out1 :: Queue(1024) -> ToDevice($WAN1_INTF);

arpql :: ARPQuerier($LAN_IP, $LAN_MAC);
// arpql1 :: ARPQuerier($LAN_IP, $LAN_MAC);
arpq0 :: ARPQuerier($WAN0_IP, $WAN0_MAC);
arpq1 :: ARPQuerier($WAN1_IP, $WAN1_MAC);

arpql -> outl;
// arpql1 -> outl;
arpq0 -> out0;
arpq1 -> out1;

arprl :: ARPResponder($LAN_SUBN $LAN_MAC,
                    $WAN0_SUBN $LAN_MAC,
                    $WAN1_SUBN $LAN_MAC);
arpr0 :: ARPResponder($WAN0_IP $WAN0_MAC,
                    $LAN_SUBN $WAN0_MAC,
                    $WAN1_SUBN $WAN0_MAC);
arpr1 :: ARPResponder($WAN1_IP $WAN1_MAC,
                    $LAN_SUBN $WAN1_MAC,
                    $WAN0_SUBN $WAN1_MAC);

cl[0] -> arprl -> outl;
c0[0] -> arpr0 -> out0;
c1[0] -> arpr1 -> out1;

// t :: Tee(2);

cl[1] -> [1]arpql;
// t[0] -> [1]arpql0;
// t[1] -> [1]arpql1;
c0[1] -> [1]arpq0;
c1[1] -> [1]arpq1;

rrs :: RoundRobinSwitch();
uq :: Unqueue();

cl[2] -> Strip(14) -> rrs;
c0[2] -> Strip(34) -> wanq :: Queue();
c1[2] -> Strip(34) -> wanq;

wanq -> uq -> CheckIPHeader() -> [0]arpql;

rrs[0] -> IPEncap(50, $WAN0_IP, $WAN0_TARGET) -> DecIPTTL() -> CheckIPHeader() -> [0]arpq0;
rrs[1] -> IPEncap(50, $WAN1_IP, $WAN1_TARGET) -> DecIPTTL() -> CheckIPHeader() -> [0]arpq1;
