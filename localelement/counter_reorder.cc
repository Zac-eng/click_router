#include <click/config.h>
#include <click/args.hh>
#include <click/glue.hh>
#include <clicknet/ip.h>
#include <clicknet/udp.h>
#include <clicknet/icmp.h>
#include <click/ipaddress.hh>
#include <click/straccum.hh>
#include <stdio.h>

#include "counter_reorder.hh"
CLICK_DECLS

#define TABLE_CAP 20

CounterReorder::CounterReorder()
: _next_id(0)
{
  _map_packet = new HashTable<uint16_t, Packet *>;
}

CounterReorder::~CounterReorder() {}

int
CounterReorder::configure(Vector<String> & conf, ErrorHandler *errh)
{
  return 0;
}

void
CounterReorder::flush_packets()
{
  while (true) {
    Packet* next_packet = _map_packet->get(_next_id);
    if (!next_packet) {
      break;
    }
    output(0).push(next_packet);
    _map_packet->erase(_next_id);
    ++_next_id;
  }
}

void
CounterReorder::push(int port, Packet *p)
{
  uint32_t     counter = ntohl(*reinterpret_cast<const uint32_t *>(p->data()));

  if (counter == _next_id) {
    click_chatter("in sequence: %d\n", counter);
    output(0).push(p);
    ++_next_id;
    flush_packets();
  }
  else if (counter < _next_id) {
    click_chatter("out-of-order, killed: %d\n", counter);
    p->kill();
  }
  else {
    click_chatter("out-of-order: %d, size: %d\n", counter, _map_packet->size());
    (*_map_packet)[counter] = p->clone();
    p->kill();
    if (_map_packet->size() > TABLE_CAP) {
      while (!_map_packet->get(_next_id)) {
        ++_next_id;
      }
      flush_packets();
    }
  }
}

CLICK_ENDDECLS
EXPORT_ELEMENT(CounterReorder)
ELEMENT_MT_SAFE(CounterReorder)
