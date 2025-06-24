#include <click/config.h>
#include <click/args.hh>
#include <click/glue.hh>
#include <clicknet/ip.h>
#include <clicknet/udp.h>
#include <clicknet/icmp.h>
#include <click/ipaddress.hh>
#include <click/straccum.hh>
#include <stdio.h>

#include "ipid_setter.hh"
CLICK_DECLS

IpIdSetter::~IpIdSetter() {}

int
IpIdSetter::configure_ports(bool is_input, int nports, ErrorHandler *errh) {
  return nports;
}

void
IpIdSetter::push(int port, Packet *p)
{
  WritablePacket  *writable_packet = p->uniqueify(); 
  click_ip        *iph = (click_ip *)(writable_packet->data());

  iph->ip_id = _next_id;
  ++_next_id;
  output(port).push(writable_packet);
}

CLICK_ENDDECLS
EXPORT_ELEMENT(IpIdSetter)
ELEMENT_MT_SAFE(IpIdSetter)
