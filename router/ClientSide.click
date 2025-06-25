define(
    $CltGWPort 30000,
    $SrvGWProbe 20000,
    $SrvGWMain 20001,   
    $SatNIC0 wlp3s0,
    $satgw0  10.18.254.254,
    $SatNIC1 enx3897a475d974,
    $satgw1  10.11.254.254,
    $srvgw  13.112.109.3,
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

TimedSource(INTERVAL 1.0, DATA "0000") -> StoreData(0, \<0a000000>) ->beacon_t :: Tee()
-> UDPIPEncap(SatSrc0:ip, CltGWPort, SrvGW:ip, SrvGWProbe, CHECKSUM true)
-> sat_nic0;

sat_nic0 -> Strip(14)  
-> Strip(28) -> CheckIPHeader()
-> GetIPAddress(16)  //Set ip annotation for arp
-> loc_nic;

beacon_t[1] 
-> StoreData(0,\<14>)
-> UDPIPEncap(SatSrc1:ip, CltGWPort, SrvGW:ip, SrvGWProbe, CHECKSUM true)
-> sat_nic1;

sat_nic1 -> Strip(14)  
-> Strip(28) -> CheckIPHeader()
-> GetIPAddress(16)
-> loc_nic;

rrs :: RoundRobinSwitch();
idsetter :: IpIdSetter();

loc_nic -> Strip(14) -> rrs;

rrs[0]
-> UDPIPEncap(SatSrc0:ip, CltGWPort, SrvGW:ip, SrvGWMain, CHECKSUM false)
-> [0]idsetter[0]
-> SetIPChecksum()
-> Print(output0)
-> sat_nic0;

rrs[1]
-> UDPIPEncap(SatSrc1:ip, CltGWPort, SrvGW:ip, SrvGWMain, CHECKSUM false)
-> [1]idsetter[1]
->SetIPChecksum()
-> Print(output1)
-> sat_nic1;

Idle -> loc_nic;
