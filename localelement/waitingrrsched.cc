#include <click/config.h>
#include <click/error.hh>
#include <click/args.hh>
#include "waitingrrsched.hh"
CLICK_DECLS

WaitingRRSched::WaitingRRSched()
    : _next(0), _signals(0), _max(0)
{
}

int WaitingRRSched::configure(Vector<String> &conf, ErrorHandler *errh)
{
    _max = ninputs();
    if (Args(conf, this, errh)
        .read_p("MAX", _max)
        .complete() < 0)
        return -1;

    return 0;
}

int
WaitingRRSched::initialize(ErrorHandler *errh)
{
    if (!(_signals = new NotifierSignal[ninputs()]))
        return errh->error("out of memory!");
    for (int i = 0; i < ninputs(); i++) {
        _signals[i] = Notifier::upstream_empty_signal(this, i);
    }
    return 0;
}

void
WaitingRRSched::cleanup(CleanupStage)
{
    delete[] _signals;
}

Packet *
WaitingRRSched::pull(int)
{
    int i = _next;
    for (int j = 0; j < _max; j++) {
      if (!_signals[i])
        usleep(500);
        Packet *p = (_signals[i] ? input(i).pull() : 0);

        i++;
        if (i >= _max) {
            i = 0;
        }
        if (p) {
            _next = i;
            return p;
        }
    }
    return 0;
}


#if HAVE_BATCH
PacketBatch *
WaitingRRSched::pull_batch(int port, unsigned max) {
    PacketBatch *batch;
    MAKE_BATCH(WaitingRRSched::pull(port), batch, max);
    return batch;
}
#endif

CLICK_ENDDECLS
EXPORT_ELEMENT(WaitingRRSched)