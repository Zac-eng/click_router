#ifndef DATA_SEQ_SCHED_EPRINT_HH
#define DATA_SEQ_SCHED_EPRINT_HH
#include <click/batchelement.hh>
#include <click/notifier.hh>
#include <click/timer.hh>
// only for timestamp
#include <click/timestamp.hh>

CLICK_DECLS

class DSNEprint : public BatchElement { public:

    DSNEprint() CLICK_COLD;
    ~DSNEprint() CLICK_COLD;

    const char *class_name() const override	{ return "DSNEprint"; }
    const char *port_count() const override	{ return "-/1"; }
    const char *processing() const override	{ return PULL; }
    const char *flags() const		{ return "S0"; }
    void *cast(const char *);

    int configure(Vector<String> &conf, ErrorHandler *errh) CLICK_COLD;
    int initialize(ErrorHandler *errh) CLICK_COLD;
    void cleanup(CleanupStage stage) CLICK_COLD;
    void add_handlers() CLICK_COLD;
    void run_timer(Timer *t);

    Packet *pull(int);
  #if HAVE_BATCH
    PacketBatch *pull_batch(int port, unsigned max);
  #endif

  private:

    struct packet_s {
	    uint64_t dsn;
      int input;
	    Packet *p;
    };
    struct heap_less {
	    inline bool operator()(packet_s &a, packet_s &b) {
	      return a.dsn < b.dsn;
	    }
    };
    struct input_s {
	    NotifierSignal signal;
	    int space;
	    int ready;
    };

    packet_s *_pkt;
    int _npkt;

    input_s *_input;
    int _nready;

    Notifier _notifier;
    int _buffer;
    uint64_t _last_dsn;
    bool _stop;
    // bool _well_ordered;

    Timer _timer;
    bool _timeout;
    
    // this is required only when you want to print timestamp
    Timestamp _first_arrival;
};

CLICK_ENDDECLS
#endif