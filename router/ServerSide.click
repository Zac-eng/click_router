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
    input[0]
    -> [1]annotator :: IPPortAnnotator[1]
    -> UDPIPEncapAnno($host:ip, BrMain ,CHECKSUM true)
    -> SetIPAddress($gwip)
    -> LocalNIC($host, $hostnic, $arpnet)
    -> ipc_br :: Classifier(9/11 22/4E21, -)[0]
    -> [0]annotator[0]
    -> Strip(28)
    -> [0]output;

    ipc_br[1] -> Discard;
}

br_nic :: GlobalNIC(BrNIC, $BrNIC, BrNIC:ip, 172.31.32.1);
srv_nic :: LocalNIC(SrvNIC, $SrvNIC, arploc);

up ::
{ [0]
    -> CheckIPHeader()
    -> IPIn
    -> CheckTCPHeader()
    -> StripIPHeader()
    -> tIN :: TCPIn(FLOWDIRECTION 0, OUTNAME up/tOUT, RETURNNAME down/tIN, REORDER true, VERBOSE 1)
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
    -> CheckIPHeader()
    -> IPIn
    -> CheckTCPHeader()
    -> StripIPHeader()
    -> tIN :: TCPIn(FLOWDIRECTION 1, OUTNAME down/tOUT, RETURNNAME up/tIN, REORDER true, VERBOSE 1)
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

br_nic
-> Strip(14)


ipc_br[0]
-> upfc :: CTXManager(BUILDER 1, AGGCACHE false, CACHESIZE 65536, VERBOSE 1, EARLYDROP true)
-> usplit :: CTXDispatcher(9/06, -);

ipc_br[1] -> Discard;

usplit[0] -> up -> srv_nic;
usplit[1] -> CheckIPHeader() -> srv_nic;

srv_nic
-> Strip(14)
-> downfc :: CTXManager(BUILDER 1, AGGCACHE false, CACHESIZE 65536, VERBOSE 1, EARLYDROP true)
-> dsplit :: CTXDispatcher(9/06, -);

dsplit[0] -> down -> br_nic;
dsplit[1] -> br_nic;
