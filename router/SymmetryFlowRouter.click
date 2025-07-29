define(    
    $SndPort 20000,
    $RcvPort 20001,
    $LocNIC  ethClient,
    $WidNIC0 enp1s0,
    $WidGW0  10.0.0.3,
    $WidNIC1 enp2s0,
    $WidGW1  10.0.3.2,
    $arpLoc  192.168.4.0/24
)

AddressInfo(
    WidNIC0 $WidNIC0,
    WidNIC1 $WidNIC1,
    LocNIC $LocNIC,
    WidGW0 $WidGW0,
    WidGW1 $WidGW1, 
    arploc $arpLoc
)

PortInfo(
    SndPort $SndPort,
    RcvPort $RcvPort
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
    //-> Unstrip(14)
        -> Discard

    arpr[1]
    -> arpRespIN :: ARPResponder($arpnet $host:eth)
    -> etherOUT;

    arpRespIN[1] -> Discard

    arpr[2]
    -> [1]arpq;

    arpr[3] -> Discard();

    etherOUT
    -> Queue
    -> t :: ToDevice($hostnic)
}

elementclass GlobalReceiver {$host, $hostnic, $arpnet, $gwip|
    input[0] -> SetIPAddress($gwip) -> Receiver($host, $hostnic, $arpnet) -> [0]output;
}

//MPCG:: FlowMPCG(WidNIC:ip, SndPort);

loc_nic :: Receiver(LocNIC, $LocNIC, arploc);
wid_nic0 :: Receiver(WidNIC0, $WidNIC0, WidNIC0:ip);
wid_nic1 :: Receiver(WidNIC1, $WidNIC1, WidNIC1:ip);

wid_nic0
-> CheckIPHeader()
-> ipc_br0 :: CTXDispatcher( 9/11 22/4E20 0,
                            9/11 22/4E21 1,
                            -);

ipc_br0[0] -> Discard;
//-> [0]MPCG;

wid_nic1
-> CheckIPHeader()
-> ipc_br1 :: CTXDispatcher( 9/11 22/4E20 0,
                            9/11 22/4E21 1,
                            -);

ipc_br1[0] -> Discard;

up ::
{ [0]
    -> IPIn
    -> CheckIPHeader()
    -> StripIPHeader()
    -> tIN :: TCPIn(FLOWDIRECTION 0, OUTNAME up/tOUT, RETURNNAME down/tIN, REORDER true, VERBOSE 1)
    -> tOUT :: TCPOut(READONLY false, CHECKSUM true)
    
    tIN[1] -> tOUT

    tOUT
    -> UnstripIPHeader()
    -> IPOut(READONLY false, CHECKSUM true)
    -> [0]
}

down ::
{ [0]
    -> IPIn
    -> CheckIPHeader()
    -> StripIPHeader()
    -> tIN :: TCPIn(FLOWDIRECTION 1, OUTNAME down/tOUT, RETURNNAME up/tIN, REORDER true, VERBOSE 1)
    -> tOUT :: TCPOut(READONLY false, CHECKSUM true)

    tIN[1] -> tOUT

    tOUT
    -> UnstripIPHeader()
    -> IPOut(READONLY false, CHECKSUM true)
    -> [0]
}

ipc_br0[1]
-> FlowStrip(28)
-> content_c0 :: CTXDispatcher(9/06 0,
                            -);

ipc_br1[1]
-> FlowStrip(28)
-> content_c1 :: CTXDispatcher(9/06 0,
                            -);

content_c0[0]
-> up
-> loc_nic;

content_c0[1]
-> loc_nic;

content_c1[0]
-> up
-> loc_nic;

content_c1[1]
-> loc_nic;

ipc_br0[2] -> Discard;
ipc_br1[2] -> Discard;

loc_nic
//-> [1]MPCG
-> down
-> scheduler :: RoundRobinSwitch();

scheduler[0]
-> UDPIPEncap(WidNIC0:ip, SndPort, WidGW0, RcvPort, CHECKSUM true)
-> wid_nic0;

scheduler[1]
-> UDPIPEncap(WidNIC1:ip, SndPort, WidGW1, RcvPort, CHECKSUM true)
-> wid_nic1;