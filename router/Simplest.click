define(
    $LanNIC enp2s0,
    $WanNIC enp1s0,
    $WanGW a4:53:0e:8b:6e:09,
    $SevGW 52.195.209.173,
)

AddressInfo(
    LanSrc $LanNIC,
    WanSrc $WanNIC,
)

elementclass NIC {$host, $hostnic, $arpnet|
    FromDevice($hostnic) -> c:: Classifier(12/0806 20/0001, 12/0806 20/0002, 12/0800, -);
    c[0] -> ARPResponder($arpnet $host:eth) -> q:: Queue(8192) -> ToDevice($hostnic);
    c[1] -> [1]aq:: ARPQuerier($host:ip, $host:eth) -> q;
    c[2] -> [0]output;
    c[3] -> Discard;
    input[0] -> aq;
    aq[1] -> q;    
}

// loc_nic :: NIC(LanSrc, $LanNIC, LanSrc:ip);
// wid_nic :: NIC(WanSrc, $WanNIC, WanSrc:ip);

FromDevice($LanNIC) -> cl:: Classifier(12/0806 20/0001, 12/0806 20/0002, 12/0800, -);
cl[0] -> ARPResponder(LanSrc:ip LanSrc:eth) -> ql:: Queue(8192) -> ToDevice($LanNIC);
cl[1] -> [1]aql:: ARPQuerier(LanSrc:ip, LanSrc:eth) -> ql;
cl[3] -> Discard;
aql[1] -> ql;

FromDevice($WanNIC) -> cw:: Classifier(12/0806 20/0001, 12/0806 20/0002, 12/0800, -);
cw[0] -> ARPResponder(WanSrc:ip WanSrc:eth) -> qw:: Queue(8192) -> ToDevice($WanNIC);
// cw[1] -> [1]aqw:: ARPQuerier(WanSrc:ip, WanSrc:eth) -> qw;
cw[1] -> Discard;
cw[3] -> Discard;
// aqw[1] -> qw;

cl[2] -> EtherRewrite(38:97:a4:75:d9:74, a4:53:0e:8b:6e:09) -> qw;
cw[2] -> Strip(14) -> CheckIPHeader() -> GetIPAddress(16) -> aql;
