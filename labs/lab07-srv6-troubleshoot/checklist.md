# SRv6 Troubleshooting Checklist

## Control plane (FRR)

- [ ] `watchfrr`, `zebra`, `isisd` running: `ps aux | grep frr`
- [ ] IS-IS neighbors Up: `show isis neighbor`
- [ ] Locator Up: `show segment-routing srv6 locator`
- [ ] SIDs allocated: `show segment-routing srv6 sid`
- [ ] IPv6 routes to remote locators: `show ipv6 route`

## Data plane (kernel)

- [ ] `sysctl net.ipv6.conf.all.seg6_enabled` → 1
- [ ] `sysctl net.ipv6.conf.all.seg6_require_hmac` → 0 (lab default)
- [ ] SRv6 routes in kernel: `ip -6 route show table all`
- [ ] Interface up: `ip link show eth1`

## Encapsulation

- [ ] Policy route with seg6 encap exists (if testing manual encap)
- [ ] tcpdump shows Routing Header type 4
- [ ] MTU sufficient (SRH adds bytes) — lab links MTU 9500

## Common issues

| Symptom | Likely cause |
|---------|--------------|
| Locator Down | typo in prefix; zebra not running |
| No IS-IS adj | wrong NET; interface not in IS-IS |
| ping ok, no SRH | normal IPv6 forwarding (no encap policy) |
| ping fail after SRv6 | missing kernel SID; seg6 disabled |
