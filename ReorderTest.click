FromDevice(wlp3s0)
-> Strip(14)
-> t::Tee(3);

t[2] -> Print(before) -> Discard;

reorder :: EncapReorder();

t[0] -> [0]idsetter :: IpIdSetter();
// -> RandomDelay(min_ms 5, max_ms 20)
idsetter[0]
-> Print("after: 0")
-> Queue(100)
-> DelayUnqueue(DELAY 10ms)
-> [0]reorder;

t[1] -> [1]idsetter;
// -> RandomDelay(min_ms 5, max_ms 20)
idsetter[1]
-> Print("after: 1")
-> Queue(100)
-> DelayUnqueue(DELAY 10ms)
-> [1]reorder;

reorder -> Print(reordered) -> Discard;
