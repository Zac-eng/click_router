define(
  $NIC0 enp1s0,
  $gw0  192.168.10.1,
  $NIC1 enp2s0,
  $gw1  192.168.10.1,
  $srvgw  18.183.133.216,
  $LocNIC ethClient,
  $arpLoc 192.168.4.0/24
)

AddressInfo(
  Src0 $NIC0,
  gw0  $gw0,
  Src1 $NIC1,
  gw1  $gw1,
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

nic0 :: GlobalNIC(Src0, $NIC0, Src0:ip, gw0);
nic1 :: GlobalNIC(Src1, $NIC1, Src1:ip, gw1);
loc_nic :: LocalNIC(LocNIC, $LocNIC, arploc);

loc_nic
-> Strip(14)
-> InsertDSN()
-> rrs::RoundRobinSwitch();

rrs[0]
-> Queue(4096)
-> BandwidthRatedUnqueue(RATE 500000Bps, BURST 1)
-> UDPIPEncap(Src0:ip, SndPort, SrvGW:ip, RcvPort, CHECKSUM true)
-> CheckIPHeader(CHECKSUM false)
//-> IPFragmenter(1400)
-> nic0;

rrs[1]
-> Queue(4096)
-> BandwidthRatedUnqueue(RATE 500000Bps, BURST 1)
-> UDPIPEncap(Src1:ip, SndPort, SrvGW:ip, RcvPort, CHECKSUM true)
-> CheckIPHeader(CHECKSUM false)
//-> IPFragmenter(1400)
-> nic1;

nic0
-> Strip(14)
-> CheckIPHeader(CHECKSUM false)
//-> IPReassembler()
-> encapc0 :: Classifier(9/11 22/4e20, -)
-> StripIPHeader()
-> CheckUDPHeader(CHECKSUM false)
-> StripTransportHeader()
-> Queue(4096)
//-> sched :: DataSeqSched(BUFFER 1000);
-> sched :: RoundRobinSched();

encapc0[1] -> Discard;

nic1
-> Strip(14)
-> CheckIPHeader(CHECKSUM false)
//-> IPReassembler()
-> encapc1 :: Classifier(9/11 22/4e20, -)
-> StripIPHeader()
-> CheckUDPHeader(CHECKSUM false)
-> StripTransportHeader()
-> Queue(4096)
-> [1]sched;

encapc1[1] -> Discard;

sched
-> Unqueue()
//-> Strip(8)
-> CheckIPHeader(CHECKSUM false)
-> loc_nic;
