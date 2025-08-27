#ifndef WAITING_RRSCHED_HH
#define WAITING_RRSCHED_HH
#include <click/batchelement.hh>
#include <click/notifier.hh>
CLICK_DECLS

class WaitingRRSched : public BatchElement {
    public:
        WaitingRRSched() CLICK_COLD;

        const char *class_name() const override  { return "WaitingRRSched"; }
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
        int _max;

};

CLICK_ENDDECLS
#endif