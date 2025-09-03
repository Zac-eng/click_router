#include <click/config.h>
#include <click/error.hh>
#include "pushtimestamp.hh"
#include <click/args.hh>
#include <click/straccum.hh>
CLICK_DECLS

PushTimestamp::PushTimestamp()
{
}

PushTimestamp::~PushTimestamp()
{
}

int
PushTimestamp::configure(Vector<String> &conf, ErrorHandler *errh)
{
    return 0;
}

Packet *
PushTimestamp::simple_action(Packet *p)
{
    if (WritablePacket *q = p->push(8)) {
	memcpy(q->data(), &q->timestamp_anno(), 8);
	return q;
    } else
	return 0;
}

CLICK_ENDDECLS
EXPORT_ELEMENT(PushTimestamp)