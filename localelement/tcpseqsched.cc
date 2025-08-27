#include <click/config.h>
#include <click/error.hh>
#include <click/args.hh>
#include "tcpseqsched.hh"
CLICK_DECLS

TCPSeqSched::TCPSeqSched()
    : _next(0), _signals(0), _max(0)
{
}

int TCPSeqSched::configure(Vector<String> &conf, ErrorHandler *errh)
{
    _max = ninputs();
    _head_packets = new Packet*[_max];
    // if (Args(conf, this, errh)
    //     .read_p("MAX", _max)
    //     .complete() < 0)
    //     return -1;
    return 0;
}

int
TCPSeqSched::initialize(ErrorHandler *errh)
{
    if (!(_signals = new NotifierSignal[ninputs()]))
        return errh->error("out of memory!");
    for (int i = 0; i < ninputs(); i++) {
        _signals[i] = Notifier::upstream_empty_signal(this, i);
    }
    click_chatter("init complete");

    return 0;
}

void
TCPSeqSched::cleanup(CleanupStage)
{
    delete[] _signals;
}

Packet *
TCPSeqSched::pull(int)
{
    for (int j = 0; j < _max; j++) {
        if (!_head_packets[j] && _signals[j]) {
            Packet *p = input(j).pull();
            if (!p) {
                click_chatter("pulling failed, %d",j);
                continue;
            }
            click_chatter("pulled %d", j);
            const click_tcp* tcph = p->tcp_header();
            if (tcph == NULL) {
                click_chatter("non tcp packet, %x", (p = p->ip_header()?p:0));
                continue;
            }
            click_chatter("tcp header");
            tcp_seq_t seq = tcph->th_seq;
            _seq_port_map.insert(seq, j);
            _head_packets[j] = p->uniqueify();
            // p->kill();
        }
    }
    if (_seq_port_map.empty())
        return 0;
    HashMap<tcp_seq_t, int>::iterator smallest = _seq_port_map.begin();
    Packet *next_packet = _head_packets[smallest.value()];
    _head_packets[smallest.value()] = NULL;
    _seq_port_map.erase(smallest.key());
    return next_packet;
}


#if HAVE_BATCH
PacketBatch *
TCPSeqSched::pull_batch(int port, unsigned max) {
    PacketBatch *batch;
    MAKE_BATCH(TCPSeqSched::pull(port), batch, max);
    return batch;
}
#endif

CLICK_ENDDECLS
EXPORT_ELEMENT(TCPSeqSched)