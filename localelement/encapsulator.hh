#ifndef CLICK_MPGWSS_HH
#define CLICK_MPGWSS_HH
#include <click/element.hh>
#include <click/hashtable.hh>
#include <click/ipaddress.hh>
CLICK_DECLS

typedef struct {
    IPAddress ip;
    uint16_t port;
} IPStatus;

typedef enum {
    MOB_0 = 10,
    SAT_0 = 20
} allowType;
typedef uint8_t comType;

class Encapsulator : public Element {
public:
    Encapsulator() CLICK_COLD;
    ~Encapsulator() CLICK_COLD;

    const char *class_name() const override	{ return "Encapsulator"; }
    const char *port_count() const override	{ return "2/1"; }
    const char *processing() const override	{ return PUSH; }

    int configure(Vector<String> &conf, ErrorHandler *errh) CLICK_COLD;
    bool can_live_reconfigure() const		{ return true; }
    
    void push(int, Packet *p);
    void add_handlers() CLICK_COLD;

private:
    HashTable <comType, IPStatus> *_map_ip;
    IPAddress _global_ip;
    uint16_t  _global_port;  

    comType _at;
    void _printIPTable();    
};

CLICK_ENDDECLS
#endif
