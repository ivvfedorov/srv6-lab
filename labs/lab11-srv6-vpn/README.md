# Сценарий 11: BGP SRv6 L3VPN — VRF, End.DT4/End.DT6, VPNv6

**Неделя 3+ (advanced)** | Время: ~3.5 ч

## Цель

Развернуть межсайтовый L3VPN поверх SRv6: настроить VRF на PE-узлах (r1, r3),
поднять BGP VPNv6, увидеть End.DT4 и End.DT6 SID в работе, проследить путь пакета
от CE до CE через SRv6-транспорт.

После выполнения необходимо уметь объяснить, как BGP переносит клиентский маршрут вместе
с SRv6 service SID, и почему удалённый PE понимает, в какую VRF поместить пакет.

## Что нужно знать заранее

- VRF — отдельная таблица маршрутизации на одном PE.
- BGP VPNv6 переносит маршруты VPN-клиентов между PE.
- SRv6 service SID выполняет роль сервисного указателя, похожую на VPN label в MPLS L3VPN.
- End.DT6/End.DT4 — behavior деинкапсуляции в VRF, а не transit-forwarding behavior.

Рекомендуемое чтение: [../../docs/theory-foundations.md](../../docs/theory-foundations.md),
раздел 10, и [../../docs/theory-srv6-advanced.md](../../docs/theory-srv6-advanced.md),
раздел 5.

## Теория

Два сайта клиента разделены транспортной сетью провайдера. Нужна L3-связность
между ними, но трафик разных клиентов не должен смешиваться на одном PE.
В MPLS это решается двумя метками (транспортная + VPN), в SRv6 — двумя типами SID:
транспортный (End/End.X) и сервисный (End.DT6/End.DT4).

VRF — это изолированная таблица маршрутизации на PE (аналог VRF-lite).
Каждый VRF содержит собственный набор маршрутов клиента, отдельный от default
table и от других VRF того же узла.

End.DT6 работает как терминирующая VPN-метка в MPLS: когда пакет попадает на PE
с DA = End.DT6 SID, узел делает Pop внешнего IPv6-заголовка и отправляет
внутренний Payload на чистый IPv6 lookup в конкретную VRF. Никакого transit —
behaviour строго терминирующий.

BGP VPNv6 (address-family ipv6 vpn) распространяет как клиентский префикс,
так и SRv6 Service SID (аналог VPN label в MP_REACH_NLRI). Route Distinguisher
обеспечивает уникальность префикса в глобальной таблице VPNv6, Route Target
управляет импортом/экспортом маршрутов между VRF.

Главная точка отказа: BGP-сессия поднята, но VPN-маршруты не приходят. Причина —
`segment-routing srv6 / locator` не добавлен в address-family ipv6 vpn. BGP
анонсирует обычное VPNv6 без SRv6 Service SID, и удалённый PE не знает, в какую
VRF деинкапсулировать пакет.

```text
Маршрут клиента в VRF
        |
        v
BGP VPNv6 NLRI + RD/RT + SRv6 service SID
        |
        v
Удалённый PE устанавливает VPN-маршрут c SID
        |
        v
Трафик инкапсулируется поверх SRv6-транспорта
        |
        v
End.DT6/End.DT4 деинкапсулирует в целевую VRF
```

Подробнее: [расширенная теория, раздел 5](../../docs/theory-srv6-advanced.md#5-bgp-srv6-l3vpn).

| Термин | Значение |
|--------|----------|
| PE | Provider Edge, узел с VRF клиента |
| P | Provider core, транспортный узел без клиентской VRF |
| RR | Route Reflector, отражает BGP-маршруты между PE |
| VRF | Отдельная таблица маршрутизации tenant’а |
| RD | Route Distinguisher, делает VPN-префикс уникальным |
| RT | Route Target, управляет import/export маршрутов |
| End.DT6 SID | SRv6 service SID для IPv6 lookup в VRF |

В этой лаборатории конфиг намеренно упрощён: явные RD/RT могут не присутствовать
в виде отдельных строк CLI. Для практического понимания всё равно нужно знать
их роль, потому что в production L3VPN именно RD/RT делают VPN-префиксы
уникальными и управляют импортом/экспортом маршрутов между VRF.
## Архитектура

```
          ┌──────────────┐       ┌──────────────┐       ┌──────────────┐
          │   r1 (PE1)   │       │  r2 (P / RR) │       │   r3 (PE2)   │
          │  AS 65000    │       │  AS 65000    │       │  AS 65000    │
          │              │       │              │       │              │
TENANT_A ─┤ tenant-a     ├───────┤  IS-IS SRv6  ├───────┤ tenant-a     ├─ TENANT_A
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
4. Инженер понимает различие между transport locator и service SID.

```bash
# Проверка перед началом
make deploy
make srv6
docker exec clab-srv6-r1 vtysh -c "show segment-routing srv6 locator"
docker exec clab-srv6-r1 vtysh -c "show isis neighbor"
```

## Подготовка: включение BGP и VRF

### Шаг 0: Переконфигурируйте стенд с BGP

В существующем стенде BGP не активен. Примените VPN-конфиги:

```bash
make vpn
```

`make vpn` создаёт Linux VRF `TENANT_A` и dummy-интерфейс `tenant-a` на PE-узлах,
перечитывает FRR-конфиг и затем запускает VPN-проверки.

После `make vpn` проверьте BGP:

```bash
docker exec clab-srv6-r1 vtysh -c "show bgp summary"
```

## Шаги проверки

### 1. Изучите конфигурацию PE (r1)

Прочитайте `configs/srv6/r1/frr-vpn.conf`. Найдите и объясните:

- Блок `vrf TENANT_A` — что делает `vni 101`?
- Есть ли в этой лабораторной конфигурации явные RD/RT? Если нет, за счёт чего FRR связывает
  VRF, VNI и VPN route export/import в упрощённой модели?
- Блок `interface tenant-a`:
  - Почему клиентские адреса находятся не на transport-интерфейсе `eth1`?
  - Как Linux VRF `TENANT_A` отделяет tenant-маршруты от default table?
- Блок `router bgp 65000`:
  - Почему соседом указан `2001:db8:2::2` (r2), а не r3 напрямую?
  - Что означает `address-family ipv6 vpn`?
  - Зачем в address-family указан `segment-routing srv6 / locator LOC1`?
- Блок `router bgp 65000 vrf TENANT_A`:
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
2001:db8:2::2   4 65000      42      44  00:15:23           1
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
Route Distinguisher: <auto-generated RD for TENANT_A>
*> 2001:db8:dead::1/128
                    2001:db8:1::1            0    100      0 i
                    SID: 2001:db8:1:a606::
```

**Обратите внимание**: Next-Hop = `2001:db8:1::1` (loopback PE1), и присутствует
SRv6 SID `2001:db8:1:a606::` (End.DT6 в VRF TENANT_A на r1).

Если конкретный формат вывода FRR отличается, найдите три обязательных признака: VPN-префикс,
next-hop PE и SRv6 SID. Без этих трёх признаков нельзя утверждать, что route является SRv6
VPN-маршрутом.

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
- `C 2001:db8:dead::1/128` (connected, tenant-a)
- `B 2001:db8:beef::1/128` (BGP, получен от r3 через VPNv6)

На r3 — зеркально:
- `B 2001:db8:dead::1/128` (BGP, получен от r1)
- `C 2001:db8:beef::1/128` (connected, tenant-a)

### 7. Проверьте connectivity (End-to-End)

```bash
# Ping из VRF TENANT_A на r1 к tenant-a адресу r3
# -I TENANT_A = выход через VRF (не интерфейс, а имя VRF)
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

Эта схема является главным ключевым результатом Сценарий 11. Если она заполнена правильно,
инженер понимает не только команды FRR, но и путь пакета через transport и service layers.

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
2001:db8:2::2   4 65000      42      44  00:15:23           1

# VPNv6 routes (r3):
r3# show bgp ipv6 vpn
   Network               Next Hop            Metric LocPrf Weight Path
Route Distinguisher: <auto-generated RD for TENANT_A>
*> 2001:db8:dead::1/128  2001:db8:1::1            0    100      0 i
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

## Критерии валидации

- [ ] BGP-сессия r1 ↔ r2, r3 ↔ r2: Established
- [ ] VPNv6-маршруты анонсированы и приняты (проверка на r1 и r3)
- [ ] End.DT6 SID присутствует в FRR (`show segment-routing srv6 sid`) и в kernel (`seg6local`)
- [ ] VRF-таблицы содержат BGP-маршруты (`show ipv6 route vrf TENANT_A`)
- [ ] Ping IPv6 из VRF r1 в VRF r3 успешен (3/3)
- [ ] Ping IPv4 из VRF r1 в VRF r3 успешен (3/3) — End.DT4
- [ ] SRH захвачен на r2, проанализирован Segment List и DA
- [ ] Схема пути пакета заполнена (задание 10)
- [ ] Объяснить, зачем в BGP update передаётся SRv6 SID (подсказка: это аналог VPN label в MPLS)

## Контрольные вопросы

1. Почему transport locator и End.DT6 service SID решают разные задачи?
2. Зачем BGP VPNv6 нужен RD?
3. Как RT/import-export policy защищает изоляцию tenant'ов?
4. Почему r2 может быть route reflector, но не иметь VRF `TENANT_A`?
5. Что должно случиться на PE, когда пакет приходит с DA = End.DT6 SID?

## Артефакты диагностики

- Схема PE-P-RR-PE с VRF и transport locator'ами.
- Вывод BGP summary и VPNv6 route с SRv6 SID.
- Вывод SID в FRR и `seg6local` в kernel.
- Проверка IPv6 и IPv4 connectivity из VRF.
- Заполненная схема полного пути пакета из задания 10.

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

