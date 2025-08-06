define(
    $CltGWPort 30000,
    $SrvGWProbe 20000,
    $SrvGWMain 20001,
    $SatNIC0 wlp3s0,
    $satgw0  10.18.254.254,
    $SatNIC1 enp2s0,
    $satgw1  10.11.254.254,
    $srvgw  13.231.243.217,
    $LocNIC ethClient,
    $arpLoc 192.168.4.0/24
)

AddressInfo(
    SatNIC0 $SatNIC0,
    satgw0  $satgw0,
    SatNIC1 $SatNIC1,
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

elementclass TCPSplitter {
  input[0]-> dispatcher :: CTXDispatcher(
    9/06,
    -)
  dispatcher[0] -> [0]output
  dispatcher[1] -> [1]output
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
    input[0] -> SetIPAddress($gwip)
    -> Receiver($host, $hostnic, $arpnet)
    -> CheckIPHeader()
    -> ipc_br :: CTXDispatcher(9/11 22/7530 0, -)

    ipc_br[0]
    -> FlowStrip(28)
    -> tcpsplt :: TCPSplitter

    ipc_br[1] -> Discard;

    tcpsplt[0] -> [0]output;
    tcpsplt[1] -> [1]output;
}

loc_nic :: Receiver(LocNIC, $LocNIC, arploc);
sat_nic0 :: GlobalReceiver(SatNIC0, $SatNIC0, SatNIC0:ip, satgw0);
sat_nic1 :: GlobalReceiver(SatNIC1, $SatNIC1, SatNIC1:ip, satgw1);

up ::
{ [0]
    -> IPIn
    -> CheckIPHeader()
    -> CheckTCPHeader()
    -> StripIPHeader()
    -> Print
    -> tIN :: TCPIn(FLOWDIRECTION 0, OUTNAME up/tOUT, RETURNNAME down/tIN, REORDER true, VERBOSE 1, PROACK 0)
    -> UnstripIPHeader()
    -> retrans :: TCPRetransmitter(VERBOSE 1)
    -> tOUT :: TCPOut(READONLY false, CHECKSUM true)

    tIN[1] -> UnstripIPHeader() -> Print(upin1) -> [1]retrans;

    tOUT
    -> IPOut(READONLY false, CHECKSUM true)
    -> [0];

    tOUT[1]
    -> IPOut(READONLY false, CHECKSUM true)
    -> [1];
}

down ::
{ [0]
    -> IPIn
    -> CheckIPHeader()
    -> CheckTCPHeader()
    -> StripIPHeader()
    -> Print()
    -> tIN :: TCPIn(FLOWDIRECTION 1, OUTNAME down/tOUT, RETURNNAME up/tIN, REORDER true, VERBOSE 1, PROACK 0)
    -> UnstripIPHeader()
    -> retrans :: TCPRetransmitter(VERBOSE 1)
    -> tOUT :: TCPOut(READONLY false, CHECKSUM true)

    tIN[1] -> UnstripIPHeader() -> Print(downin1) -> [1]retrans;

    tOUT
    -> IPOut(READONLY false, CHECKSUM true)
    -> [0];

    tOUT[1]
    -> IPOut(READONLY false, CHECKSUM true)
    -> [1];
}

rrs :: StrideSwitch(0, 1);

sat_nic0[0]
-> Print(intodown)
-> down;

sat_nic0[1]
-> CheckIPHeader()
-> loc_nic;

sat_nic1[0]
-> Print(intodown)
-> down;

sat_nic1[1]
-> CheckIPHeader()
-> loc_nic;

down
-> loc_nic;

down[1]
-> rrs;

loc_nic
-> uptcp :: TCPSplitter;

uptcp[0]
-> up
-> rrs;

uptcp[1]
-> rrs;

up[1]
-> loc_nic;

rrs[0]
-> UDPIPEncap(SatNIC0:ip, CltGWPort, SrvGW:ip, SrvGWMain, CHECKSUM true)
-> sat_nic0;

rrs[1]
-> UDPIPEncap(SatNIC1:ip, CltGWPort, SrvGW:ip, SrvGWMain, CHECKSUM true)
-> sat_nic1;