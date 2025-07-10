/*
 * MultiPathGatewayServerSide.{cc,hh}
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

#include "MultiPathGatewayServerSide.hh"
CLICK_DECLS


MultiPathGatewayServerSide::MultiPathGatewayServerSide()
//  : _offset(0)
: _at(MOB_0)
{
  _map_ip = new HashTable<comType, IPStatus>;
}

MultiPathGatewayServerSide::~MultiPathGatewayServerSide()
//  : _offset(0)
{
  
}

int
MultiPathGatewayServerSide::configure(Vector<String> & conf, ErrorHandler *errh)
{
  String _ct = "MOB";
  if ( Args(conf, this, errh)
      .read_mp("GLOBAL_IP", _global_ip)
      .read_mp("GLOBAL_PORT", IPPortArg(IP_PROTO_UDP), _global_port)
      .read("COM_TYPE", _ct)
       //.read("OFFSET", _offset)
       .complete() < 0)
    return -1;
  if (_ct == "MOB"){
    _at=MOB_0;
  }else if(_ct == "SAT"){
    _at=SAT_0;
  }else {
    click_chatter("Unknown Communication Type\n");
    return -1;
  }
  StringAccum sa;
  sa << "Global IP is " << _global_ip.unparse() << ". Global Port is " << _global_port << ".\n";
  //click_chatter("Global IP is %s. Global Port is %u", _global_ip.unparse(), );
  click_chatter("%s", sa.c_str());
  return 0;
}

void
MultiPathGatewayServerSide::_printIPTable(){
  StringAccum sa;
  for (auto it = _map_ip->begin(); it != _map_ip->end(); it ++){    
    if (it -> first == MOB_0) {
      sa << "MOB";
    } else if (it -> first == SAT_0){
      sa << "SAT";
    } else {
      ;
    }
    sa << " -> " << it -> second.ip << ":" << it -> second.port << "\n";
  }
  click_chatter("%s", sa.c_str());
}

void
MultiPathGatewayServerSide::push(int port, Packet *p)
{
  // p is assumed ip packet. 
  if(port == 0){
    // port == 0 bridge-side
      
    // IP Header
    click_ip     *iph = (click_ip *) (p -> data());
    IPAddress dst_ipa = IPAddress(iph -> ip_src);
    
    // UDP Header
    click_udp   *udph = (click_udp *) (p -> data() + 20);
    uint16_t dst_port = ntohs(udph -> uh_sport);

    // Payload Header
    uint8_t     *payh = (uint8_t *)(p-> data() + 20 + 8); // IP (20) + UDP(8)

    IPStatus _map_val = {
      dst_ipa,
      dst_port
    };

    (*_map_ip)[(comType)*payh] = _map_val;
    // _printIPTable();
    p->kill();
  }else if(port==1){
    // port == 1 server-side        
    IPAddress dst_ipa = (*_map_ip)[_at].ip;
    uint16_t dst_port = (*_map_ip)[_at].port;

    WritablePacket *wp  = p->push(sizeof(click_udp) + sizeof(click_ip));
    click_ip      *iph  = reinterpret_cast<click_ip *> (wp -> data());
    click_udp     *udph = reinterpret_cast<click_udp *> (wp -> data() + 20);

    // click_chatter("Port 1 rcv\n");
    // set up IP header
    iph->ip_v = 4;
    iph->ip_hl = sizeof(click_ip) >> 2;
    iph->ip_len = htons(p->length());
    iph->ip_id = htons(0); // htons(_id.fetch_and_add(1));
    iph->ip_p = IP_PROTO_UDP;
    iph->ip_src = _global_ip.in_addr();
    iph->ip_dst = dst_ipa.in_addr();
    iph->ip_tos = 0;
    iph->ip_off = 0;
    iph->ip_ttl = 250;

    iph->ip_sum = 0;
    iph->ip_sum = click_in_cksum((unsigned char *)iph, sizeof(click_ip));

    wp -> set_ip_header(iph, sizeof(click_ip));

    // set up UDP header
    udph->uh_sport = htons(_global_port);
    udph->uh_dport = htons(dst_port);
    uint16_t len = p->length() - sizeof(click_ip);
    udph->uh_ulen = htons(len);
    udph->uh_sum = 0;
    unsigned csum = click_in_cksum((unsigned char *)udph, len);
    udph->uh_sum = click_in_cksum_pseudohdr(csum, iph, len);    
    output(0).push(wp);
  }  
}

void 
MultiPathGatewayServerSide::add_handlers()
{  
  add_data_handlers("com", Handler::OP_READ | Handler::OP_WRITE, &_at);
}

CLICK_ENDDECLS
EXPORT_ELEMENT(MultiPathGatewayServerSide)
ELEMENT_MT_SAFE(MultiPathGatewayServerSide)
