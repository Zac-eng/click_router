define(
  
)

elementclass DPDKNic {$index, $|
  FromDPDKDevice($index) -> c:: Classifier(12/0806 20/0001, 12/0806 20/0002, 12/0800, -);
    c[0] -> ARPResponder($arpnet $host:eth) -> q:: Queue -> ToDevice($hostnic);
    c[1] -> [1]aq:: ARPQuerier($host:ip, $host:eth) -> q;
    // ip packet from host
    c[2] -> [0]output;
    c[3] -> Discard;
    // ip packet to host
    input[0] -> aq;
    aq[1] -> q;    
}

FromDPDKDevice(0) -> Print -> Discard;