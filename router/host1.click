define(
  $NIC0 eth0,
  $gw0  10.0.3.3,
  $NIC1 enxc8a3625a4ed9,
  $gw1  192.168.11.4,
  $LocNIC ethServer,
  $arpLoc 192.168.4.0/24,
  $BandWidth 100000000Bps
)

AddressInfo(
  Src0 $NIC0,
  gw0  $gw0,
  Src1 $NIC1,
  gw1  $gw1,
  LocNIC $LocNIC,
  arploc $arpLoc
)

PortInfo(
  FixedPort 20001
)

elementclass LocalNIC {$host, $hostnic, $arpnet|
  FromDevice($hostnic) -> c:: Classifier(12/0806 20/0001, 12/0806 20/0002, 12/0800, -);
  c[0] -> ARPResponder($arpnet $host:eth) -> q:: Queue -> ToDevice($hostnic);
  c[1] -> [1]aq:: ARPQuerier($host:ip, $host:eth) -> q;
  c[2] -> [0]output;
  c[3] -> Discard;
  input[0] -> aq;
  aq[1] -> q;
}

nic0 :: LocalNIC(Src0, $NIC0, Src0:ip);
nic1 :: LocalNIC(Src1, $NIC1, Src1:ip);
loc_nic :: LocalNIC(LocNIC, $LocNIC, arploc);

loc_nic
-> Strip(14)
-> SetTimestamp()
-> PushTimestamp()
-> rrs::RoundRobinSwitch();

rrs[0]
-> IPEncap(32, Src0:ip, gw0)
-> GetIPAddress(16)
-> nic0;

rrs[1]
-> IPEncap(32, Src0:ip, gw0)
-> GetIPAddress(16)
-> nic1;


nic0
-> Strip(14)
-> CheckIPHeader()
-> StripIPHeader()
-> ExtractTimestampAnno()
-> Strip(8)
-> Queue()
-> sched :: TimeSortedSched();

nic1
-> Strip(14)
-> CheckIPHeader()
-> StripIPHeader()
-> ExtractTimestampAnno()
-> Strip(8)
-> Queue()
-> [1]sched;

sched
-> Unqueue()
-> GetIPAddress(16)
-> loc_nic;
