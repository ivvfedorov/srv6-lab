# SRv6 Troubleshooting Checklist

Используйте чеклист сверху вниз. Не переходите к SRv6 policy или BGP, пока не доказаны
контейнеры, интерфейсы, IGP и kernel dataplane.

## 1. Стенд и интерфейсы

| Проверка | Команда | Что доказывает | Если не работает |
|----------|---------|----------------|------------------|
| Контейнеры созданы | `containerlab inspect -t srv6-reference.yml` | Lab запущена | `make srv6` |
| Интерфейсы подняты | `ip -6 -br addr` | У узла есть data-адреса | Проверить topology/bind config |
| Link state | `ip link show eth1` | Интерфейс не down | Проверить endpoints в topology |
| IPv6 forwarding | `sysctl net.ipv6.conf.all.forwarding` | Узел маршрутизирует IPv6 | Проверить `ipv6 forwarding` в FRR config |

## 2. Control plane (FRR)

| Проверка | Команда | Что доказывает | Если не работает |
|----------|---------|----------------|------------------|
| FRR daemons | `ps aux \| grep -E 'watchfrr|zebra|isisd'` | FRR запущен | Перезапустить FRR/container |
| IS-IS neighbors | `vtysh -c "show isis neighbor"` | IGP соседство установлено | Проверить `ipv6 router isis CORE` на интерфейсе |
| IS-IS database | `vtysh -c "show isis database"` | Узел получил LSP | Проверить NET/level/линки |
| IPv6 routes | `vtysh -c "show ipv6 route"` | FRR RIB содержит маршруты | Проверить IS-IS и connected routes |
| Locator | `vtysh -c "show segment-routing srv6 locator"` | SRv6 locator принят FRR | Проверить `segment-routing srv6` |
| SID table | `vtysh -c "show segment-routing srv6 sid"` | FRR создал SID behavior | Проверить locator и zebra |

## Data plane (kernel)

| Проверка | Команда | Что доказывает | Если не работает |
|----------|---------|----------------|------------------|
| SRv6 enabled | `sysctl net.ipv6.conf.all.seg6_enabled` | Kernel принимает SRv6 | `sysctl -w ...=1` |
| HMAC не требуется | `sysctl net.ipv6.conf.all.seg6_require_hmac` | Lab не требует HMAC | `sysctl -w ...=0` |
| Kernel routes | `ip -6 route show` | FIB получил маршруты | Сравнить с FRR RIB |
| Local SID | `ip -6 route show table local \| grep seg6local` | Kernel знает local behavior | Проверить zebra/SID |
| Encap route | `ip -6 route show \| grep seg6` | Headend encap установлен | Проверить ЛР10 route add |

## Encapsulation

| Проверка | Команда | Что доказывает | Если не работает |
|----------|---------|----------------|------------------|
| SRH в пакете | `tcpdump -ni eth1 'ip6[40:1]=4'` | Реальная инкапсуляция есть | Проверить route encap |
| Segment List | Wireshark Routing Header Type 4 | SID list соответствует заданию | Проверить порядок SID |
| Hop-by-hop path | `traceroute6 -n ...` | Видимый L3 path | Сравнить с policy/IGP |
| MTU | `ip link show eth1` | SRH не ломает packet size | Уменьшить payload или поднять MTU |

## Common issues

| Symptom | Likely cause | First check | Fix direction |
|---------|--------------|-------------|---------------|
| Locator Down | typo in prefix; zebra not running | `show segment-routing srv6 locator detail` | Проверить `segment-routing srv6` config |
| No IS-IS adj | wrong NET; interface not in IS-IS | `show isis interface` | Проверить interface config |
| ping ok, no SRH | normal IPv6 forwarding, no encap policy | `ip -6 route show \| grep seg6` | Для SRH нужен ЛР10 encap route |
| ping fail after SRv6 | missing kernel SID; seg6 disabled | `sysctl seg6_enabled`, `grep seg6local` | Включить sysctl, проверить zebra |
| BGP VPN route есть, ping VRF fail | service SID/VRF lookup broken | `show ipv6 route vrf TENANT_A`, `grep End.DT6` | Проверить ЛР11 config |

## Report template for incident

```text
Symptom:
Layer: stand / FRR control plane / kernel dataplane / packet
Evidence:
Root cause:
Fix:
Verification:
```
