#ifndef CLICK_UDPIPENCAP_ANNO_HH
#define CLICK_UDPIPENCAP_ANNO_HH
#include <click/batchelement.hh>
#include <click/glue.hh>
#include <click/atomic.hh>
#include <clicknet/udp.h>
#include "ipport-annotator.hh"

CLICK_DECLS

class UDPIPEncapAnno : public BatchElement { public:

    UDPIPEncapAnno() CLICK_COLD;
    ~UDPIPEncapAnno() CLICK_COLD;

    const char *class_name() const override	{ return "UDPIPEncapAnno"; }
    const char *port_count() const override	{ return PORTS_1_1; }
    const char *flags() const		{ return "A"; }

    int configure(Vector<String> &, ErrorHandler *) CLICK_COLD;
    bool can_live_reconfigure() const	{ return true; }
    void add_handlers() CLICK_COLD;

    Packet *simple_action(Packet *);
#if HAVE_BATCH
	PacketBatch* simple_action_batch(PacketBatch *);
#endif

  protected:
    struct in_addr _saddr;
    struct in_addr _daddr;
    uint16_t _sport;
    uint16_t _dport;
    bool _cksum;

  private:

#if HAVE_FAST_CHECKSUM && FAST_CHECKSUM_ALIGNED
    bool _aligned;
    bool _checked_aligned;
#endif
    atomic_uint32_t _id;

    static String read_handler(Element *, void *) CLICK_COLD;

};

class RandomUDPIPEncapAnno : public UDPIPEncapAnno { public:


    const char *class_name() const  { return "RandomUDPIPEncapAnno"; }

    int configure(Vector<String> &, ErrorHandler *) override CLICK_COLD;
};


CLICK_ENDDECLS
#endif