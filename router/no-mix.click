//define($INTFL ethServer)
define($INTFL ethClient)
//define($INTFW enx3897a475d974)
define($INTFW enp1s0)
define($arpLoc 192.168.4.0/24)

AddressInfo(
  Intfl $INTFL,
  Intfw $INTFW,
  arploc $arpLoc
)

elementclass NIC {$host, $hostnic, $arpnet|
    FromDevice($hostnic) -> c:: Classifier(12/0806 20/0001, 12/0806 20/0002, 12/0800, -);
    c[0] -> ARPResponder($arpnet $host:eth) -> q:: Queue -> ToDevice($hostnic);
    c[1] -> [1]aq:: ARPQuerier($host:ip, $host:eth) -> q;
    c[2] -> [0]output;
    c[3] -> Discard;
    input[0] -> aq;
    aq[1] -> q;
}

lnic :: NIC(Intfl, $INTFL, arploc);
wnic :: NIC(Intfw, $INTFW, arploc);

lnic -> Strip(14) -> CheckIPHeader(CHECKSUM false) -> GetIPAddress(16) -> wnic;

wnic -> Strip(14) -> CheckIPHeader(CHECKSUM false) -> GetIPAddress(16) -> lnic;