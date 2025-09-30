#include <click/config.h>
#include <click/error.hh>
#include "insertdsn.hh"
#include <click/args.hh>
#include <click/straccum.hh>
CLICK_DECLS

InsertDSN::InsertDSN()
  : _next(1)
{
}

InsertDSN::~InsertDSN()
{
}

int
InsertDSN::configure(Vector<String> &conf, ErrorHandler *errh)
{
    return 0;
}

Packet *
InsertDSN::simple_action(Packet *p)
{
  if (WritablePacket *q = p->push(8)) {
	  memcpy(q->data(), &this->_next, 8);
    ++this->_next;
	  return q;
  } else
	  return 0;
}

CLICK_ENDDECLS
EXPORT_ELEMENT(InsertDSN)