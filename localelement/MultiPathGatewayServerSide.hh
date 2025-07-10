#ifndef CLICK_MPGWSS_HH
#define CLICK_MPGWSS_HH
#include <click/element.hh>
#include <click/hashtable.hh>
#include <click/ipaddress.hh>
CLICK_DECLS

/*
 * =c
 * MultiPathGatewayServerSide(GLOBAL_IP, GLOBAL_PORT [, COM_TYPE])
 * =s MultiPathGatewayServerSide
 * Based on beacon packets, this elements select a communication path from Local 5G, NTN and so on.
 * =d
 * This element receives beacon packets from input 0 and builds a hash table.
 * The key of the hash table is the communication type: "MOB" (mobile network) and "SAT" (NTN).
 * The values in the hash table are the source IP, port of the beacon packet, and communication status.
 * Packets forwarded from input 1 are encapsulated using UDP/IP and sent to output 0.
 * The UDP/IP header includes src IP: GLOBAL_IP, src port: GLOBAL_PORT, and dst IP/port from the hash table.
 * COM_TYPE is either SAT (20) or MOB (10) and is updated via a write handler.
 */

typedef struct {
    IPAddress ip;
    uint16_t port;
    // uint8_t com_type;
} IPStatus;

typedef enum {
    MOB_0 = 10,
    SAT_0 = 20
} allowType;
typedef uint8_t comType;

class MultiPathGatewayServerSide : public Element {
public:
    MultiPathGatewayServerSide() CLICK_COLD;
    ~MultiPathGatewayServerSide() CLICK_COLD;

    const char *class_name() const override	{ return "MultiPathGatewayServerSide"; }
    const char *port_count() const override	{ return "2/1"; }
    const char *processing() const override	{ return PUSH; }
    

    // int initialize(ErrorHandler *) CLICK_COLD;
    int configure(Vector<String> &conf, ErrorHandler *errh) CLICK_COLD;
    bool can_live_reconfigure() const		{ return true; }
    
    void push(int, Packet *p);
    void add_handlers() CLICK_COLD;

private:
    HashTable <comType, IPStatus> *_map_ip;
    IPAddress _global_ip;
    uint16_t  _global_port;  

    //allowType _at;
    comType _at;
    void _printIPTable();    
};

CLICK_ENDDECLS
#endif
