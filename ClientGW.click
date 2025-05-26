define(
    $CltGWPort 30000,
    $SrvGWProbe 20000,    
    $SrvGWMain 20001,   
    $MobNIC ethMobNW,
    $mobgw  192.168.2.1,
    $SatNIC ethSatNW,
    $satgw  192.168.1.1,
    $srvgw  192.168.3.1,
    $LocNIC ethClient,
    $arpLoc 192.168.4.0/24
)

AddressInfo(
    MobSrc $MobNIC,
    MobGW  $mobgw,
    SatSrc $SatNIC,
    SatGW  $satgw,
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
    // Arp Request
    c[0] -> ARPResponder($arpnet $host:eth) -> q:: Queue -> ToDevice($hostnic);
    // Arp Response
    c[1] -> [1]aq:: ARPQuerier($host:ip, $host:eth) -> q;
    // ip packet from host
    c[2] -> [0]output;
    c[3] -> Discard;
    // ip packet to host
    input[0] -> aq;
    aq[1] -> q;    
}

elementclass GlobalNIC {$host, $hostnic, $arpnet, $gwip|
    input[0] -> SetIPAddress($gwip) -> LocalNIC($host, $hostnic, $arpnet) -> [0]output;
}

mob_nic :: GlobalNIC(MobSrc, $MobNIC, MobSrc:ip, MobGW);
sat_nic :: GlobalNIC(SatSrc, $SatNIC, SatSrc:ip, SatGW);
loc_nic :: LocalNIC(LocNIC, $LocNIC, arploc);


// ******** Mobile Network

// Beacon Packet
// Data 0x00000000 
// 1st byte 0x0a -> Mobile, 0x14 -> Sat
TimedSource(INTERVAL 1.0, DATA "0000") -> StoreData(0, \<0a000000>) ->beacon_t :: Tee()
-> UDPIPEncap(MobSrc:ip, CltGWPort, SrvGW:ip, SrvGWProbe, CHECKSUM true)
// -> Print("BeaMOB",40)
-> mob_nic;

// Capsulation Packet from Server side via Local 5G.
mob_nic -> Strip(14)  
-> Strip(28) -> CheckIPHeader()
// -> IPPrint("<- Mob")
-> GetIPAddress(16)  //Set ip annotation for arp
-> loc_nic;
//->Discard(); // Local Nic

// ******** Satellite Network
// Beacon Packet
beacon_t[1] 
-> StoreData(0,\<14>) // Modify 1st byte of Payload. 
-> UDPIPEncap(SatSrc:ip, CltGWPort, SrvGW:ip, SrvGWProbe, CHECKSUM true)
// -> Print("BeaSAT",40)
-> sat_nic;

// Capsulation Packet from Server side via NTN.
sat_nic -> Strip(14)  
-> Strip(28) -> CheckIPHeader()
// -> IPPrint("<- NTN")
-> GetIPAddress(16)  //Set ip annotation for arp
-> loc_nic;

hs :: HashSwitch(4, 2);

// ******** Local Network
loc_nic -> Strip(14) -> hs;

hs[0] -> UDPIPEncap(MobSrc:ip, CltGWPort, SrvGW:ip, SrvGWMain, CHECKSUM true)
-> mob_nic;

hs[1] -> UDPIPEncap(SatSrc:ip, CltGWPort, SrvGW:ip, SrvGWProbe, CHECKSUM true)
-> sat_nic;

Idle -> loc_nic;
