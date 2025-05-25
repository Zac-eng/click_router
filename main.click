define(
  $LanNic enx6c1ff71a039b,
  $WanNic enp2s0,
  $arplan 192.168.32.0/24,
  $arpwan 10.0.2.0/24,
)

AddressInfo(
  LanNic $LanNic,
  WanNic $WanNic,
  arplan $arplan,
  arpwan $arpwan
)

elementclass NIC {$host, $hostnic, $arpnet|
  FromDevice($hostnic) -> c:: Classifier(12/0806 20/0001, 12/0806 20/0002, 12/0800, -);
  // Arp Request
  c[0] -> ARPResponder($host:ip $host:eth, $arpnet $host:eth) -> q:: Queue -> ToDevice($hostnic);
  // Arp Response
  c[1] -> [1]aq:: ARPQuerier($host:ip, $host:eth) -> q;
  // ip packet from host
  c[2] -> [0]output;
  c[3] -> Discard;
  // ip packet to host
  input[0] -> aq;
  aq[1] -> q;
}

lan_nic :: NIC(LanNic, $LanNic, arpwan);
wan_nic :: NIC(WanNic, $WanNic, arplan);

lan_nic -> Strip(14)
-> CheckIPHeader()
-> GetIPAddress(16)
-> wan_nic;

wan_nic -> Strip(14)
-> CheckIPHeader()
-> GetIPAddress(16)
-> lan_nic;
