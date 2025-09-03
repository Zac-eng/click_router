#include <click/config.h>
#include <click/error.hh>
#include "extracttimestamp.hh"
#include <click/args.hh>
#include <click/straccum.hh>
CLICK_DECLS

ExtractTimestampAnno::ExtractTimestampAnno()
{
}

ExtractTimestampAnno::~ExtractTimestampAnno()
{
}

int
ExtractTimestampAnno::configure(Vector<String> &conf, ErrorHandler *errh)
{
    return 0;
}

Packet *
ExtractTimestampAnno::simple_action(Packet *p)
{
    if (WritablePacket *q = p->uniqueify()) {
	memcpy(&q->timestamp_anno(), q->data(), 8);
	return q;
    } else
	return 0;
}

CLICK_ENDDECLS
EXPORT_ELEMENT(ExtractTimestampAnno)