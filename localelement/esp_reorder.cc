#include <click/config.h>
#include <click/args.hh>
#include <click/glue.hh>
#include <clicknet/ip.h>
#include <clicknet/udp.h>
#include <clicknet/icmp.h>
#include <click/ipaddress.hh>
#include <click/straccum.hh>
#include <stdio.h>

#include "esp_reorder.hh"
CLICK_DECLS

#define TABLE_CAP 20

EspReorder::EspReorder()
: _next_id(0)
{
  _map_packet = new HashTable<uint32_t, Packet *>;
}

EspReorder::~EspReorder() {
  delete _map_packet;
}

int
EspReorder::configure(Vector<String> & conf, ErrorHandler *errh)
{
  return 0;
}

void
EspReorder::flush_packets()
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
EspReorder::push(int port, Packet *p)
{
  const unsigned char     *esp_packet = p->data();
  uint32_t                esp_seqnum = ntohl(*reinterpret_cast<const uint32_t *>(&(esp_packet[4])));

  if (esp_seqnum == _next_id) {
    click_chatter("in sequence: %d\n", esp_seqnum);
    output(0).push(p);
    ++_next_id;
    flush_packets();
  }
  else if (esp_seqnum < _next_id) {
    click_chatter("out-of-order, killed: %d\n", esp_seqnum);
    p->kill();
  }
  else {
    click_chatter("out-of-order: %d, size: %d\n", esp_seqnum, _map_packet->size());
    (*_map_packet)[esp_seqnum] = p->clone();
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
EXPORT_ELEMENT(EspReorder)
ELEMENT_MT_SAFE(EspReorder)
