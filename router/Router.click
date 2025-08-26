define(
  $NIC0 enp1s0,
  $gw0  10.0.3.2,
  $NIC1 enp2s0,
  $gw1  192.168.11.5,
  $LocNIC ethClient,
  $arpLoc 192.168.4.0/24
)

AddressInfo(
  Src0 $NIC0,
  gw0  $gw0,
  Src1 $NIC1,
  gw1  $gw1,
  LocNIC $LocNIC,
  arploc $arpLoc
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
-> rrs :: RoundRobinSwitch();

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
-> Queue()
-> rrsched :: RoundRobinSched();

nic1
-> Strip(14)
-> CheckIPHeader()
-> StripIPHeader()
-> Queue()
-> [1]rrsched;

rrsched
-> Unqueue()
-> loc_nic;