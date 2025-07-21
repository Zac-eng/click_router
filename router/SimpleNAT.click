// Define internal and external interfaces
// Assume eth0 is internal (private), eth1 is external (public)
define($INT_IFACE eth0)
define($EXT_IFACE eth1)

// NAT configuration
define($PRIVATE_NET 192.168.0.0/24)
define($PUBLIC_IP 203.0.113.1)

// Incoming from internal network
FromDevice($INT_IFACE)
-> ipfilter :: IPFilter($PRIVATE_NET)
-> c :: Counter
-> t :: ToDevice($EXT_IFACE)

// Outgoing from internal network, perform NAT
ipfilter
-> Print("Internal -> External")
-> nat :: IPNat($PRIVATE_NET $PUBLIC_IP)
-> [0]t

// Packets from the external network
FromDevice($EXT_IFACE)
-> IPNat($PUBLIC_IP $PRIVATE_NET)
-> Print("External -> Internal")
-> ToDevice($INT_IFACE)
