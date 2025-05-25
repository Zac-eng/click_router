/* 
 * MyTCPReorder.{cc,hh} -- reorders TCP packets based on sequence numbers
 */

#include "mytcpreorder.hh"

MyTCPReorder::MyTCPReorder() 
    : _capacity(1000), _timeout_ms(1000), _next_seq(0),
      _timer(timer_hook, this), _buffer_count(0),
      _total_packets(0), _reordered_packets(0) {
}

MyTCPReorder::~MyTCPReorder() {
    // Clean up any packets still in buffer
    for (PacketMap::iterator it = _packet_map.begin(); 
         it != _packet_map.end(); ++it) {
        it->second->kill();
    }
}

int MyTCPReorder::configure(Vector<String> &conf, ErrorHandler *errh) {
    if (cp_va_kparse(conf, this, errh,
                    "CAPACITY", cpkP+cpkM, cpUnsigned, &_capacity,
                    "TIMEOUT", cpkP, cpUnsigned, &_timeout_ms,
                    cpEnd) < 0)
        return -1;
    
    _timer.initialize(this);
    if (_timeout_ms > 0)
        _timer.schedule_after_msec(_timeout_ms);
    
    return 0;
}

void MyTCPReorder::push(int, Packet *p) {
    // Extract TCP header and sequence number
    const click_ip *iph = p->ip_header();
    if (!iph || iph->ip_p != IP_PROTO_TCP) {
        // Not a TCP packet, pass it through
        printf("non tcp\n");
        output(1).push(p);
        return;
    }

    const click_tcp *tcph = p->tcp_header();
    if (!tcph) {
        output(1).push(p);
        return;
    }

    _total_packets++;
    uint32_t seq = ntohl(tcph->th_seq);
    printf("%d\n", seq);
    // Initialize next_seq if this is the first packet
    if (_packet_map.empty() && _next_seq == 0) {
        _next_seq = seq;
    }

    // If this is the next expected packet, send it immediately
    if (seq == _next_seq) {
        uint32_t len = p->length() - (p->transport_header_offset() + (tcph->th_off << 2));
        _next_seq += len > 0 ? len : 1;  // Move to next expected sequence
        output(0).push(p);
        
        // Check if we can release more packets
        check_release();
        return;
    }

    // Buffer is full, drop oldest packet
    if (_buffer_count >= _capacity) {
        Packet *old_p = _packet_map.begin()->second;
        _packet_map.erase(_packet_map.begin());
        _buffer_count--;
        old_p->kill();
    }

    // Store the packet for later
    _packet_map.insert(std::make_pair(seq, p));
    _buffer_count++;
    _reordered_packets++;

    // Reschedule timer if needed
    if (_timeout_ms > 0 && !_timer.scheduled())
        _timer.schedule_after_msec(_timeout_ms);
}

void MyTCPReorder::check_release() {
    release_packets();
}

void MyTCPReorder::release_packets() {
    // Release any packets that are now in order
    while (!_packet_map.empty()) {
        PacketMap::iterator it = _packet_map.begin();
        if (it->first != _next_seq)
            break;
        
        Packet *p = it->second;
        _packet_map.erase(it);
        _buffer_count--;

        const click_tcp *tcph = p->tcp_header();
        uint32_t len = p->length() - (p->transport_header_offset() + (tcph->th_off << 2));
        _next_seq += len > 0 ? len : 1;
        
        output(0).push(p);
    }
}

void MyTCPReorder::timer_hook(Timer *t, void *user_data) {
    MyTCPReorder *e = static_cast<MyTCPReorder*>(user_data);
    
    // If we've waited too long, flush everything
    if (!e->_packet_map.empty()) {
        // Update next_seq to the oldest packet's sequence
        e->_next_seq = e->_packet_map.begin()->first;
        e->release_packets();
    }
    
    // Reschedule if there are still packets
    if (!e->_packet_map.empty() && e->_timeout_ms > 0)
        t->schedule_after_msec(e->_timeout_ms);
}

String MyTCPReorder::read_handler(Element *e, void *thunk) {
    MyTCPReorder *r = static_cast<MyTCPReorder*>(e);
    switch (reinterpret_cast<intptr_t>(thunk)) {
    case 0:
        return String(r->_buffer_count);
    case 1:
        return String(r->_total_packets);
    case 2:
        return String(r->_reordered_packets);
    default:
        return String();
    }
}

void MyTCPReorder::add_handlers() {
    add_read_handler("buffersize", read_handler, (void*)0);
    add_read_handler("total", read_handler, (void*)1);
    add_read_handler("reordered", read_handler, (void*)2);
}

EXPORT_ELEMENT(MyTCPReorder)
ELEMENT_MT_SAFE(MyTCPReorder)
