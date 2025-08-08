/*
 * TCPRetransmitter.{cc,hh}
 *
 * Tom Barbette
 *
 */

#include <click/config.h>
#include <click/glue.hh>
#include <click/args.hh>
#include <click/error.hh>
#include <click/timer.hh>
#include <clicknet/tcp.h>
#include "tcpretransmitter.hh"


TCPRetransmitter::TCPRetransmitter() : _verbose(false), _proack(false), _resize(false), _readonly(false)
{

}

TCPRetransmitter::~TCPRetransmitter()
{

}
// void*
// TCPRetransmitter::cast(const char * name) {
//     if (strcmp("TCPRetransmitter", name)) {
//         return this;
//     }
//     return CTXSpaceElement<fcb_transmit_buffer>::cast(name);
// }

int TCPRetransmitter::configure(Vector<String> &conf, ErrorHandler *errh)
{
    if(Args(conf, this, errh)
            .read("PROACK", _proack)
            .read("VERBOSE", _verbose)
            .read("READONLY", _readonly)
            .complete() < 0)
        return -1;

    ElementCastTracker visitor(router(), "TCPIn");
    router()->visit_upstream(this,0,&visitor);
    if (visitor.size() != 1) {
        return errh->error("Could not find TCPIn element !");
    } else {
        _in = static_cast<TCPIn*>(visitor[0]);
    }
    //Set the initialization to run after all stack objects passed
    allStackInitialized.post(new Router::FctFuture([this](ErrorHandler* errh) {
        return retransmitter_initialize(errh);
    }, this));
    return 0;;
}


int TCPRetransmitter::retransmitter_initialize(ErrorHandler *errh) {
    if (_in->getOutElement()->maxModificationLevel(0) & MODIFICATION_RESIZE) {
        if (_readonly) {
            return errh->error("READONLY is set but some elements want to modify packets !");
        }
        _resize = true;

    }
    return 0;
}

void
TCPRetransmitter::release_flow(fcb_transmit_buffer* fcb) {
    if (fcb->first_unacked) {
        //click_chatter("TCPRetransmitter :: Releasing %d transmit buffers", fcb->first_unacked->count());
        fcb->first_unacked->fast_kill();
        fcb->first_unacked = 0;
    }
    return;
}

void
TCPRetransmitter::forward_packets(fcb_transmit_buffer* fcb, PacketBatch* batch) {
    /**
     * Just prune the buffer and put the packet with payload in the list (don't buffer ACKs)
     */

    prune(fcb);
    FOR_EACH_PACKET_SAFE(batch,packet) {
        if (getPayloadLength(packet) == 0)
            continue;

        Packet* clone = packet->clone(true); //Fast clone. If using DPDK, we only hold a buffer reference
        flow_assert(clone->buffer() == packet->buffer());
        /*click_chatter("%p %p %p",clone->mac_header(),packet->mac_header());
        clone->set_mac_header(packet->mac_header());
        clone->set_network_header(packet->network_header());
        clone->set_transport_header(packet->transport_header());*/

        //Actually add the packet in the FCB
        if (fcb->first_unacked) {
            fcb->first_unacked->append_packet(clone);
            clone->set_next(0);
        } else {
            fcb->first_unacked = PacketBatch::make_from_packet(clone);
            fcb->first_unacked_seq = getSequenceNumber(packet);
        }
    }

    //Send the original batch
    if(batch != NULL)
        output_push_batch(0, batch);

    return;
}

void
TCPRetransmitter::push_flow(int port, fcb_transmit_buffer* fcb, PacketBatch *batch)
{
    //If the flow is killed, just push the batch to port 0 (let RST go through)
    if (unlikely(!_in->fcb_data()->common || _in->fcb_data()->common->state == TCPState::CLOSED)) {
        output_push_batch(0, batch);
        return;
    }
    if(port == 0) { //Normal packet to buffer
        forward_packets(fcb, batch);
    } else { /* port == 1 */ //Retransmission
        auto fcb_in = _in->fcb_data(); //Scratchpad for TCPIn

        //Retransmission of a SYN -> Let it go through
        if ((fcb_in->common->state < TCPState::OPEN) && isSyn(batch->first()) || isRst(batch->first())) {
            if (_verbose)
                click_chatter("Unestablished connection, letting the rt packet go through");

            //TODO : it should go through the options removal again !
            if (batch->count() > 1) {
                Packet* packet = batch->first();
                batch = batch->pop_front();
                output_push_batch(0, PacketBatch::make_from_packet(packet));
                batch->fast_kill();
            } else {
                output_push_batch(0, batch);
            }
            return;
        }
        /**
         * The retransmission happens because the ack was never received.
         * There are two cases :
         * - The ack was sent by the dest but did not reach the source. If this
         *   is the case we know the other's side last ACK.
         *   In which case we drop the packet and re-ack ourselves.
         * - This packet never reached the end host. We retransmit the
         * equivalent packet in the buffer. We cannot retransmit the same packet
         * because it could be a retransmit attack.
         */

        Packet* lastretransmit = 0;

        unsigned int flowDirection = determineFlowDirection();
        ByteStreamMaintainer &maintainer = fcb_in->common->maintainers[flowDirection];

        FOR_EACH_PACKET_SAFE(batch, packet) {
            uint32_t seq = getSequenceNumber(packet);
            uint32_t mappedSeq;
            if (_resize) {
                mappedSeq = maintainer.mapSeq(seq);
            } else {
                mappedSeq = seq;
            }

            if (_proack && fcb_in->common->lastAckReceivedSet() && SEQ_LT(mappedSeq, fcb_in->common->getLastAckReceived(_in->getOppositeFlowDirection()))) {
                if (_verbose)
                    click_chatter("Client just did not receive the ack, let's ACK him (seq %lu, last ack %lu, state %d)",seq,fcb_in->common->getLastAckReceived(_in->getOppositeFlowDirection()),fcb_in->common->state);
                _in->ackPacket(packet,true);

                continue;
            }
            if (getPayloadLength(packet) == 0) {
                if (unlikely(_verbose)) {
                    click_chatter("Retransmitted packet is an ACK");
                }
                if (batch->count() == 1) {
                    output_push_batch(0,batch);
                    return;
                } else
                    output_push_batch(0,PacketBatch::make_from_packet(packet->clone()));
            } else {
                //Seq is bigger than last ack, (the original of) this packet was lost before the dest reached it (or we never received the ack)
                FOR_EACH_PACKET_SAFE(fcb->first_unacked, pr) {
                    if (getSequenceNumber(pr) == mappedSeq) {
                        if (lastretransmit == pr) { //Avoid double retransmission
                            //TODO : do we always want to do that?
                            if (_verbose)
                                click_chatter("Avoid double retransmit");
                        } else {
                            lastretransmit = pr;
                            if (unlikely(_verbose))
                                click_chatter("Retransmitting one packet from the buffer (seq %lu)",getSequenceNumber(pr));
                            fcb_acquire(1);
                            output_push_batch(0,PacketBatch::make_from_packet(pr->clone(true)));
                        }
                        goto found;
                    }
                }

                if (unlikely(_verbose))
                    click_chatter("ERROR : Received a retransmit for a packet not in the buffer (%lu, last ack %lu, is_syn %d, is_ack %d, pay_len %d)", seq, fcb_in->common->getLastAckReceived(_in->getOppositeFlowDirection()),isSyn(packet),isAck(packet), getPayloadLength(packet));
                //This may be a retransmit for a packet we have seen acked (so we pruned), but the acked was lost
                _in->ackPacket(packet, true);
                goto found;
            }


            found:
            continue;
        }
        batch->fast_kill();
        return;
    }
}

inline void TCPRetransmitter::prune(fcb_transmit_buffer* fcb)
{
    if (!_in->fcb_data()->common->lastAckReceivedSet())
        return;

    tcp_seq_t seq = _in->fcb_data()->common->getLastAckReceived(_in->getOppositeFlowDirection());
    tcp_seq_t next_seq = fcb->first_unacked_seq;
    Packet* next = fcb->first_unacked->first();
    if (!next || SEQ_GEQ(next_seq,seq))
        return;
    Packet* last = 0;
    int count = 0;
//    tcp_seq_t lastSeq = 0;
    // click_chatter("before get seq, %p", next->data());
    // if (next != nullptr) {
    //     // click_chatter("tcp header: %p",next->tcp_header());
    //     if (next->tcp_header() != nullptr)
    //         // click_chatter("last ack: %u, seq: %u",ntohl(seq), next->tcp_header()->th_seq);
    // }

    while (next != nullptr && next->tcp_header() != nullptr && (SEQ_LT(getSequenceNumber(next),seq))) {
/*        if (lastSeq) {
        if (!SEQ_GT(getSequenceNumber(next), lastSeq)) {
            click_chatter("new %lu <= %lu",getSequenceNumber(next), lastSeq);
            assert(false);
        }
        }
        lastSeq=getSequenceNumber(next);*/
        last = next;
        count++;
        next = next->next();
    }
// click_chatter("next: %d", count);
    if (count) {
        PacketBatch* second = 0;
        //click_chatter("Pruning %d (last received %lu, last was %lu)",count,_in->fcb_data()->common->getLastAckReceived(_in->getOppositeFlowDirection()),getSequenceNumber(last));
        if (next)
            fcb->first_unacked->cut(last, count, second);
        SFCB_STACK(
            fcb->first_unacked->fast_kill();
        );
    // click_chatter("killed");

        fcb->first_unacked = second;
        if (second)
            fcb->first_unacked_seq = getSequenceNumber(second->first());
    // click_chatter("first unacked");

    }
}


EXPORT_ELEMENT(TCPRetransmitter)
ELEMENT_MT_SAFE(TCPRetransmitter)
