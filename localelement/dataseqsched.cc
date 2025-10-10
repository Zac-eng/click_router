#include <click/config.h>
#include <click/error.hh>
#include "dataseqsched.hh"
#include <click/standard/scheduleinfo.hh>
#include <click/args.hh>
#include <click/router.hh>
#include <click/heap.hh>
CLICK_DECLS

#define TIMEOUT_MS 1

DataSeqSched::DataSeqSched()
    : _pkt(0), _npkt(0), _input(0), _nready(0),
      _notifier(Notifier::SEARCH_CONTINUE_WAKE),
      _buffer(10), _last_dsn(0), _timeout(false)
{
}

DataSeqSched::~DataSeqSched()
{
}

void *
DataSeqSched::cast(const char *n)
{
    if (strcmp(n, Notifier::EMPTY_NOTIFIER) == 0)
	    return &_notifier;
    else
    	return Element::cast(n);
}

int
DataSeqSched::configure(Vector<String> &conf, ErrorHandler *errh)
{
    _notifier.initialize(Notifier::EMPTY_NOTIFIER, router());
    _stop = false;
    if (Args(conf, this, errh)
	    .read("BUFFER", _buffer)
	    .complete() < 0)
	    return -1;
    if (_buffer <= 0)
	    return errh->error("BUFFER must be at least 1");
    return 0;
}

int
DataSeqSched::initialize(ErrorHandler *errh)
{
    _pkt = new packet_s[ninputs() * _buffer];
    _input = new input_s[ninputs()];
    if (!_pkt || !_input)
	    return errh->error("out of memory!");
    for (int i = 0; i < ninputs(); i++) {
	    _input[i].signal = Notifier::upstream_empty_signal(this, i, &_notifier);
	    _input[i].space = _buffer;
	    _input[i].ready = i;
    }
    _nready = ninputs();
    _timer.initialize(this);
    _timer.schedule_after_msec(10000);
    printf("npkt,dsn,last,timestamp");
    return 0;
}

void
DataSeqSched::cleanup(CleanupStage)
{
    for (int i = 0; i < _npkt; ++i)
	    _pkt[i].p->kill();
    delete[] _pkt;
    delete[] _input;
}

Packet*
DataSeqSched::pull(int)
{
    bool signals_on = false;
    // first maybe fill in buffer
    for (int rpos = _nready - 1; rpos >= 0; --rpos) {
        int i = _input[rpos].ready;
        input_s &is = _input[i];
        if (is.signal) {
            signals_on = true;
            while ((_pkt[_npkt].p = input(i).pull())) {
                memcpy(&_pkt[_npkt].dsn, _pkt[_npkt].p->data(), 8);
                _pkt[_npkt].input = i;
                ++_npkt;
                printf("%d,%ld,%ld,%s\n", _npkt, _pkt[_npkt-1].dsn, _last_dsn, (Timestamp::now() - _first_arrival).unparse().c_str());
                push_heap(_pkt, _pkt + _npkt, heap_less());
                --is.space;
                if (!is.space) {
                    _input[rpos].ready = _input[_nready - 1].ready;
                    --_nready;
                    break;
                }
            }
        }
    }

    // then maybe emit a packet
    _notifier.set_active(_npkt > 0 || signals_on);
    if (_npkt <= 0)
        return 0;
    if (!_timeout && _pkt[0].dsn != 0 && _pkt[0].dsn > _last_dsn + 1)
        return 0;
    if (_timeout || _pkt[0].dsn == 0 || _pkt[0].dsn == _last_dsn + 1) {
        // if (_timeout)
        //     printf("timeout\n");
        if (_pkt[0].dsn == 0)
            this->_first_arrival = Timestamp::now();
        _last_dsn = _pkt[0].dsn;
    }
    _timeout = false;
    _timer.reschedule_after_msec(TIMEOUT_MS);
    Packet *p = _pkt[0].p;
    input_s &is = _input[_pkt[0].input];
    ++is.space;
    if (is.space == 1) {
        _input[_nready].ready = _pkt[0].input;
        ++_nready;
    }
    pop_heap(_pkt, _pkt + _npkt, heap_less());
    --_npkt;
    return p;
}

#if HAVE_BATCH
PacketBatch *
DataSeqSched::pull_batch(int port, unsigned max) {
    PacketBatch *batch;
    MAKE_BATCH(DataSeqSched::pull(port), batch, max);
    return batch;
}
#endif

void
DataSeqSched::run_timer(Timer *t)
{
    _timeout = true;
    _notifier.set_active(true);
    t->reschedule_after_msec(TIMEOUT_MS);
}

void
DataSeqSched::add_handlers()
{
    // add_data_handlers("well_ordered", Handler::f_read | Handler::f_checkbox, &_well_ordered);
}

CLICK_ENDDECLS
EXPORT_ELEMENT(DataSeqSched)