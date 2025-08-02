#ifndef FLOW_IPPORT_ANNOTATOR_HH
#define FLOW_IPPORT_ANNOTATOR_HH

#include <click/config.h>
#include <click/args.hh>
#include <click/error.hh>
#include <clicknet/ip.h>
#include <clicknet/udp.h>
#include <click/packet.hh>
#include <click/packet_anno.hh>
#include <click/element.hh>
#include <click/glue.hh>
#include <click/batchelement.hh>

#ifndef UDP_DPORT_ANNO 
#define UDP_DPORT_ANNO 40
#endif

struct IPPortInfo {
    uint32_t ip;
    uint16_t port;
};

class IPPortAnnotator : public BatchElement {
public:
    IPPortAnnotator() {}

    const char *class_name() const override { return "IPPortAnnotator"; }
    const char *port_count() const override { return "2/2"; }
    const char *processing() const override { return "h/h"; }

    int configure(Vector<String> &, ErrorHandler *) override;

    void push_batch(int port, PacketBatch *batch) override;

private:
    IPPortInfo _stored_info;
};


#endif
