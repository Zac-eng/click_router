// replace variables below
// LAN_INTF , LAN_IP , LAN_MAC
// WAN0_INTF, WAN0_IP, WAN0_MAC, WAN0_SUBN, WAN0_TARGET
// WAN1_INTF, WAN1_IP, WAN1_MAC, WAN1_SUBN, WAN1_TARGET

cl :: Classifier(12/0806 20/0001,
                  12/0806 20/0002,
                  12/0800,
                  -);
c0 :: Classifier(12/0806 20/0001,
                  12/0806 20/0002,
                  12/0800,
                  -);
c1 :: Classifier(12/0806 20/0001,
                  12/0806 20/0002,
                  12/0800,
                  -);

FromDevice(LAN_INTF) -> [0]c0;
FromDevice(WAN0_INTF) -> [0]c0;
FromDevice(WAN1_INTF) -> [0]c1;

outl :: Queue(200) -> ToDevice(LAN_INTF)
out0 :: Queue(200) -> ToDevice(WAN0_INTF);
out1 :: Queue(200) -> ToDevice(WAN1_INTF);

arpql :: ARPQuerier(LAN_IP, LAN_MAC);
arpq0 :: ARPQuerier(WAN0_IP, WAN0_MAC);
arpq1 :: ARPQuerier(WAN1_IP, WAN1_MAC);

arl :: ARPResponder(LAN_IP LAN_MAC,
                    WAN0_SUBN LAN_MAC,
                    WAN1_SUBN LAN_MAC);
ar0 :: ARPResponder(WAN0_IP WAN0_MAC,
                    WAN0_SUBN WAN0_MAC);

ar1 :: ARPResponder(WAN1_IP WAN1_MAC,
                    WAN1_SUBN WAN1_MAC);                    

t :: Tee(3);
cl[1] -> t;
c0[1] -> t;
c1[1] -> t;

t[0] -> [0]arpql;
t[1] -> [0]arpq0;
t[2] -> [0]arpq1;

arpql -> outl;
arpq0 -> out0;
arpq1 -> out1;

cl[0] -> arl -> outl;
c0[0] -> ar0 -> out0;
c1[0] -> ar1 -> out1;

hs :: HashSwitch();

hs[0] -> IPEncap(3, WAN0_IP, WAN0_TARGET) -> [1]arpq0;
hs[1] -> IPEncap(3, WAN1_IP, WAN1_TARGET) -> [1]arpq1;

ipl :: Strip(14)
      -> hs;
ip0 :: Strip(14)
      -> Strip(20)
      -> rrs;
ip1 :: Strip(14)
      -> Strip(20)
      -> rrs;

cl[2] -> ipl;
c0[2] -> ip0;
c1[2] -> ip1;

rrs :: RoundRobinSched();

rrs[0] -> [1]arpql;
