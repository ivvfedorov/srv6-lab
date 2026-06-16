# ЛР11: BGP SRv6 L3VPN — VRF, End.DT4/End.DT6, VPNv6

**Неделя 3+ (advanced)** | Время: ~3.5 ч

## Цель

Развернуть межсайтовый L3VPN поверх SRv6: настроить VRF на PE-узлах (r1, r3),
поднять BGP VPNv6, увидеть End.DT4 и End.DT6 SID в работе, проследить путь пакета
от CE до CE через SRv6-транспорт.

## Теория

L3VPN разделяет маршруты разных клиентов через VRF. В MPLS VPN сервисный контекст обычно
передаётся VPN label, а в SRv6 эту роль выполняет service SID: End.DT4 для IPv4 VRF и End.DT6
для IPv6 VRF. Когда пакет приходит на PE с Destination Address, равным End.DT6 SID, узел
деинкапсулирует внешний заголовок и делает lookup внутреннего IPv6-пакета в нужной VRF.

BGP VPNv6 распространяет не только префикс клиента, но и next-hop PE вместе с SRv6 service SID.
Transport reachability до PE обеспечивает IS-IS SRv6 locator, а сервисную доставку в VRF
обеспечивает End.DT SID. Поэтому проверка VPN состоит из трёх частей: BGP-сессия и VPNv6 NLRI,
SID в FRR/kernel, end-to-end ping из VRF.

Подробнее: [расширенная теория, раздел 5](../../docs/theory-srv6-advanced.md#5-bgp-srv6-l3vpn).

## Архитектура

```
          ┌──────────────┐       ┌──────────────┐       ┌──────────────┐
          │   r1 (PE1)   │       │  r2 (P / RR) │       │   r3 (PE2)   │
          │  AS 65001    │       │  AS 65002    │       │  AS 65003    │
          │              │       │              │       │              │
TENANT_A ─┤ lo:1 (dummy) ├───────┤  IS-IS SRv6  ├───────┤ lo:1 (dummy) ├─ TENANT_A
          │ 192.168.1.1  │       │   transport  │       │ 192.168.3.1  │
          │ dead::1      │       │              │       │ beef::1      │
          └──────────────┘       └──────────────┘       └──────────────┘
               eth1 ←──2001:db8:12::/64──→ eth1 (r2) ←──2001:db8:23::/64──→ eth2 (r3)

BGP Peering (VPNv6):
  r1 (PE) ←→ r2 (Route Reflector) ←→ r3 (PE)

SRv6 Transport:
  r1 → [End.X r2→r3] → [End r3] → End.DT6 → VRF TENANT_A → CE
```

## Предусловия

1. Основная лаба развернута.
2. SRv6 включён и IS-IS сходится.
3. VPN-конфиги из `configs/srv6/r*/frr-vpn.conf` доступны в репозитории.

```bash
# Проверка перед началом
make deploy
make srv6
docker exec clab-srv6-r1 vtysh -c "show segment-routing srv6 locator"
docker exec clab-srv6-r1 vtysh -c "show isis neighbor"
```

## Подготовка: включение BGP и VRF

### Шаг 0: Переконфигурируйте лабу с BGP

В существующей топологии BGP не активен. Примените VPN-конфиги:

```bash
make vpn
```

После `make vpn` проверьте BGP:

```bash
docker exec clab-srv6-r1 vtysh -c "show bgp summary"
```

## Задания

### 1. Изучите конфигурацию PE (r1)

Прочитайте `configs/srv6/r1/frr-vpn.conf`. Найдите и объясните:

- Блок `vrf TENANT_A` — что делает `vni 101`?
- Блок `router bgp 65001`:
  - Почему соседом указан `2001:db8:2::2` (r2), а не r3 напрямую?
  - Что означает `address-family ipv6 vpn`?
  - Зачем в address-family указан `segment-routing srv6 / locator LOC1`?
- Блок `router bgp 65001 vrf TENANT_A`:
  - Зачем здесь второй экземпляр BGP?
  - Что делает `redistribute connected`?

### 2. Проверьте BGP-сессии

```bash
docker exec clab-srv6-r1 vtysh -c "show bgp summary"
docker exec clab-srv6-r2 vtysh -c "show bgp summary"
docker exec clab-srv6-r3 vtysh -c "show bgp summary"
```

Ожидаемый результат:

```
r1# show bgp summary
Neighbor        V    AS    MsgRcvd MsgSent  Up/Down  State/PfxRcd
2001:db8:2::2   4 65002      42      44  00:15:23           1
```

### 3. Проверьте VPN-маршруты (VPNv6)

```bash
# На r1 — что мы анонсируем?
docker exec clab-srv6-r1 vtysh -c "show bgp ipv6 vpn"

# На r3 — что мы получили от r1?
docker exec clab-srv6-r3 vtysh -c "show bgp ipv6 vpn"
```

Ожидаемый вывод (на r3):

```
   Network          Next Hop            Metric LocPrf Weight Path
Route Distinguisher: 65003:101
*> 2001:db8:dead::1/128
                    2001:db8:1::1            0    100      0 65002 65001 ?
                    SID: 2001:db8:1:a606::
```

**Обратите внимание**: Next-Hop = `2001:db8:1::1` (loopback PE1), и присутствует
SRv6 SID `2001:db8:1:a606::` (End.DT6 в VRF TENANT_A на r1).

### 4. Изучите SID — End.DT6

```bash
docker exec clab-srv6-r1 vtysh -c "show segment-routing srv6 sid"
docker exec clab-srv6-r3 vtysh -c "show segment-routing srv6 sid"
```

Найдите SID с Behavior `uDT6` (или `End.DT6`). Запишите SID и контекст (VRF).

### 5. Проверьте kernel SID (data plane)

```bash
docker exec clab-srv6-r1 ip -6 route show table local | grep seg6local
docker exec clab-srv6-r3 ip -6 route show table local | grep seg6local
```

Ожидаемый вывод:

```
local 2001:db8:1:a606:: dev lo scope host  <-- End.DT6 на r1
    seg6local action End.DT6 vrf TENANT_A
```

Это означает: когда на r1 приходит пакет с DA = `2001:db8:1:a606::`, ядро выполняет
`seg6local action End.DT6` — деинкапсулирует и делает lookup в VRF `TENANT_A`.

### 6. Проверьте VRF-маршруты на PE

```bash
docker exec clab-srv6-r1 vtysh -c "show ipv6 route vrf TENANT_A"
docker exec clab-srv6-r3 vtysh -c "show ipv6 route vrf TENANT_A"
```

На r1 должны быть:
- `C 2001:db8:dead::1/128` (connected, lo:1)
- `B 2001:db8:beef::1/128` (BGP, получен от r3 через VPNv6)

На r3 — зеркально:
- `B 2001:db8:dead::1/128` (BGP, получен от r1)
- `C 2001:db8:beef::1/128` (connected)

### 7. Проверьте connectivity (End-to-End)

```bash
# Ping из VRF TENANT_A на r1 к loopback'у r3 в том же VRF
docker exec clab-srv6-r1 ping6 -I TENANT_A -c 3 2001:db8:beef::1
```

Ожидаемый результат: **3/3 packets received**.

### 8. Захват SRv6 VPN-трафика на транспортном узле (r2)

```bash
# Терминал 1: захват на r2:eth1 (сторона r1)
docker exec clab-srv6-r2 tcpdump -ni eth1 -c 10 -vv 'ip6[40:1]=4' -w /tmp/vpn-srh-eth1.pcap

# Терминал 2: ping из VRF
docker exec clab-srv6-r1 ping6 -I TENANT_A -c 3 2001:db8:beef::1
```

Скопируйте pcap и откройте в Wireshark:

```bash
docker cp clab-srv6-r2:/tmp/vpn-srh-eth1.pcap /tmp/vpn-srh-eth1.pcap
```

**Вопросы для анализа**:

1. Какой Destination Address? Это транспортный SID или VPN SID?
2. Есть ли SRH? Если да — сколько SID в Segment List?
3. Какой Segments Left? Что будет на r3, когда он дойдёт до 0?
4. Где в пакете находится оригинальный (inner) IPv6-заголовок? Какой у него DA?
5. Сравните размер пакета на входе (от CE) и на выходе (в сторону r2) — какой overhead?

### 9. End.DT4: IPv4 VPN по SRv6

Если на PE настроены IPv4-адреса в VRF, проверьте IPv4-связность:

```bash
# Ping IPv4 из VRF r1 к loopback'у r3 в VRF TENANT_A
docker exec clab-srv6-r1 ping -I TENANT_A -c 3 192.168.3.1
```

Ожидаемый результат: **3/3**.

Проверьте IPv4 VPN-маршруты:

```bash
docker exec clab-srv6-r1 vtysh -c "show bgp vrf TENANT_A ipv4 unicast"
docker exec clab-srv6-r3 vtysh -c "show bgp vrf TENANT_A ipv4 unicast"
```

Найдите End.DT4 SID:

```bash
docker exec clab-srv6-r1 ip -6 route show table local | grep -A2 End.DT4
```

### 10. Анализ полного пути пакета (End-to-End)

Заполните схему пути пакета от CE на r1 до CE на r3:

```
Шаг 1 (r1, VRF lookup):
  Пакет: DA = 2001:db8:beef::1
  VRF TENANT_A → BGP маршрут → Next-Hop: ____, VPN SID: ____

Шаг 2 (r1, инкапсуляция):
  Новый IPv6-заголовок: DA = ____ (первый SID из SR Policy/IGP)
  SRH: [ ____, ____ ]
  Segments Left: ____

Шаг 3 (r2, transit):
  DA = ____ (End.X SID на r2)
  End.X: форвард на eth2, Segments Left-- → ____

Шаг 4 (r3, termination):
  DA = ____ (End.DT6 SID)
  End.DT6: деинкапсуляция, lookup в VRF ____
  Inner DA = ____ → CE loopback
```

### 11. Очистка

Верните базовые конфиги без BGP:

```bash
make redeploy
```

## Expected output

```
# BGP summary (r1):
r1# show bgp summary
Neighbor        V    AS    MsgRcvd MsgSent  Up/Down  State/PfxRcd
2001:db8:2::2   4 65002      42      44  00:15:23           1

# VPNv6 routes (r3):
r3# show bgp ipv6 vpn
   Network               Next Hop            Metric LocPrf Weight Path
Route Distinguisher: 65003:101
*> 2001:db8:dead::1/128  2001:db8:1::1            0    100      0 65002 65001 ?
                          SID: 2001:db8:1:a606::

# VRF route (r3):
r3# show ipv6 route vrf TENANT_A
B>* 2001:db8:dead::1/128 [200/0] via 2001:db8:1::1 (vrf default), ...

# Kernel SID (r3):
$ ip -6 route show table local | grep seg6local
local 2001:db8:3:a606:: dev lo scope host
    seg6local action End.DT6 vrf TENANT_A

# Ping (end-to-end):
$ ping6 -I TENANT_A -c 3 2001:db8:beef::1
3 packets transmitted, 3 received, 0% packet loss
```

## Критерий успеха

- [ ] BGP-сессия r1 ↔ r2, r3 ↔ r2: Established
- [ ] VPNv6-маршруты анонсированы и приняты (проверка на r1 и r3)
- [ ] End.DT6 SID присутствует в FRR (`show segment-routing srv6 sid`) и в kernel (`seg6local`)
- [ ] VRF-таблицы содержат BGP-маршруты (`show ipv6 route vrf TENANT_A`)
- [ ] Ping IPv6 из VRF r1 в VRF r3 успешен (3/3)
- [ ] Ping IPv4 из VRF r1 в VRF r3 успешен (3/3) — End.DT4
- [ ] SRH захвачен на r2, проанализирован Segment List и DA
- [ ] Схема пути пакета заполнена (задание 10)
- [ ] Объяснить, зачем в BGP update передаётся SRv6 SID (подсказка: это аналог VPN label в MPLS)

## Дополнительно: масштабирование

### Мульти-VRF (несколько tenant'ов)

Добавьте второй VRF (`TENANT_B`, VNI 102) на r1 и r3. Проверьте изоляцию:

```bash
# TENANT_B не должен видеть маршруты TENANT_A
docker exec clab-srv6-r1 vtysh -c "show ipv6 route vrf TENANT_B"
```

### Route Reflector (r2)

В нашей топологии r2 выступает Route Reflector (RR). Проверьте, что r1 и r3 не имеют
прямой BGP-сессии между собой:

```bash
docker exec clab-srv6-r1 vtysh -c "show bgp summary"
# Должна быть только одна сессия: к r2 (2001:db8:2::2)
```

Преимущества RR: r1 и r3 не нуждаются в full mesh, r2 отражает маршруты между ними.

## Ссылки

- [Расширенная теория, раздел 5 — BGP SRv6 L3VPN](../../docs/theory-srv6-advanced.md#5-bgp-srv6-l3vpn)
- [Расширенная теория, раздел 1 — SID Structure](../../docs/theory-srv6-advanced.md#1-структура-sid-locator--function--argument)
- [Расширенная теория, раздел 9 — Справочник поведений](../../docs/theory-srv6-advanced.md#9-полный-справочник-поведений-behaviours)
- [Cheatsheet (advanced)](../../docs/cheatsheet.md)
- [RFC 8986 — SRv6 Network Programming](https://datatracker.ietf.org/doc/html/rfc8986)
- [draft-ietf-bess-srv6-services — BGP SRv6 Services](https://datatracker.ietf.org/doc/draft-ietf-bess-srv6-services/)
- [Конфиги VPN](../../configs/srv6/)
