#ifndef MyTCP_REORDER_HH
#define MyTCP_REORDER_HH
#include <click/element.hh>
#include <click/hashtable.hh>
#include <click/ipaddress.hh>
#include <click/config.h>
#include <click/args.hh>
#include <click/glue.hh>
#include <clicknet/ip.h>
#include <clicknet/udp.h>
#include <clicknet/tcp.h>
#include <clicknet/icmp.h>
#include <click/ipaddress.hh>
#include <click/straccum.hh>

CLICK_DECLS

class MyTCPReorder : public Element {
public:
  MyTCPReorder() CLICK_COLD;
  ~MyTCPReorder() CLICK_COLD;

  const char *class_name() const override	{ return "MyTCPReorder"; }
  const char *port_count() const override	{ return "1-/1"; }
  const char *processing() const override	{ return PUSH; }

  int configure(Vector<String> &conf, ErrorHandler *errh) CLICK_COLD;
  void push(int, Packet *p);
  // void add_handlers() CLICK_COLD;

private:
  HashTable <uint32_t, Packet *> *_packet_map;
  uint32_t _next_id;

  void flush_packets();
};

CLICK_ENDDECLS
#endif
