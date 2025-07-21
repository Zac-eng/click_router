#ifndef MyTCP_REORDER_HH
#define MyTCP_REORDER_HH

#include <click/config.h>
#include <click/element.hh>
#include <click/confparse.hh>
#include <click/error.hh>
#include <click/packet.hh>
#include <clicknet/tcp.h>
#include <clicknet/ip.h>
#include <click/timer.hh>
#include <click/hashtable.hh>
#include <click/ipaddress.hh>

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
  uint32_t _next_seq;

  void flush_packets();
};

CLICK_ENDDECLS
#endif


// #include <map>

// class MyTCPReorder : public Element {
// public:
//     MyTCPReorder();
//     ~MyTCPReorder();

//     const char *class_name() const { return "MyTCPReorder"; }
//     const char *port_count() const { return "1-/2"; }
//     const char *processing() const { return PUSH; }

//     int configure(Vector<String> &, ErrorHandler *);
//     void push(int port, Packet *p);

//     static String read_handler(Element *e, void *thunk);
//     void add_handlers();

// private:
//     // Parameters
//     uint32_t _capacity;
//     uint32_t _timeout_ms;

//     // Data structures for packet reordering
//     typedef std::multimap<uint32_t, Packet*> PacketMap;
//     PacketMap _packet_map;
//     uint32_t _next_seq;
//     Timer _timer;

//     // State tracking
//     uint32_t _buffer_count;
//     uint32_t _total_packets;
//     uint32_t _reordered_packets;

//     void check_release();
//     void release_packets();
//     static void timer_hook(Timer*, void*);
// };