define(
  $LAN_INTF    bridge100,
  $LAN_IP      192.168.86.1,
  $LAN_MAC     d6:57:63:bd:45:64,
  $LAN_SUBN    192.168.86.0/24,
  $WAN0_INTF   en6,
  $WAN0_IP     192.168.11.3,
  $WAN0_MAC    38:97:a4:75:d9:74,
  $WAN0_SUBN   192.168.11.0/24,
  $WAN0_TARGET 192.168.11.2,
  $WAN1_INTF   en11,
  $WAN1_IP     10.0.2.3,
  $WAN1_MAC    c8:a3:62:5a:4e:d9,
  $WAN1_SUBN   10.0.2.0/24,
  $WAN1_TARGET 10.0.2.2,
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
arpq0 :: ARPQuerier($WAN0_IP, $WAN0_MAC);
arpq1 :: ARPQuerier($WAN1_IP, $WAN1_MAC);

arpql -> outl;
arpq0 -> out0;
arpq1 -> out1;

arprl :: ARPResponder($LAN_IP $LAN_MAC,
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

cl[1] -> [1]arpql;
c0[1] -> [1]arpq0;
c1[1] -> [1]arpq1;

hs :: HashSwitch(4, 2);
rrs :: RoundRobinSchedular();

cl[2] -> Strip(14) -> hs;
c0[2] -> Strip(34) -> [0]rrs;
c1[2] -> Strip(34) -> [1]rrs;

rrs -> TCPIn() -> CheckIPHeader() -> [0]arpql;

hs[0] -> IPEncap(50, $WAN0_IP, $WAN0_TARGET) -> DecIPTTL() -> [0]arpq0;
hs[1] -> IPEncap(50, $WAN1_IP, $WAN1_TARGET) -> DecIPTTL() -> [0]arpq1;
