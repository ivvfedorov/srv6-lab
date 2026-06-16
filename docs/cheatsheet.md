# Cheatsheet: Containerlab, FRR, SRv6, Linux

## Containerlab

```bash
containerlab deploy -t srv6.yml
containerlab destroy -t srv6.yml
containerlab inspect -t srv6.yml
containerlab inspect interfaces -t srv6.yml
containerlab exec -t srv6.yml --cmd "команда"
containerlab graph -t srv6.yml --srv 0.0.0.0:50080
containerlab tools gotty attach -t srv6.yml
```

## Linux networking

```bash
ip link show
ip -6 addr show
ip -6 route show
ip -6 neigh show
ip monitor route                    # netlink events
traceroute6 2001:db8:23::3
cat /proc/net/ipv6_route
ss -6 -tulpn
```

### SRv6 kernel (data plane)

```bash
sysctl net.ipv6.conf.all.seg6_enabled
sysctl net.ipv6.conf.all.seg6_require_hmac

# Пример static encap (lab troubleshooting)
ip -6 route add 2001:db8:99::/64 encap seg6 mode encap \
  segs 2001:db8:2::2,2001:db8:3::3 dev eth1
```

## tcpdump / Wireshark

```bash
tcpdump -ni eth1 ip6
tcpdump -ni eth1 'ip6[40:1] = 4'    # SRH (Routing Type 4)
tcpdump -ni eth1 -w capture.pcap
tcpdump -r capture.pcap -vv
```

Поля для SRv6 в Wireshark: IPv6 → Routing Header (Type 4) → Segment List.

## FRR — daemons

| Daemon | Назначение |
|--------|------------|
| zebra | RIB, netlink → kernel FIB |
| staticd | Статические маршруты |
| isisd | IS-IS (SRv6 locator advertisement) |
| bgpd | BGP (+ SRv6 VPN в новых версиях) |
| watchfrr | Мониторинг и перезапуск daemons |
| vtysh | Единый CLI |

```bash
vtysh                               # интерактивно
vtysh -c "show version"
vtysh -c "show ipv6 route"
vtysh -c "show zebra"
vtysh -c "show isis neighbor"
vtysh -c "show segment-routing srv6 locator"
vtysh -c "show segment-routing srv6 sid"
/usr/lib/frr/frrinit.sh restart
```

### Коды маршрутов (`show ipv6 route`)

| Код | Значение |
|-----|----------|
| K | kernel |
| C | connected |
| S | static |
| I | IS-IS |
| B | BGP |

## FRR — SRv6 (control plane)

```
configure terminal
 segment-routing
  srv6
   locators
    locator LOC1
     prefix 2001:db8:1::/64
    exit
   exit
  exit
 exit
!
router isis CORE
 segment-routing srv6
  locator LOC1
 exit
!
```

### IS-IS LSP и TLV для SRv6

```bash
vtysh -c "show isis database detail"                     # все LSP с SRv6 sub-TLV
vtysh -c "show isis database detail r1.00-00"            # LSP конкретного узла
vtysh -c "show isis database detail r1.00-00" | grep -A20 "SRv6"
```

## FRR — SRv6 Advanced (Policy, BGP VPN, Flex-Algo)

### SR Policy

```bash
vtysh -c "show segment-routing srv6 policy"
vtysh -c "show segment-routing srv6 policy detail"
vtysh -c "show segment-routing srv6 locator detail"
```

### BGP SRv6 L3VPN

```bash
vtysh -c "show bgp ipv6 vpn summary"
vtysh -c "show bgp ipv6 vpn"
vtysh -c "show bgp ipv6 vpn 2001:db8:dead::/64"
vtysh -c "show bgp vrf TENANT_A ipv6 unicast"
vtysh -c "show vrf TENANT_A"
vtysh -c "show ipv6 route vrf TENANT_A"
```

### Flex-Algo (BGP SRv6)

```bash
vtysh -c "show isis flex-algo"
vtysh -c "show segment-routing srv6 locator LOC_LOWLAT detail"
```

### Конфигурация VRF + BGP L3VPN (фрагмент)

```bash
vtysh -c "configure terminal"
vtysh -c " vrf TENANT_A"
vtysh -c "  vni 101"
vtysh -c " exit-vrf"
vtysh -c " router bgp 65001"
vtysh -c "  address-family ipv6 vpn"
vtysh -c "   neighbor 2001:db8:3::3 activate"
vtysh -c "   segment-routing srv6"
vtysh -c "    locator LOC1"
vtysh -c "   exit"
vtysh -c "  exit-address-family"
vtysh -c " exit"
```

## SRv6 OAM (ping / traceroute с SRH)

```bash
# Ручной SRv6 ping через SRH
ip -6 route add 2001:db8:3::/128 encap seg6 mode encap \
  segs 2001:db8:2::2,2001:db8:3::3 dev eth1
ping6 2001:db8:3::3

# Удалить маршрут
ip -6 route del 2001:db8:3::/128

# Тест End.DT6 SID напрямую
ip -6 route add 2001:db8:3:fe::/128 encap seg6 mode encap \
  segs 2001:db8:3:fe:: dev eth1
ping6 2001:db8:3:fe::
```

## Kernel seg6 — дамп SID-маршрутов и local-функций

```bash
# Все маршруты, включая seg6_local (локальные SID)
ip -6 route show table all | grep seg6

# Только seg6_local (End, End.X, End.DT6 — обработка на узле)
ip -6 route show table local | grep seg6local

# Только seg6 encap (SR Policy в FIB)
ip -6 route show | grep seg6
```

## Wireshark: фильтры для SRv6

```
ipv6.routing_hdr.type == 4                    # SRH
srv6.sid == 2001:db8:2:e001::                 # конкретный SID в segment list
isis.lsp                                      # IS-IS LSP
isis.srv6_locator                             # SRv6 Locator TLV
bgp.update.nlri_prefix.safi_vpn == 128        # BGP VPNv6 NLRI
```

## Netlink (Python pyroute2)

```python
from pyroute2 import IPRoute

ip = IPRoute()
ip.link("add", ifname="dummy0", kind="dummy")
idx = ip.link_lookup(ifname="dummy0")[0]
ip.addr("add", index=idx, address="2001:db8:99::1", prefixlen=64)
ip.route("add", dst="2001:db8:99::/64", oif=idx)
ip.close()
```

Наблюдение через strace:

```bash
strace -e socket,sendmsg ip -6 route add 2001:db8:99::/64 dev eth1 2>&1 | head -30
```

## VPP (lab08)

```bash
vppctl show version
vppctl show interface
vppctl show hardware
vppctl show ip6 fib
```

## eBPF (lab09, на хосте)

```bash
sudo bpftrace -e 'kprobe:netif_receive_skb { @[comm] = count(); }'
# Ctrl+C для вывода статистики
```

## Полезные ссылки

- [Containerlab docs](https://containerlab.dev)
- [FRR docs](https://docs.frrouting.org/en/latest/)
- [Linux SRv6 kernel](https://docs.kernel.org/networking/seg6.html)
- [RFC 8754 — SRv6 Network Programming](https://datatracker.ietf.org/doc/html/rfc8754)
- [RFC 8986 — SRv6 Network Programming (behaviours)](https://datatracker.ietf.org/doc/html/rfc8986)
- [RFC 9256 — SR Policy Architecture](https://datatracker.ietf.org/doc/html/rfc9256)
- [RFC 9350 — IGP Flexible Algorithm](https://datatracker.ietf.org/doc/html/rfc9350)
- [RFC 8402 — Segment Routing Architecture](https://datatracker.ietf.org/doc/html/rfc8402)
- [VPP docs](https://docs.fd.io/vpp/latest/)
- [Расширенная теория SRv6 (локально)](theory-srv6-advanced.md)
