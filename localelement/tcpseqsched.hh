// -*- c-basic-offset: 4 -*-
#ifndef CLICK_TCP_SEQ_SCHED_HH
#define CLICK_TCP_SEQ_SCHED_HH
#include <click/batchelement.hh>
#include <click/notifier.hh>
#include <click/hashmap.hh>
#include <click/packet.hh>
CLICK_DECLS

struct HeadPacket {
  int     port;
  Packet* p;
};

class TCPSeqSched : public BatchElement {
  public:
      TCPSeqSched() CLICK_COLD;

      const char *class_name() const override  { return "TCPSeqSched"; }
      const char *port_count() const override  { return "-/1"; }
      const char *processing() const override  { return PULL; }
      const char *flags() const       { return "S0"; }

      int configure(Vector<String> &conf, ErrorHandler *) CLICK_COLD;
      int initialize(ErrorHandler *) CLICK_COLD;
      void cleanup(CleanupStage) CLICK_COLD;

      Packet *pull(int port);
  #if HAVE_BATCH
      PacketBatch *pull_batch(int port, unsigned max);
  #endif

  protected:
      int _next;
      NotifierSignal *_signals;
      HashMap<tcp_seq_t, int> _seq_port_map;
      Packet** _head_packets;
      int _max;

};

CLICK_ENDDECLS
#endif
