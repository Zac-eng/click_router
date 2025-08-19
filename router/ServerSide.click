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
    input[0] -> SetIPAddress($gwip) -> LocalNIC($host, $hostnic, $arpnet) -> [0]output;
}

br_nic :: GlobalNIC(BrNIC, $BrNIC, BrNIC:ip, 172.31.32.1);
srv_nic :: LocalNIC(SrvNIC, $SrvNIC, arploc);

br_nic
-> Strip(14)
-> ipc_br :: Classifier(9/11 22/4E21, -)
-> annotator :: IPPortAnnotator
-> iprr :: IPRRSwitch();

ipc_br[1] -> Discard;

iprr[0] -> Strip(28) -> Queue -> BandwidthRatedUnqueue(RATE 20Mbps, BURST 1000) -> Queue -> rrsched :: RoundRobinSched();
iprr[1] -> Strip(28) -> Queue -> BandwidthRatedUnqueue(RATE 20Mbps, BURST 1000) -> Queue -> [1]rrsched;

rrsched -> Unqueue -> GetIPAddress(16) -> srv_nic;

srv_nic
-> [1]annotator[1]
-> UDPIPEncapAnno(BrNIC:ip, BrMain ,CHECKSUM true)
-> br_nic;
