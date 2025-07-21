define($INTFL ethClient)
define($INTFW enp1s0)
define($arpLoc 192.168.4.0/24)

AddressInfo(
  Intfl $INTFL,
  Intfw $INTFW,
  arploc $arpLoc
)

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

tab :: ARPTable

elementclass Receiver {$intf, $mac, $ip, $range |
    input[0]
    -> arpq :: ARPQuerier($ip, $mac, TABLE tab)
    -> etherOUT :: Null

    f :: FromDevice($intf)
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
    -> Print("RX ARP Request $mac", -1, ACTIVE $printarp)
    -> arpRespIN :: ARPResponder($range $mac)
    -> Print("TX ARP Responding", -1, ACTIVE $printarp)
    -> etherOUT;

    arpRespIN[1] -> Print("ARP Packet not for $mac", -1) -> Discard

    arpr[2]
    -> Print("RX ARP Response $mac", -1, ACTIVE $printarp)
    -> [1]arpq;

    arpr[3] -> Print("Unknown packet type IN???",-1, ACTIVE $printunknown) -> Discard();

    etherOUT
    -> Queue
    -> t :: ToDevice($intf)
}

r1 :: Receiver($INTFL, Intfl:eth, Intfl:ip, arploc);
r2 :: Receiver($INTFW, Intfw:eth, Intfw:ip, arploc);

r1
-> CheckIPHeader(CHECKSUM false)
-> r2;

r2
-> CheckIPHeader(CHECKSUM false)
-> r1;
