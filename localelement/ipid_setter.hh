#ifndef IP_ID_SETTER_HH
#define IP_ID_SETTER_HH

#include <click/config.h>
#include <click/element.hh>
#include <click/ipaddress.hh>
#include <click/packet.hh>
#include <clicknet/ip.h>
#include <click/atomic.hh>
#include <click/glue.hh>

CLICK_DECLS

class IpIdSetter : public Element {
public:
    IpIdSetter() : _next_id(0) {}
    ~IpIdSetter();
    const char *class_name() const override { return "IpIdSetter"; }
    const char *port_count() const override { return "1-/1-"; }
    int configure_ports(bool is_input, int nports, ErrorHandler *errh);
    const char *processing() const override { return PUSH; }

    void   push(int port, Packet *p);

private:
    uint16_t _next_id;
};

CLICK_ENDDECLS
#endif
