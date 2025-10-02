// -*- mode: c++; c-basic-offset: 4 -*-
#ifndef CLICK_INSERT_DSN_HH
#define CLICK_INSERT_DSN_HH
#include <click/batchelement.hh>
CLICK_DECLS

class InsertDSN : public SimpleElement<InsertDSN> { public:

    InsertDSN() CLICK_COLD;
    ~InsertDSN() CLICK_COLD;

    const char *class_name() const override	{ return "InsertDSN"; }
    const char *port_count() const override	{ return PORTS_1_1; }
    int configure(Vector<String> &, ErrorHandler *) CLICK_COLD;

    Packet *simple_action(Packet *);

private:
    uint64_t _next;
};

CLICK_ENDDECLS
#endif
