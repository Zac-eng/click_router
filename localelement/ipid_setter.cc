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

void
IpIdSetter::push(int port, Packet *p)
{
  click_ip     *iph = (click_ip *) (p -> data());
  
  iph->ip_id = _next_id;
  ++_next_id;
  output(0).push(p);
}

CLICK_ENDDECLS
EXPORT_ELEMENT(IpIdSetter)
ELEMENT_MT_SAFE(IpIdSetter)
