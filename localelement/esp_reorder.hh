#ifndef ESP_REORDER_HH
#define ESP_REORDER_HH
#include <click/element.hh>
#include <click/hashtable.hh>
#include <click/ipaddress.hh>
CLICK_DECLS

class EspReorder : public Element {
public:
  EspReorder() CLICK_COLD;
  ~EspReorder() CLICK_COLD;

  const char *class_name() const override	{ return "EspReorder"; }
  const char *port_count() const override	{ return "1-/1"; }
  const char *processing() const override	{ return PUSH; }

  int configure(Vector<String> &conf, ErrorHandler *errh) CLICK_COLD;
  void push(int, Packet *p);

private:
  HashTable <uint32_t, Packet *> *_map_packet;
  uint16_t _next_id;

  void flush_packets();
};

CLICK_ENDDECLS
#endif
