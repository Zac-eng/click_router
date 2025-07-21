#include "mytcpreorder.hh"
CLICK_DECLS

#define TABLE_CAP 20

MyTCPReorder::MyTCPReorder()
: _next_seq(0)
{
  _packet_map = new HashTable<uint32_t, Packet *>;
}

MyTCPReorder::~MyTCPReorder() {
    for (HashTable <uint32_t, Packet *>::iterator it = _packet_map->begin(); it != _packet_map->end(); ++it) {
        it->second->kill();
    }
    delete _packet_map;
}

int
MyTCPReorder::configure(Vector<String> & conf, ErrorHandler *errh)
{
  return 0;
}

void
MyTCPReorder::flush_packets()
{
  while (true) {
    Packet* next_packet = _packet_map->get(_next_seq);
    if (!next_packet) {
      break;
    }
    output(0).push(next_packet);
    _packet_map->erase(_next_seq);
    ++_next_seq;
  }
}

void
MyTCPReorder::push(int port, Packet *p)
{
    click_ip     *iph = (click_ip *) (p -> ip_header());
    if (!iph || iph->ip_p != IP_PROTO_TCP) {
        // Not a TCP packet, pass it through
        output(0).push(p);
        return;
    }
    const click_tcp *tcph = p->tcp_header();
    if (!tcph) {
        output(0).push(p);
        return;
    }
    uint32_t seq = ntohl(tcph->th_seq);
    if (seq == _next_seq) {
        click_chatter("in sequence: %d\n", seq);
        output(0).push(p);
        ++_next_seq;
        flush_packets();
    }
    else if (seq < _next_seq) {
        click_chatter("out-of-order, killed: %d\n", seq);
        p->kill();
    }
    else {
        click_chatter("out-of-order: %d, size: %d\n", seq, _packet_map->size());
        (*_packet_map)[seq] = p->clone();
        p->kill();
        if (_packet_map->size() > TABLE_CAP) {
            while (!_packet_map->get(_next_seq)) {
                ++_next_seq;
            }
            flush_packets();
        }
    }
}

CLICK_ENDDECLS
EXPORT_ELEMENT(MyTCPReorder)
ELEMENT_MT_SAFE(MyTCPReorder)
