// replace variables below
// LAN_INTF , LAN_IP , LAN_MAC
// WAN0_INTF, WAN0_IP, WAN0_MAC, WAN0_SUBN, WAN0_TARGET
// WAN1_INTF, WAN1_IP, WAN1_MAC, WAN1_SUBN, WAN1_TARGET

c0 :: Classifier(12/0806 20/0001,
                  12/0806 20/0002,
                  12/0800,
                  -);

FromDevice(LAN_INTF) -> [0]c0;

outl :: Queue(200) -> ToDevice(LAN_INTF)
out0 :: Queue(200) -> ToDevice(WAN0_INTF);
out1 :: Queue(200) -> ToDevice(WAN1_INTF);

arpql :: ARPQuerier(LAN_IP, LAN_MAC);
arpq0 :: ARPQuerier(WAN0_IP, WAN0_MAC);
arpq1 :: ARPQuerier(WAN1_IP, WAN1_MAC);

t :: Tee(3);
c0[1] -> t;

t[0] -> arpql;
t[1] -> arpq0;
t[2] -> arpq1;

arpql -> outl;
arpq0 -> out0
arpq1 -> out1;

ar :: ARPResponder(LAN_IP LAN_MAC,
                    WAN0_SUBN LAN_MAC,
                    WAN1_SUBN LAN_MAC);

c0[0] -> ar -> outl;

hs :: HashSwitch();

ip :: Strip(14)
      -> hs;

c0[2] -> ip;

hs[0] -> IPEncap(3, WAN0_IP, WAN0_TARGET) -> arpq0;

hs[1] -> IPEncap(3, WAN1_IP, WAN1_TARGET) -> arpq1;
