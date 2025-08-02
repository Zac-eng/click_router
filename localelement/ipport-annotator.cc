#include "ipport-annotator.hh"

CLICK_DECLS

int IPPortAnnotator::configure(Vector<String> &, ErrorHandler *) {
  _stored_info.ip = 0;
  _stored_info.port = 0;
  return 0;
}

void IPPortAnnotator::push_batch(int port, PacketBatch *batch) {
  if (port == 0) {
    if (_stored_info.ip == 0) {
      FOR_EACH_PACKET(batch, p) {
        const click_ip *iph = p->ip_header();
        if (!iph) continue;
        if (iph->ip_p != IP_PROTO_UDP) continue;
        const click_udp *udph = reinterpret_cast<const click_udp *>(p->transport_header());
        if (!udph) continue;
        _stored_info.ip = iph->ip_src.s_addr;
        _stored_info.port = ntohs(udph->uh_sport);
        click_chatter("Stored src IP: %x, port: %u", _stored_info.ip, _stored_info.port);
      }
    }
    checked_output_push_batch(0, batch);
  } else if (port == 1) {
    if (_stored_info.ip == 0) batch->kill();
    FOR_EACH_PACKET(batch, p) {
      WritablePacket *wp = p->uniqueify();
      if (!wp) continue;
      wp->set_dst_ip_anno(_stored_info.ip);
      wp->set_anno_u16(UDP_DPORT_ANNO, _stored_info.port);
      click_chatter("Annotated packet with IP: %x, port: %u", _stored_info.ip, _stored_info.port);
    }
    checked_output_push_batch(1, batch);
  }
}

CLICK_ENDDECLS
EXPORT_ELEMENT(IPPortAnnotator)
