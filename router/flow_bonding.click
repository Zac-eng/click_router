define($INTFL ethClient)
define($INTF1 enp1s0)
define($INTF2 enp2s0)
define($LOCALNET 192.168.4.0/24)

AddressInfo(
  Intfl $INTFL,
  Intf1 $INTF1,
  Intf2 $INTF2,
  Local $LOCALNET,
)

//Stack Parameters
define($inreorder 1) //Enable reordering
define($readonly 0) //Read-only (payload is never modified)
define($tcpchecksum 1) //Fix tcp checksum
define($checksumoffload 1) //Enable hardware checksum offload

//Debug parameters
define($rxverbose 99)
define($txverbose 99)
define($printarp 0)
define($printunknown 0)

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

tab :: ARPTable()

elementclass Receiver { $intf, $mac, $ip, $range |

    etherOUT :: Queue() -> ToDevice($intf)

    input[0]
    -> arpq :: ARPQuerier($ip, $mac, TABLE tab)
    -> etherOUT;

    f :: FromDevice($intf)
    -> fc :: CTXManager(BUILDER 1, AGGCACHE false, CACHESIZE 65536, VERBOSE 1, EARLYDROP true)
    -> arpr :: ARPDispatcher()

    arpr[0]
    -> FlowStrip(14)
    -> receivercheck :: CheckIPHeader(CHECKSUM false)
    -> inc :: CTXDispatcher(9/01 0, 9/06 0, -)


    inc[0] //TCP or ICMP
    -> CheckTCPHeader()
    -> [0]output;


    inc[1]
    -> IPPrint("UNKNOWN IP")
    -> Unstrip(14)
        -> Discard

    arpr[1]
    -> Print("RX ARP Request $mac", -1, ACTIVE $printarp)
    -> arpRespIN :: ARPResponder($ip $mac, $range $mac)
    -> Print("TX ARP Responding", -1, ACTIVE $printarp)
    -> etherOUT;

    arpRespIN[1] -> Print("ARP Packet not for $mac", -1) -> Discard

    arpr[2]
    -> Print("RX ARP Response $mac", -1, ACTIVE $printarp)
    -> [1]arpq;

    arpr[3] -> Print("Unknown packet type IN???",-1, ACTIVE $printunknown) -> Discard();

}

rl :: Receiver($INTFL, Intfl:eth ,Intfl:ip, Local);
r1 :: Receiver($INTF1, Intf1:eth ,Intf1:ip, Local);
r2 :: Receiver($INTF2, Intf2:eth ,Intf2:ip, Local);

rl
  ->  up ::
  { [0]
    -> IPIn
    -> Script
    -> Print(upin)
    -> tIN :: TCPIn(FLOWDIRECTION 0, OUTNAME up/tOUT, RETURNNAME down/tIN, REORDER $inreorder)
    -> TCPReorder()
    -> tOUT :: TCPOut(READONLY $readonly, CHECKSUM $tcpchecksum)
    -> Print(upout)
    -> IPOut(READONLY $readonly, CHECKSUM true)
    -> [0]
  }
  -> rrs :: FlowMinLoadSwitch();

rrs[0]  -> r1;
rrs[1]  -> r2;

down ::
  { [0]
    -> IPIn
    -> Script
    -> Print(downin)
    -> tIN :: TCPIn(FLOWDIRECTION 1, OUTNAME down/tOUT, RETURNNAME up/tIN, REORDER $inreorder)
    -> TCPReorder()
    -> tOUT :: TCPOut(READONLY $readonly, CHECKSUM $tcpchecksum)
    -> Print(downout)
    -> IPOut(READONLY $readonly, CHECKSUM true)
    -> [0]
  }
  -> rl;

r1 -> down;
r2 -> down;