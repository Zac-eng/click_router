/*
 * EncapReorder.{cc,hh}
 * Kengo Sasaki
 *
 * Copyright (c) 1999-2000 Massachusetts Institute of Technology
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, subject to the conditions
 * listed in the Click LICENSE file. These conditions include: you must
 * preserve this copyright notice, and you cannot mention the copyright
 * holders in advertising related to the Software without their permission.
 * The Software is provided WITHOUT ANY WARRANTY, EXPRESS OR IMPLIED. This
 * notice is a summary of the Click LICENSE file; the license in that file is
 * legally binding.
 */

#include <click/config.h>
#include <click/args.hh>
#include <click/glue.hh>
#include <clicknet/ip.h>
#include <clicknet/udp.h>
#include <clicknet/icmp.h>
#include <click/ipaddress.hh>
#include <click/straccum.hh>
#include <stdio.h>

#include "encap_reorder.hh"
CLICK_DECLS

EncapReorder::EncapReorder()
: _next_id(0)
{
  _map_packet = new HashTable<uint16_t, Packet *>;
}

EncapReorder::~EncapReorder() {}

int
EncapReorder::configure(Vector<String> & conf, ErrorHandler *errh)
{
  return 0;
}

void
EncapReorder::push(int port, Packet *p)
{
  click_ip     *iph = (click_ip *) (p -> data());
  uint16_t     ip_id = iph->ip_id;

  if (ip_id == _next_id) {
    output(0).push(p);
    ++_next_id;
    while (true) {
      HashTable <uint16_t, Packet *>::iterator next_packet = _map_packet->find(_next_id);
      if (next_packet == _map_packet->end()) {
        break;
      }
      output(0).push(next_packet->second);
      ++_next_id;
    }
  }
  else {
    (*_map_packet)[ip_id] = p;
  }
}

CLICK_ENDDECLS
EXPORT_ELEMENT(EncapReorder)
ELEMENT_MT_SAFE(EncapReorder)
