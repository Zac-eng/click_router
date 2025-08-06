define(    
    $BrProve 20000,
    $BrMain 20001,
    $BrNIC  eth0,
    $SrvNIC ethServer,
    $br_fhp 172.31.32.1,
    $arpLoc 192.168.4.0/24
)

AddressInfo(
    BrNIC $BrNIC,
    SrvNIC $SrvNIC,
    br_fhp $br_fhp,
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
    input[0]
    -> UDPIPEncap($host:ip, BrMain, 210.148.150.77, 55666, CHECKSUM true)
    -> SetIPAddress($gwip)
    -> Receiver($host, $hostnic, $arpnet)
    -> CheckIPHeader()
    -> ipc_br :: CTXDispatcher( 9/11 22/4E21 0, -)[0]
    -> FlowStrip(28)
    -> [0]output;

    ipc_br[1] -> Discard
}

srv_nic :: Receiver(SrvNIC, $SrvNIC, arploc);
br_nic :: GlobalReceiver(BrNIC, $BrNIC, BrNIC:ip, br_fhp);

br_nic
-> uptcp :: TCPSplitter;

up ::
{ [0]
    -> IPIn
    -> CheckIPHeader()
    -> StripIPHeader()
    -> tIN :: TCPIn(FLOWDIRECTION 0, OUTNAME up/tOUT, RETURNNAME down/tIN, REORDER true, VERBOSE 1)
    -> UnstripIPHeader()
    -> retrans :: TCPRetransmitter(VERBOSE 1)
    -> tOUT :: TCPOut(READONLY false, CHECKSUM true)

    tIN[1] -> UnstripIPHeader() -> [1]retrans;

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
    -> tIN :: TCPIn(FLOWDIRECTION 1, OUTNAME down/tOUT, RETURNNAME up/tIN, REORDER true, VERBOSE 1)
    -> UnstripIPHeader()
    -> retrans :: TCPRetransmitter(VERBOSE 1)
    -> tOUT :: TCPOut(READONLY false, CHECKSUM true)

    tIN[1] -> UnstripIPHeader() -> [1]retrans;

    tOUT
    -> IPOut(READONLY false, CHECKSUM true)
    -> [0];

    tOUT[1]
    -> IPOut(READONLY false, CHECKSUM true)
    -> [1];
}

uptcp[0]
-> up
-> srv_nic;

up[1]
-> br_nic;

uptcp[1]
-> srv_nic;

srv_nic
-> downtcp :: TCPSplitter;

downtcp[0]
-> down
-> br_nic;

downtcp[1]
-> br_nic;

down[1]
-> srv_nic;