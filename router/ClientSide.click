define(
    $CltGWPort 30000,
    $SrvGWProbe 20000,
    $SrvGWMain 20001,
    $SrvPort0 5201,
    $SrvPort1 5202,
    $SatNIC0 enp1s0,
    $satgw0  192.168.1.1,
    $SatNIC1 enp2s0,
    $satgw1  192.168.1.1,
    $srvgw  43.207.174.2,
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
    SrvGWMain  $SrvGWMain,
    SrvPort0   $SrvPort0,
    SrvPort1   $SrvPort1
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

sat_nic0
-> Strip(14)
-> sat0_cl :: Classifier(9/11 22/7530, -)
-> Strip(28)
-> CheckIPHeader()
-> loc_nic;

sat0_cl[1] -> Discard;

sat_nic1
-> Strip(14)
-> sat1_cl :: Classifier(9/11 22/7530, -)
-> Strip(28)
-> CheckIPHeader()
-> loc_nic;

sat1_cl[1]->Discard;

switch :: {
    input[0]
    -> CheckIPHeader()
    -> ipc :: IPClassifier(
        dst tcp port SrvPort0,
        dst tcp port SrvPort1,
        -
    )

    ipc[0] -> [0]output;
    ipc[1] -> [1]output;
    ipc[2] -> Discard;
};

//switch :: {
//    input[0] -> [0]output;
//    Idle -> [1]output;
//}

loc_nic
-> Strip(14)
-> switch;

switch[0]
-> UDPIPEncap(SatSrc0:ip, CltGWPort, SrvGW:ip, SrvGWMain, CHECKSUM true)
-> sat_nic0;

switch[1]
-> UDPIPEncap(SatSrc1:ip, CltGWPort, SrvGW:ip, SrvGWMain, CHECKSUM true)
-> sat_nic1;
