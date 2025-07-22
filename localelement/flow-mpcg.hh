#ifndef CLICK_FLOW_MPCG_HH
#define CLICK_FLOW_MPCG_HH

#include <click/flow/flowelement.hh>
#include <click/flowbuffer.hh>
#include <click/ipaddress.hh>
#include <click/vector.hh>

struct IPState {
    IPAddress ip;
    uint16_t port;
};

class FlowMPCG : public FlowSpaceElement<int> {

public:
    FlowMPCG() CLICK_COLD;
    ~FlowMPCG() CLICK_COLD;

    const char *class_name() const override { return "FlowMPCG"; }
    const char *processing() const override { return AGNOSTIC; }
    const char *flow_code() const override { return "ip/udp"; }
    const char *port_count() const override { return "2/1"; }
    int configure(Vector<String> &, ErrorHandler *) override;
    int initialize(ErrorHandler *) override;

    struct FlowState {
        IPState status;
    };

    void push_flow(int port, int* flowdata, PacketBatch* head);

private:
    IPAddress _global_ip;
    uint16_t _global_port;
    FlowState _source;
};

#endif
