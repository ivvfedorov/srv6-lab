# SRv6 Reference Configuration

Эталонные конфиги для ЛР5–ЛР11. Базовые конфиги без SRv6 находятся в `configs/r*/frr.conf`.
SRv6-режим разворачивается через `srv6-reference.yml`, VPN-режим — через `srv6-vpn.yml`.

## Locator plan

| Node | Locator name | Prefix | Loopback |
|------|--------------|--------|----------|
| r1 | LOC1 | `2001:db8:1::/64` | `2001:db8:1::1/128` |
| r2 | LOC2 | `2001:db8:2::/64` | `2001:db8:2::2/128` |
| r3 | LOC3 | `2001:db8:3::/64` | `2001:db8:3::3/128` |

## IS-IS NET

| Node | NET |
|------|-----|
| r1 | `49.0001.0000.0000.0001.00` |
| r2 | `49.0001.0000.0000.0002.00` |
| r3 | `49.0001.0000.0000.0003.00` |

## Автовыделенные SID (после `make srv6`)

IS-IS SRv6 автоматически создаёт:

| Behavior | RFC name | Назначение |
|----------|----------|------------|
| uN | End (uSID) | Prefix-SID узла |
| uA | End.X (uSID) | Adjacency SID на интерфейсе |

Проверка: `vtysh -c "show segment-routing srv6 sid"`

## Применение

```bash
make srv6
```

Команда пересоздаёт lab `srv6` с bind-mount на `configs/srv6/r*/frr.conf`. Она не копирует
конфиги поверх `configs/r*/frr.conf` и не должна менять рабочее дерево git.

## Откат к базовому IS-IS (без SRv6)

```bash
make redeploy
```

## Kernel encap (ручной тест, lab07)

```bash
# На r1 — отправка через segment list [r2, r3]
ip -6 route add 2001:db8:3::3/128 encap seg6 mode encap \
  segs 2001:db8:2::2,2001:db8:3::3 dev eth1
```

Требует, что SID'ы установлены в kernel (через zebra/FRR).

---

# Advanced Configuration Reference (ЛР10–ЛР11)

## Advanced Locator Plan

| Node | Locator | Prefix | Algo | Назначение |
|------|---------|--------|------|-----------|
| r1 | LOC1 | `2001:db8:1::/64` | 0 | IGP Shortest Path |
| r2 | LOC2 | `2001:db8:2::/64` | 0 | IGP Shortest Path |
| r3 | LOC3 | `2001:db8:3::/64` | 0 | IGP Shortest Path |
| r1 | LOC1_LOWLAT | `2001:db8:1001::/64` | 128 | Low-Latency (Flex-Algo, опционально) |
| r3 | LOC3_LOWLAT | `2001:db8:1003::/64` | 128 | Low-Latency (Flex-Algo, опционально) |

## BGP AS и Router-ID

| Node | AS | Router-ID |
|------|-----|----------|
| r1 | 65000 | 1.1.1.1 |
| r2 | 65000 (route-reflector) | 2.2.2.2 |
| r3 | 65000 | 3.3.3.3 |

## VRF для L3VPN

| Node | VRF | VNI | IPv4 Loopback | IPv6 Loopback | End.DT4 SID | End.DT6 SID |
|------|-----|-----|---------------|---------------|-------------|-------------|
| r1 | TENANT_A | 101 | `192.168.1.1/32` | `2001:db8:dead::1/128` | auto-assigned (`auto-sid`) | auto-assigned (`auto-sid`) |
| r3 | TENANT_A | 101 | `192.168.3.1/32` | `2001:db8:beef::1/128` | auto-assigned (`auto-sid`) | auto-assigned (`auto-sid`) |

Узнать реальные SID после развёртывания: `vtysh -c "show segment-routing srv6 sid" | grep uDT`.

## SR Policy SID Allocation (ЛР10)

| Policy | Headend | Color | Endpoint | BSID | Segment List |
|--------|---------|-------|----------|------|-------------|
| POL-R1-R3-PRIMARY | r1 | 10 | `2001:db8:3::3` | `2001:db8:1:b001::` | `[2001:db8:2:e001::, 2001:db8:3::]` |
| POL-R1-R3-BACKUP | r1 | 20 | `2001:db8:3::3` | `2001:db8:1:b002::` | `[2001:db8:2::2]` (shortest path) |

## Структура SID (для справки)

```
Locator (B=64 бит)    | Function (N бит)         | Argument (опц.)
2001:db8:1::          | :0e001: (End.X, uA)      | ::
2001:db8:1::          | :00001: (End.DT6, uDT6)  | :0101: (VRF ID)
|<--- /64 locator -->| |<-- до /128 -->|
```

## План VRF-интерфейсов (ЛР11)

| Узел | VRF | Интерфейс | IPv4 | IPv6 |
|------|-----|-----------|------|------|
| r1 | TENANT_A | tenant-a (dummy) | `192.168.1.1/32` | `2001:db8:dead::1/128` |
| r3 | TENANT_A | tenant-a (dummy) | `192.168.3.1/32` | `2001:db8:beef::1/128` |

В текущем стенде CE эмулируется dummy-интерфейсом `tenant-a` внутри Linux VRF `TENANT_A`.
Отдельные CE-контейнеры и линки `eth3` намеренно не используются, чтобы ЛР11 фокусировалась на
BGP VPNv6 и End.DT SID.

## BGP Peering для L3VPN

```
r1 (PE, AS 65000) ←→ r2 (RR, AS 65000)
r3 (PE, AS 65000) ←→ r2 (RR, AS 65000)

Address-family: IPv6 VPN (AFI=2, SAFI=128)
Next-hop: loopback (2001:db8:1::1 для r1, 2001:db8:3::3 для r3)
```

## Эталонный BGP + VRF конфиг (r1, фрагмент)

См. `configs/srv6/r1/frr-vpn.conf` — полный конфиг с VRF и BGP L3VPN.

## Полезные команды (advanced)

```bash
# SR Policy
vtysh -c "show segment-routing srv6 policy"
vtysh -c "show segment-routing srv6 locator detail"

# BGP VPN
vtysh -c "show bgp ipv6 vpn summary"
vtysh -c "show bgp ipv6 vpn"
vtysh -c "show bgp vrf TENANT_A ipv6 unicast"

# VRF
vtysh -c "show vrf TENANT_A"
vtysh -c "show ipv6 route vrf TENANT_A"

# IS-IS TLV
vtysh -c "show isis database detail" | grep -A10 "SRv6"

# Kernel SID local
ip -6 route show table local | grep seg6local
```

## Ссылки

- Расширенная теория: [docs/theory-srv6-advanced.md](../../docs/theory-srv6-advanced.md)
- Cheatsheet (advanced): [docs/cheatsheet.md](../../docs/cheatsheet.md)
- ЛР10 (SR Policy): [labs/lab10-srv6-policy/README.md](../../labs/lab10-srv6-policy/README.md)
- ЛР11 (BGP L3VPN): [labs/lab11-srv6-vpn/README.md](../../labs/lab11-srv6-vpn/README.md)
