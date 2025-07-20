define($INTFL ethServer)
define($INTFW enx3897a475d974)

AddressInfo(
  Intfl $INTFL,
  Intfw $INTFW,
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

lnic :: NIC(Intfl, $INTFL, Intfl:ip);
wnic :: NIC(Intfw, $INTFW, Intfw:ip);

lnic -> Strip(14) -> rs :: RandomSwitch();
rs[0] -> Queue -> [0]rruq :: RoundRobinUnqueue() -> CheckIPHeader()-> wnic
rs[1] -> Queue -> [1]rruq;

wnic -> lnic;
