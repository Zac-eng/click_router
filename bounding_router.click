define(
  $LAN_INTF    enx6c1ff71a039b,
//  $LAN_IP      192.168.86.1,
//  $LAN_MAC     d6:57:63:bd:45:64,
  $LAN_SUBN    192.168.86.0/24,
  $WAN0_INTF   enp1s0,
//  $WAN0_IP     192.168.11.3,
//  $WAN0_MAC    38:97:a4:75:d9:74,
  $WAN0_SUBN   192.168.11.0/24,
  $WAN0_TARGET 192.168.11.2,
  $WAN1_INTF   enp2s0,
//  $WAN1_IP     10.0.2.3,
//  $WAN1_MAC    c8:a3:62:5a:4e:d9,
  $WAN1_SUBN   10.0.2.0/24,
  $WAN1_TARGET 10.0.2.2,
)

AddressInfo(
  lan_intf $LAN_INTF,
  wan0_intf $WAN0_INTF,
  wan1_intf $WAN1_INTF
)

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

arpql :: ARPQuerier(lan_intf:ip, lan_intf:eth);
arpq0 :: ARPQuerier(wan0_intf:ip, wan0_intf:eth);
arpq1 :: ARPQuerier(wan1_intf:ip, wan1_intf:eth);

arpql -> outl;
arpq0 -> out0;
arpq1 -> out1;

arprl :: ARPResponder(lan_intf:ip, lan_intf:eth,
                    $WAN0_SUBN lan_intf:eth,
                    $WAN1_SUBN lan_intf:eth);
arpr0 :: ARPResponder(wan0_intf:ip, wan0_intf:eth,
                    $LAN_SUBN wan0_intf:eth,
                    $WAN1_SUBN wan0_intf:eth);
arpr1 :: ARPResponder(wan1_intf:ip, wan1_intf:eth,
                    $LAN_SUBN wan1_intf:eth,
                    $WAN0_SUBN wan1_intf:eth);

cl[0] -> arprl -> outl;
c0[0] -> arpr0 -> out0;
c1[0] -> arpr1 -> out1;

cl[1] -> [1]arpql;
c0[1] -> [1]arpq0;
c1[1] -> [1]arpq1;

hs :: HashSwitch(4, 2);
tcpro :: MyTCPReorder();

cl[2] -> Strip(14) -> hs;
c0[2] -> Strip(34) -> [0]tcpro;
c1[2] -> Strip(34) -> [1]tcpro;

tcpro[0] -> [0]arpql;
tcpro[1] -> Print -> [0]arpql;

hs[0] -> IPEncap(50, wan0_intf:ip, $WAN0_TARGET) -> DecIPTTL() -> [0]arpq0;
hs[1] -> IPEncap(50, wan1_intf:ip, $WAN1_TARGET) -> DecIPTTL() -> [0]arpq1;
