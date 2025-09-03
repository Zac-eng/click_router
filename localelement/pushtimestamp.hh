// -*- mode: c++; c-basic-offset: 4 -*-
#ifndef CLICK_PUSH_TIMESTAMP_HH
#define CLICK_PUSH_TIMESTAMP_HH
#include <click/element.hh>
CLICK_DECLS

class PushTimestamp : public Element { public:

    PushTimestamp() CLICK_COLD;
    ~PushTimestamp() CLICK_COLD;

    const char *class_name() const override	{ return "PushTimestamp"; }
    const char *port_count() const override	{ return PORTS_1_1; }
    int configure(Vector<String> &, ErrorHandler *) CLICK_COLD;

    Packet *simple_action(Packet *);

};

CLICK_ENDDECLS
#endif