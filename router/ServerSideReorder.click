define(    
    $BrProve 20000,
    $BrMain 20001,
    $BrNIC  eth0,
    $SrvNIC ethServer,
    $arpLoc 192.168.4.0/24
)

AddressInfo(
    BrNIC $BrNIC,
    SrvNIC $SrvNIC, 
    arploc $arpLoc
)
PortInfo(
    BrProve $BrProve,
    BrMain $BrMain
)

// ControlSocket(unix, /tmp/ntnl5g)

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

MPCG:: MultiPathGatewayServerSide(BrNIC:ip, BrProve, COM_TYPE SAT );

//br_todevice :: LocalTD(BrNIC, $BrNIC);
br_nic :: GlobalNIC(BrNIC, $BrNIC, BrNIC:ip, 172.31.32.1);
//srv_todevice :: LocalTD(SrvNIC, $SrvNIC);
srv_nic :: LocalNIC(SrvNIC, $SrvNIC, arploc);

// ********  Bridge Network
Idle -> br_nic;
// FromDevice($BrNIC) 
// -> c_br :: Classifier(12/0806 20/0002, 12/0800, -); 
// c_br[0] -> [1]br_todevice;
br_nic -> CheckIPHeader(OFFSET 14) -> Strip(14) ->
ipc_br :: IPClassifier( dst udp port BrProve,
                        dst udp port BrMain,
                        -) ;
// Probe packet
ipc_br[0] -> 
// Print(Probe, 40) -> 
[0]MPCG;

MPCG -> 
// Print(Encap, 40) -> 
GetIPAddress(16) -> br_nic;

up ::
{ [0]
    -> IPIn
    -> tIN :: TCPIn(FLOWDIRECTION 0, OUTNAME up/tOUT, RETURNNAME down/tIN, REORDER true)
    -> tOUT :: TCPOut(READONLY false, CHECKSUM true)
    -> IPOut(READONLY false, CHECKSUM true)
    -> [0]
}

down ::
{ [0]
    -> IPIn
    -> tIN :: TCPIn(FLOWDIRECTION 1, OUTNAME down/tOUT, RETURNNAME up/tIN, REORDER true)
    -> tOUT :: TCPOut(READONLY false, CHECKSUM true)
    -> IPOut(READONLY false, CHECKSUM true)
    -> [0]
}

// Capsulation packet
ipc_br[1] 
-> Strip (28)
-> up
-> srv_nic;

//etc
ipc_br[2] -> Discard;

// *********  Server Network
Idle -> srv_nic;
srv_nic -> Strip(14) -> down
    //-> Print("In Srv", 40) 
    -> [1]MPCG;