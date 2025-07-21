define(
    $CltGWPort 30000,
    $SrvGWProbe 20000,
    $SrvGWMain 20001,   
    $SatNIC0 wlp3s0,
//    $satgw0  172.20.10.1,
    $satgw0  10.18.254.254,
//    $SatNIC1 enx3897a475d974,
    $SatNIC1 enp1s0,
    $satgw1  10.11.254.254,
//    $SatNIC1 enp2s0,
//    $satgw1  10.0.3.2,
    $srvgw  18.183.98.17,
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











define(
    $LanNIC ethClient,
    $WanNIC wlp3s0,
//    $WanGW a4:53:0e:8b:6e:09,
)

AddressInfo(
    LanSrc $LanNIC,
    WanSrc $WanNIC,
)

elementclass LocalNIC {$host, $hostnic, $arpnet|
    FromDevice($hostnic ,PROMISC true, SNIFFER false, BURST 32) -> c:: Classifier(12/0806 20/0001, 12/0806 20/0002, 12/0800, -);
    c[0] -> ARPResponder($arpnet $host:eth) -> q:: Queue(8192) -> ToDevice($hostnic);
    c[1] -> [1]aq:: ARPQuerier($host:ip, $host:eth) -> q;
    c[2] -> [0]output;
    c[3] -> Discard;
    input[0] -> aq;
    aq[1] -> q;    
}

elementclass GlobalNIC {$host, $hostnic, $arpnet, $gwip|
    input[0] -> SetIPAddress($gwip) -> LocalNIC($host, $hostnic, $arpnet) -> [0]output;
}

-> espen :: IPsecESPEncap()
        -> cauth :: IPsecAuthHMACSHA1(0)
        -> encr :: IPsecAES(1)
        -> ipencap :: IPsecEncap(50)
