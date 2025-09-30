// -*- c-basic-offset: 4 -*-
#ifndef CLICK_DATA_SEQ_SCHED_HH
#define CLICK_DATA_SEQ_SCHED_HH
#include <click/batchelement.hh>
#include <click/notifier.hh>
#include <click/packet.hh>
#include <click/timer.hh>
#include <queue>
CLICK_DECLS

class DataSeqSched : public BatchElement {
  public:
      DataSeqSched() CLICK_COLD;

      const char *class_name() const override  { return "DataSeqSched"; }
      const char *port_count() const override  { return "-/1"; }
      const char *processing() const override  { return PULL; }
      const char *flags() const       { return "S0"; }

      int configure(Vector<String> &conf, ErrorHandler *) CLICK_COLD;
      int initialize(ErrorHandler *) CLICK_COLD;
      void run_timer(Timer *t) override;
      void cleanup(CleanupStage) CLICK_COLD;

      Packet *pull(int port);
  #if HAVE_BATCH
      PacketBatch *pull_batch(int port, unsigned max);
  #endif

  protected:
      uint64_t _next;
      NotifierSignal *_signals;
      Timer _timer;
      struct Compare {
        bool operator() (
          const std::pair<uint64_t, Packet*> &a,
          const std::pair<uint64_t, Packet*> &b) {
            return a.first > b.first;
          }
      };
      std::priority_queue<std::pair<uint64_t, Packet*>,
        std::vector<std::pair<uint64_t, Packet*>>,
        Compare> _queue;

};

CLICK_ENDDECLS
#endif
