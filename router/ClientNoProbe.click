define(
    $CltGWPort 30000,
    $SrvGWProbe 20000,
    $SrvGWMain 20001,   
//    $SatNIC0 wlp3s0,
//    $satgw0  172.20.10.1,
    $SatNIC0 enp1s0,
    $satgw0  10.11.254.254,
//    $SatNIC1 enx3897a475d974,
    $SatNIC1 enp2s0,
    $satgw1  10.11.254.254,
    $srvgw  54.65.71.156,
    $LocNIC ethClient,
    $arpLoc 192.168.4.0/24
)

AddressInfo(
    SatSrc0 $SatNIC0,
    satgw0  $satgw0,
    SatSrc1 $SatNIC1,
    satgw1  $satgw1,
    SrvGW  $srvgw,
    LocNIC $LocNIC,
    arploc $arpLoc
)

PortInfo(
    CltGWPort  $CltGWPort,
    SrvGWProbe $SrvGWProbe,
    SrvGWMain  $SrvGWMain
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

elementclass GlobalNIC {$host, $hostnic, $arpnet, $gwip|
    input[0] -> SetIPAddress($gwip) -> LocalNIC($host, $hostnic, $arpnet) -> [0]output;
}

sat_nic0 :: GlobalNIC(SatSrc0, $SatNIC0, SatSrc0:ip, satgw0);
sat_nic1 :: GlobalNIC(SatSrc1, $SatNIC1, SatSrc1:ip, satgw1);
loc_nic :: LocalNIC(LocNIC, $LocNIC, arploc);

sat_nic0 -> Strip(14)  
-> Strip(28)
-> CheckIPHeader()
-> loc_nic;

sat_nic1 -> Strip(14)  
-> Strip(28)
-> CheckIPHeader()
-> loc_nic;

rrs :: StrideSwitch(1, 0);
//rrs :: {
//    input[0] -> [1]output;
//    Idle -> [0]output;
//}

loc_nic -> Strip(14) -> rrs;

rrs[0]
-> UDPIPEncap(SatSrc0:ip, CltGWPort, SrvGW:ip, SrvGWMain, CHECKSUM true)
-> sat_nic0;

rrs[1]
-> UDPIPEncap(SatSrc1:ip, CltGWPort, SrvGW:ip, SrvGWMain, CHECKSUM true)
-> sat_nic1;
