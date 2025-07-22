#include <click/config.h>
#include <click/args.hh>
#include <clicknet/ip.h>
#include <clicknet/udp.h>
#include <click/glue.hh>
#include <click/error.hh>
#include "flow-mpcg.hh"

CLICK_DECLS

FlowMPCG::FlowMPCG() {}

FlowMPCG::~FlowMPCG() {}

int FlowMPCG::configure(Vector<String> &conf, ErrorHandler *errh) {
    if (Args(conf, this, errh)
        .read_mp("GLOBAL_IP", _global_ip)
        .read_mp("GLOBAL_PORT", IPPortArg(IP_PROTO_UDP), _global_port)
        .complete() < 0)
        return -1;
    click_chatter("Configured with global IP %s, port %u", _global_ip.unparse().c_str(), _global_port);
    return 0;
}

int FlowMPCG::initialize(ErrorHandler *) {
    return 0;
}

void FlowMPCG::push_flow(int port, int* flowdata, PacketBatch* head) {
    for (Packet *p = head->first(); p != head->tail(); ++p) {
        FlowState *fstate = &_source;

        if (port == 0) {
            // Learn source IP/port and map it by payload header
            click_ip *iph = (click_ip *)(p->data());
            IPAddress src_ip = IPAddress(iph->ip_src);

            click_udp *udph = (click_udp *)(p->data() + sizeof(click_ip));
            uint16_t src_port = ntohs(udph->uh_sport);

            uint8_t *payh = (uint8_t *)(p->data() + sizeof(click_ip) + sizeof(click_udp));

            fstate->status = IPState{src_ip, src_port};
            p->kill(); // Drop learning packet
        } else if (port == 1) {
            // Rewrite with stored IP and port
            IPState st = fstate->status;

            WritablePacket *wp = p->push(sizeof(click_ip) + sizeof(click_udp));
            click_ip *iph = reinterpret_cast<click_ip *>(wp->data());
            click_udp *udph = reinterpret_cast<click_udp *>(wp->data() + sizeof(click_ip));

            iph->ip_v = 4;
            iph->ip_hl = sizeof(click_ip) >> 2;
            iph->ip_len = htons(wp->length());
            iph->ip_id = htons(0);
            iph->ip_p = IP_PROTO_UDP;
            iph->ip_src = _global_ip.in_addr();
            iph->ip_dst = st.ip.in_addr();
            iph->ip_tos = 0;
            iph->ip_off = 0;
            iph->ip_ttl = 64;
            iph->ip_sum = 0;
            iph->ip_sum = click_in_cksum((unsigned char *)iph, sizeof(click_ip));

            wp->set_ip_header(iph, sizeof(click_ip));

            udph->uh_sport = htons(_global_port);
            udph->uh_dport = htons(st.port);
            uint16_t len = wp->length() - sizeof(click_ip);
            udph->uh_ulen = htons(len);
            udph->uh_sum = 0;
            unsigned csum = click_in_cksum((unsigned char *)udph, len);
            udph->uh_sum = click_in_cksum_pseudohdr(csum, iph, len);

            output(0).push(wp);
        }
    }
}

CLICK_ENDDECLS
EXPORT_ELEMENT(FlowMPCG)
ELEMENT_MT_SAFE(FlowMPCG)
