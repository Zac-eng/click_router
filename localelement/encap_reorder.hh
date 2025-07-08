#ifndef ENCAP_REORDER_HH
#define ENCAP_REORDER_HH
#include <click/element.hh>
#include <click/hashtable.hh>
#include <click/ipaddress.hh>
CLICK_DECLS

#define TABLE_CAP 10

class EncapReorder : public Element {
public:
  EncapReorder() CLICK_COLD;
  ~EncapReorder() CLICK_COLD;

  const char *class_name() const override	{ return "EncapReorder"; }
  const char *port_count() const override	{ return "1-/1"; }
  const char *processing() const override	{ return PUSH; }

  int configure(Vector<String> &conf, ErrorHandler *errh) CLICK_COLD;
  void push(int, Packet *p);
  // void add_handlers() CLICK_COLD;

private:
  HashTable <uint16_t, Packet *> *_map_packet;
  uint16_t _next_id;
};

CLICK_ENDDECLS
#endif
