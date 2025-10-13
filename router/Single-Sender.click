define(
  $GlbNIC enp2s0,
  $gw  192.168.1.1,
  $srvgw  35.77.85.175,
  $LocNIC ethClient,
  $arpLoc 192.168.4.0/24
)

AddressInfo(
  Src $GlbNIC,
  gw  $gw,
  SrvGW  $srvgw,
  LocNIC $LocNIC,
  arploc $arpLoc
)

PortInfo(
  SndPort 20000,
  RcvPort 20001
)

elementclass LocalNIC {$host, $hostnic, $arpnet|
  FromDevice($hostnic) -> c:: Classifier(12/0806 20/0001, 12/0806 20/0002, 12/0800, -);
  c[0] -> ARPResponder($arpnet $host:eth) -> q:: Queue(4096) -> ToDevice($hostnic);
  c[1] -> [1]aq:: ARPQuerier($host:ip, $host:eth) -> q;
  c[2] -> [0]output;
  c[3] -> Discard;
  input[0] -> aq;
  aq[1] -> q;
}

elementclass GlobalNIC {$host, $hostnic, $arpnet, $gwip|
  input[0] -> SetIPAddress($gwip) -> LocalNIC($host, $hostnic, $arpnet) -> [0]output;
}

glb_nic :: GlobalNIC(Src, $GlbNIC, Src:ip, gw);
loc_nic :: LocalNIC(LocNIC, $LocNIC, arploc);

loc_nic
-> Strip(14)
-> InsertDSN()
-> UDPIPEncap(Src:ip, SndPort, SrvGW:ip, RcvPort, CHECKSUM true)
-> CheckIPHeader(CHECKSUM false)
-> glb_nic;

glb_nic
-> Strip(14)
-> CheckIPHeader(CHECKSUM false)
-> encapc :: Classifier(9/11 22/4e20, -)
-> StripIPHeader()
-> CheckUDPHeader(CHECKSUM false)
-> StripTransportHeader()
-> CheckIPHeader(CHECKSUM false)
-> loc_nic;

encapc[1] -> Discard;
