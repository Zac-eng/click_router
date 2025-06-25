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
  WritablePacket  *w_packet = p->uniqueify(); 
  click_ip        *iph = (click_ip *)(w_packet->data());
  // click_udp       *udph = (click_udp *)(w_packet->transport_header());

  iph->ip_id = _next_id;
  ++_next_id;
  // iph->ip_sum = 0;
  // iph->ip_sum = click_in_cksum((unsigned char *)iph, sizeof(click_ip));
  // udph->uh_sum = 0;
  // int len = ntohs(udph->uh_ulen);
  // udph->uh_sum = click_in_cksum_pseudohdr(
  //   click_in_cksum((unsigned char *)udph, len),
  //   iph, len
  // );
  output(port).push(w_packet);
}

CLICK_ENDDECLS
EXPORT_ELEMENT(IpIdSetter)
ELEMENT_MT_SAFE(IpIdSetter)
