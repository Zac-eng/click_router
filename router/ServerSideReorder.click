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

elementclass ARPDispatcher {
        input[0]->
                iparp :: CTXDispatcher(
                        12/0800,
                        12/0806,
                        -)
                iparp[0] -> [0]output
                iparp[1] -> arptype ::CTXDispatcher(20/0001, 20/0002, -)
                iparp[2] -> [3]output

                arptype[0] -> [1]output
                arptype[1] -> [2]output
                arptype[2] -> [3]output
}

tab :: ARPTable

elementclass Receiver {$host, $hostnic, $arpnet |
    input[0]
    -> arpq :: ARPQuerier($host:ip, $host:eth, TABLE tab)
    -> etherOUT :: Null

    f :: FromDevice($hostnic)
    -> fc :: CTXManager(BUILDER 1, AGGCACHE false, CACHESIZE 65536, VERBOSE 1, EARLYDROP true)
    -> arpr :: ARPDispatcher()

    arpr[0]
    -> FlowStrip(14)
    -> receivercheck :: CheckIPHeader(CHECKSUM false)
    -> inc :: CTXDispatcher(9/01 0, 9/06 0, 9/11 0, -)


    inc[0] //TCP or ICMP
    -> [0]output;


    inc[1]
    -> IPPrint("UNKNOWN IP")
    -> Unstrip(14)
        -> Discard

    arpr[1]
    -> arpRespIN :: ARPResponder($range $mac)
    -> etherOUT;

    arpRespIN[1] -> Print("ARP Packet not for $host:eth", -1) -> Discard

    arpr[2]
    -> Print("RX ARP Response $host:eth", -1, ACTIVE $printarp)
    -> [1]arpq;

    arpr[3] -> Print("Unknown packet type IN???",-1, ACTIVE) -> Discard();

    etherOUT
    -> Queue
    -> t :: ToDevice($hostnic)
}

elementclass GlobalReceiver {$host, $hostnic, $arpnet, $gwip|
    input[0] -> SetIPAddress($gwip) -> Receiver($host, $hostnic, $arpnet) -> [0]output;
}

MPCG:: MultiPathGatewayServerSide(BrNIC:ip, BrProve, COM_TYPE SAT );

rl :: Receiver(SrvNIC, $SrvNIC, arploc);
rw :: GlobalReceiver(BrNIC, $BrNIC, BrNIC:ip, 172.31.32.1);

// ********  Bridge Network
Idle -> br_nic;
// FromDevice($BrNIC) 
// -> c_br :: Classifier(12/0806 20/0002, 12/0800, -); 
// c_br[0] -> [1]br_todevice;
br_nic -> CheckIPHeader(OFFSET 14) -> FlowStrip(14) ->
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
    -> Print(upin, MAXLENGTH 28)
    -> tIN :: TCPIn(FLOWDIRECTION 0, OUTNAME up/tOUT, RETURNNAME down/tIN, REORDER true)
    -> tOUT :: TCPOut(READONLY false, CHECKSUM true)
    -> Print(upout, MAXLENGTH 28)
    -> IPOut(READONLY false, CHECKSUM true)
    -> [0]
}

down ::
{ [0]
    -> IPIn
    -> Print(downin, MAXLENGTH 28)
    -> tIN :: TCPIn(FLOWDIRECTION 1, OUTNAME down/tOUT, RETURNNAME up/tIN, REORDER true)
    -> tOUT :: TCPOut(READONLY false, CHECKSUM true)
    -> Print(downout, MAXLENGTH 28)
    -> IPOut(READONLY false, CHECKSUM true)
    -> [0]
}

// Capsulation packet
ipc_br[1] 
-> FlowStrip (28)
-> up
-> srv_nic;

//etc
ipc_br[2] -> Discard;

// *********  Server Network
Idle -> srv_nic;
srv_nic -> FlowStrip(14) -> down
    //-> Print("In Srv", 40) 
    -> [1]MPCG;