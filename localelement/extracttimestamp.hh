// -*- mode: c++; c-basic-offset: 4 -*-
#ifndef CLICK_EXTRACT_TIMESTAMP_ANNO_HH
#define CLICK_EXTRACT_TIMESTAMP_ANNO_HH
#include <click/element.hh>
CLICK_DECLS

class ExtractTimestampAnno : public Element { public:

    ExtractTimestampAnno() CLICK_COLD;
    ~ExtractTimestampAnno() CLICK_COLD;

    const char *class_name() const override	{ return "ExtractTimestampAnno"; }
    const char *port_count() const override	{ return PORTS_1_1; }
    int configure(Vector<String> &, ErrorHandler *) CLICK_COLD;

    Packet *simple_action(Packet *);

};

CLICK_ENDDECLS
#endif