define(
  $BrMain 20001,
  $BrNIC  eth0,
  $SrvNIC ethServer,
  $SrvPort0 5201,
  $SrvPort1 5202,
  $arpLoc 192.168.4.0/24
)

AddressInfo(
    BrNIC $BrNIC,
    SrvNIC $SrvNIC, 
    arploc $arpLoc
)

PortInfo(
  BrMain   $BrMain,
)

elementclass LocalNIC {$host, $hostnic, $arpnet|
  FromDevice($hostnic) -> c:: Classifier(12/0806 20/0001, 12/0806 20/0002, 12/0800, -);
  c[0] -> ARPResponder($arpnet $host:eth) -> q:: Queue(4096) -> ToDevice($hostnic);
  c[1] -> [1]aq:: ARPQuerier($host:ip, $host:eth) -> q;
  c[2] -> Strip(14) -> [0]output;
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
  -> ipc_br :: Classifier(9/11 22/4E21, -)
  -> CheckIPHeader()
  -> [0]annotator[0]
  -> StripIPHeader()
  -> CheckUDPHeader()
  -> StripTransportHeader()
  -> [0]output;

  ipc_br[1] -> Discard;
}

br_nic :: GlobalNIC(BrNIC, $BrNIC, BrNIC:ip, 172.31.32.1);
srv_nic :: LocalNIC(SrvNIC, $SrvNIC, arploc);

br_nic
-> Queue(4096)
-> sched :: DataSeqSched(BUFFER 1000)
-> Unqueue()
-> Strip(8)
-> GetIPAddress(16)
-> srv_nic;

brc[1] -> Discard;

srv_nic
-> br_nic;
