# Расширенная теория SRv6

Этот документ углубляет понимание SRv6 за пределы базовых лаб ЛР5–ЛР7. Если вы прошли
базовый курс и умеете включать locator + IS-IS — этот материал закрывает пробелы до уровня
production-ready.

**Целевая аудитория**: прошли ЛР1–ЛР7, понимают разницу между control plane и data plane,
умеют пользоваться `vtysh`, `tcpdump`, `sysctl`.

---

## Оглавление

1. [Структура SID: Locator : Function : Argument](#1-структура-sid-locator--function--argument)
2. [uSID и компрессия](#2-usid-и-компрессия)
3. [SR Policy: основа source-routing](#3-sr-policy-основа-source-routing)
4. [Как IS-IS анонсирует SRv6: TLV-механика](#4-как-is-is-анонсирует-srv6-tlv-механика)
5. [BGP SRv6 L3VPN](#5-bgp-srv6-l3vpn)
6. [Flexible Algorithm (Flex-Algo)](#6-flexible-algorithm-flex-algo)
7. [SRv6 OAM: ping, traceroute, loopback](#7-srv6-oam-ping-traceroute-loopback)
8. [TI-LFA: быстрая защита в SRv6](#8-ti-lfa-быстрая-защита-в-srv6)
9. [Полный справочник поведений (Behaviours)](#9-полный-справочник-поведений-behaviours)
10. [Ссылки на RFC и draft](#10-ссылки-на-rfc-и-draft)

---

## 1. Структура SID: Locator : Function : Argument

### 1.1 Определение (RFC 8986, Section 3.1)

Каждый SRv6 SID — это 128-битный IPv6-адрес, разделённый на три логические части:

```
|<--------------- SID (128 бит) --------------------------------->|
|<----- Locator (B бит) ------->|<-- Function (N бит) -->|<-- Arg -->|
```

| Часть | Назначение | Пример |
|-------|-----------|--------|
| **Locator** | Адресует узел в сети. Все узлы знают маршрут к locator-префиксу через IGP. | `2001:db8:1::/64` → r1 |
| **Function** | Идентифицирует поведение (End, End.X, End.DT4, ...) на узле. | `:e000:` = End.X |
| **Argument** (опционально) | Аргумент для поведения (например, VRF-идентификатор для End.DT4). | `:0101:` = VRF tenant-A |

### 1.2 Расчёт ёмкости

В нашей лабе locator = `/64` (B = 64). Оставшиеся 64 бита делятся между Function и Argument.

- При длине функции **16 бит** (uSID): можно разместить **4 функции** в одном locator'е (`16 × 4 = 64`).
- При длине функции **32 бита**: можно разместить **2 функции**.
- При длине функции **без компрессии** (64 бита): 1 функция + 0 на аргумент.

**Практическое правило**: `/64` locator с 16-битной функцией даёт `2^16 = 65 536` SID на узел,
с 32-битной — `2^32 ≈ 4.3 млрд`.

### 1.3 Почему locator именно /64?

- **Агрегация в IGP**: чем короче префикс, тем меньше записей в FIB. `/64` — компромисс между
  гибкостью (много SID на узел) и размером таблицы маршрутизации.
- **Совместимость с uSID**: uSID block по умолчанию 16 бит, и `/64` даёт ровно 4 uSID-контейнера
  на один 128-битный SID.
- В реальных сетях операторы используют `/48` (агрегация на уровне сайта), `/64` (per-node)
  и `/80` или `/96` (per-service).

### 1.4 Как проверить в FRR

```bash
vtysh -c "show segment-routing srv6 locator detail"
```

Показывает префикс locator'а и выделенные block-диапазоны (если настроена компрессия).

---

## 2. uSID и компрессия

### 2.1 Проблема: overhead заголовка

Без компрессии каждый SID занимает **128 бит** (16 байт). SRH с 5 SID: `8 (фикс. заголовок) + 5 × 16 = 88 байт`.
При MTU 1500 это значительная потеря полезной нагрузки.

### 2.2 Идея uSID (micro-SID)

uSID (draft-ietf-spring-srv6-srh-compression) сокращает размер одного SID до 16 или 32 бит
и упаковывает несколько uSID в один 128-битный Destination Address.

```
Обычный SID (без компрессии):
[ 128-bit locator + function = один SID в DA ]

С uSID (16-битная функция):
[ 32-бит uSID Block ] [ 16-бит func1 ] [ 16-бит func2 ] [ 16-бит func3 ] ... [ 16-бит End-of-Carrier ]
    <--- один IPv6 Destination Address (128 бит) содержит до 6 uSID --->
```

### 2.3 Ключевые понятия

| Термин | Определение |
|--------|-------------|
| **uSID block** | Старшие биты locator'а, общие для всех uSID на узле (обычно 32 бита). |
| **uSID carrier** | 128-битный IPv6-адрес, вмещающий несколько uSID-функций. |
| **uSID function** | 16-битная (или 32-битная) функция внутри carrier. |
| **End-of-Carrier** | Специальный uSID (обычно `0000`), отмечающий конец списка. |

### 2.4 uN и uA — это uSID-варианты

В нашей лабе IS-IS автоматически создаёт uN (End, Prefix-SID) и uA (End.X, Adjacency SID).
Приставка `u` означает «micro-SID вариант» — эти SID имеют 16-битную функцию.

```bash
# В FRR это отображается как:
r1# show segment-routing srv6 sid
SID                   Behavior    Context
2001:db8:1::          uN          isis(0)          # End, 16-битная функция 0x0000
2001:db8:1:e000::     uA          interface eth1   # End.X, 16-битная функция 0xE000
```

### 2.5 NEXT-C-SID и CSRv6

Два основных конкурирующих подхода к компрессии в индустрии:

| Подход | Размер SID | Стандартизация |
|--------|-----------|----------------|
| **uSID** (Cisco) | 16 бит, uSID carrier | draft-ietf-spring-srv6-srh-compression |
| **CSRv6** (Huawei/ZTE) | 32 бита, G-SID | В рамках того же draft |

FRR 8.4+ поддерживает uSID через параметры `usid-block-len` и `usid-func-len`.

---

## 3. SR Policy: основа source-routing

### 3.1 Что такое SR Policy

**RFC 9256** определяет SR Policy как тройку `(headend, color, endpoint)` с одним или более
Candidate Path.

```
SR Policy = {
  headend:    узел, инициирующий инкапсуляцию (PE)
  color:      TE-цель (low-latency, high-bandwidth, ...)
  endpoint:   конечная точка (PE назначения)

  Candidate Paths: [
    {
      origin:       кто создал путь (PCEP, BGP, CLI)
      preference:   приоритет (выбирается highest)
      Segment Lists: [
        { SIDs: [SID1, SID2, SID3], weight: 1 },
        { SIDs: [SID4, SID5, SID6], weight: 1 }   # ECMP
      ]
    }
  ]
}
```

### 3.2 Зачем нужен SR Policy

Без Policy трафик идёт по IGP shortest-path. Policy позволяет:

- **Traffic Engineering** — направить трафик не по shortest path.
- **Разделение сервисов** — один цвет для голосового трафика, другой для данных.
- **Резервирование** — активный + резервный Candidate Path.

### 3.3 Candidate Path и BSID

**Candidate Path** — один из вариантов маршрута для Policy. Может быть создан:

- **CLI** (явно администратором)
- **PCEP** (от внешнего SDN-контроллера)
- **BGP SR-TE** (анонсирован соседним узлом)

**BSID (Binding SID)** — короткий идентификатор, ссылающийся на конкретный SR Policy.
Когда узел получает пакет с BSID в destination, он применяет связанный Policy.

```
Пример:
  Policy: r1 -> r3, color=10, endpoint=2001:db8:3::3
    BSID: 2001:db8:1:b001::
    Candidate Path 1 (pref=100):
      Segment List: [2001:db8:2:e001::, 2001:db8:3::]

  Policy: r1 -> r3, color=20 (резервный путь)
    BSID: 2001:db8:1:b002::
    Candidate Path 1 (pref=100):
      Segment List: [2001:db8:1:e000::]  # напрямую через r2:eth1
```

### 3.4 Конфигурация в FRR (фрагмент)

```
segment-routing
 srv6
  locators
   locator LOC1
    prefix 2001:db8:1::/64
   exit
  exit
 exit
!
router bgp 65000
 bgp router-id 1.1.1.1
 neighbor 2001:db8:3::3 remote-as 65000
 !
 address-family ipv6 vpn
  neighbor 2001:db8:3::3 activate
  segment-routing srv6
   locator LOC1
  exit
 exit-address-family
!
```

### 3.5 Как проверить SR Policy

```bash
vtysh -c "show segment-routing srv6 policy"
vtysh -c "show segment-routing srv6 policy detail"
vtysh -c "show bgp ipv6 vpn"
```

---

## 4. Как IS-IS анонсирует SRv6: TLV-механика

### 4.1 Общий принцип

IS-IS анонсирует SRv6-информацию как sub-TLV внутри **Router Capability TLV (тип 242)**
в LSP (Link State PDU).

### 4.2 Структура анонсов

| TLV / sub-TLV | Назначение | IETF-код |
|---------------|-----------|----------|
| **SRv6 Capabilities sub-TLV** | Флаги поддержки (O-flag для OAM) | sub-TLV 25 внутри TLV 242 |
| **SRv6 Locator TLV** (тип 27) | Префикс locator'а, алгоритм, метрика | TLV 27 внутри TLV 242 |
| **SRv6 End SID sub-TLV** | End SID с флагами и behaviour | sub-TLV внутри Locator TLV |
| **SRv6 End.X SID sub-TLV** | End.X SID с adjacency-информацией | sub-TLV внутри Locator TLV |
| **SRv6 LAN End.X SID sub-TLV** | End.X на broadcast-интерфейсе | sub-TLV внутри Locator TLV |

### 4.3 Просмотр LSP в FRR

```bash
# Показать все LSP в базе
docker exec clab-srv6-r1 vtysh -c "show isis database detail"

# Найти SRv6 Locator TLV в сыром виде
docker exec clab-srv6-r1 vtysh -c "show isis database detail r1.00-00" | grep -A20 "SRv6"
```

### 4.4 Захват LSP в Wireshark

1. Захватите IS-IS Hello/CSNP/LSP на интерфейсе:

```bash
docker exec clab-srv6-r2 tcpdump -ni eth1 -c 50 -w /tmp/isis-lsp.pcap \
  'proto 124'   # 124 = IS-IS over IPv6
```

2. Скопируйте pcap на хост и откройте в Wireshark.
3. Фильтр: `isis.lsp`.
4. Найдите TLV 242 (Router Capability) → sub-TLV SRv6 Locator → sub-TLV End SID.

### 4.5 Связь LSP → RIB → FIB

```
IS-IS LSP (TLV 27: Locator)
       │
       ▼
zebra RIB (show ipv6 route — код I)
       │
       ▼  netlink (RTM_NEWROUTE)
kernel FIB (ip -6 route show table all | grep seg6)
       │
       ▼
seg6_local input (обработка пакета с SID в DA)
```

---

## 5. BGP SRv6 L3VPN

### 5.1 Архитектура

В классическом MPLS L3VPN используется два стека меток: транспортная (LDP/RSVP-TE) + сервисная
(VPN label). В SRv6 метки заменяются на SID:

```
MPLS L3VPN:     [Transport Label] [VPN Label] [Payload]
SRv6 L3VPN:     [IPv6 DA = VPN SID] [SRH: transport SID(s)] [Payload]
```

**VPN SID** (End.DT4/End.DT6) — анонсируется через BGP VPNv4/VPNv6 update как SRv6 SID в
MP_REACH_NLRI.

**Transport SID** (End, End.X) — обеспечивает достижимость PE через IGP.

### 5.2 End.DT4 vs End.DT6

| Behaviour | Назначение | Протокол |
|-----------|-----------|----------|
| **End.DT6** | IPv6 L3VPN: деинкапсуляция IPv6 пакета в VRF | BGP VPNv6 |
| **End.DT4** | IPv4 L3VPN: деинкапсуляция IPv4 пакета в VRF | BGP VPNv4 |
| **End.DX6** | IPv6 EVPN: L2-сервис (L2 bridge domain) | BGP EVPN |
| **End.DX4** | IPv4 EVPN: L2-сервис | BGP EVPN |

### 5.3 Как выглядит BGP update с SRv6 SID

BGP использует **MP_REACH_NLRI** (AFI=2, SAFI=128 для VPNv6) с атрибутом
**SRv6 SID Information** (sub-TLV в Prefix-SID Attribute, тип 40).

```
BGP Update:
  MP_REACH_NLRI:
    AFI: IPv6 (2), SAFI: VPNv6 (128)
    Next-Hop: 2001:db8:1::1  (loopback PE)
    NLRI: 2001:db8:1::1, RD=65000:100, Prefix=2001:db8:dead::/64
    Prefix-SID Attribute (type 40):
      SRv6 L3VPN Service sub-TLV:
        SID: 2001:db8:1:0101::  (End.DT6 в VRF tenant-A)
```

### 5.4 Путь пакета в SRv6 L3VPN

```
CE1 → PE1 (r1) → P (r2) → PE2 (r3) → CE2

1. CE1 отправляет IPv6-пакет на CE2.
2. PE1 (r1) делает lookup в VRF, находит BGP-маршрут с VPN SID.
3. PE1 инкапсулирует: Destination = VPN SID (2001:db8:3:0101::),
   SRH: [transport SID r2, transport SID r3].
4. r2 форвардит по DA (End.X на eth2).
5. r3: DA = 2001:db8:3:0101:: = End.DT6 в VRF tenant-A.
   Поведение: удалить IPv6-заголовок, lookup в VRF tenant-A, форвардить CE2.
```

### 5.5 Минимальная конфигурация (PE1, фрагмент)

```
# VRF
vrf TENANT_A
 vni 101
exit-vrf
!
interface tenant-a
 vrf TENANT_A
 ipv6 address 2001:db8:dead::1/128
!
# BGP
router bgp 65000
 bgp router-id 1.1.1.1
 neighbor 2001:db8:2::2 remote-as 65000
 !
 address-family ipv6 vpn
  neighbor 2001:db8:2::2 activate
  segment-routing srv6
   locator LOC1
  exit
 exit-address-family
!
router bgp 65000 vrf TENANT_A
 address-family ipv6 unicast
  redistribute connected
  segment-routing srv6
   locator LOC1
   auto-sid
  exit
 exit-address-family
!
```

---

## 6. Flexible Algorithm (Flex-Algo)

### 6.1 Идея

Flex-Algo (RFC 9350) позволяет определить **альтернативную топологию** поверх той же
физической сети, с собственными:

- Метриками (например, задержка вместо стоимости)
- Ограничениями (exclude определённые линки)
- SID-пространством (отдельный locator)

### 6.2 Algo 0 vs Algo 128+

| Алгоритм | Значение | Топология |
|----------|---------|-----------|
| **Algo 0** | Shortest Path (стандартная метрика) | Все линки, best-effort |
| **Algo 128** | Low-Latency (TE-метрика = задержка) | Только линки с задержкой < 10 мс |
| **Algo 129** | High-Bandwidth | Только линки с bandwidth > 10 Гбит/с |

### 6.3 Два locator'а на одном узле

Узел участвует в нескольких топологиях через отдельные locator'ы:

```
segment-routing
 srv6
  locators
   locator LOC_ALGO0
    prefix 2001:db8:1::/64
    algorithm 0
   exit
   locator LOC_LOWLAT
    prefix 2001:db8:1001::/64
    algorithm 128
   exit
  exit
 exit
!
router isis CORE
 segment-routing srv6
  locator LOC_ALGO0
  locator LOC_LOWLAT
 exit
!
```

### 6.4 Как трафик попадает в нужный алгоритм

1. **Colour-based**: SR Policy с цветом, привязанным к алгоритму (через BGP цветных маршрутов).
2. **Destination-based**: префикс анонсирован с участием в определённом алгоритме.

---

## 7. SRv6 OAM: ping, traceroute, loopback

### 7.1 Проблема

Обычный `ping6 2001:db8:3::3` проверяет **только IGP-достижимость**, но не проверяет,
что конкретный SID (например, End.DT4) работает корректно.

### 7.2 SRv6 Ping

Определён в RFC 9256 (§6.9) и draft-ietf-6man-spring-srv6-oam. Отправляет пакет с SRH,
где последний SID = `::` (End-of-SID), а предпоследний — это SID тестируемого узла.
Узел обрабатывает SID, и если поведение End — посылает ICMPv6 Echo Reply.

```bash
# Ручной SRv6 ping на локальный End SID узла r3
ip -6 route add 2001:db8:3::/128 encap seg6 mode encap \
  segs 2001:db8:3:: dev eth1
ping6 2001:db8:3::
```

### 7.3 SRv6 Traceroute

Использует Hop Limit в SRH аналогично расширенному traceroute в MPLS:

```bash
traceroute6 -n 2001:db8:3::3
# Каждый hop (r1, r2, r3) отвечает ICMPv6 Time Exceeded,
# если Hop Limit в SRH достигает 0.
```

### 7.4 Loopback-тест

Для тестирования End.DT6 без второго CE:

```bash
# r3: статический End.DT6 + loopback-интерфейс в VRF
# r1: ping на End.DT6 SID с SRH
ip -6 route add 2001:db8:3:fe::/128 encap seg6 mode encap \
  segs 2001:db8:3:fe:: dev eth1
ping6 2001:db8:3:fe::
```

---

## 8. TI-LFA: быстрая защита в SRv6

### 8.1 Проблема

При падении линка IS-IS должен:
1. Обнаружить падение (hello timeout: ~9–30 сек без BFD).
2. Перестроить SPF.
3. Обновить FIB.

Это **сотни миллисекунд или секунды** — неприемлемо для критичного трафика (<50 мс).

### 8.2 Идея TI-LFA

**Topology-Independent Loop-Free Alternate** — **предварительно вычисленный** резервный путь,
который гарантированно не создаёт петлю, и использует явный segment list (SR Policy) для
обхода точки отказа.

```
      r1 ----- r2 ----- r3
       \               /
        \---- r4 -----/

Без защиты: r2→r3, линк падает → потеря трафика на время сходимости IGP.

С TI-LFA (на r2, защита линка r2-r3):
  Резервный путь: r2 → r1 → r4 → r3.
  Segment List:   [End.X на r1 в сторону r4, End на r4]  // пост-конвергенция через P-пространство + Q-пространство
```

### 8.3 Терминология

| Термин | Определение |
|--------|-------------|
| **P-пространство** | Узлы, достижимые от PLR без прохождения через защищаемый линк. |
| **Q-пространство** | Узлы, которые могут достичь destination без прохождения через защищаемый линк. |
| **PLR** (Point of Local Repair) | Узел, выполняющий защитное переключение (r2). |
| **PQ-узел** | Узел, входящий и в P-, и в Q-пространство. Оптимальная точка стыковки. |

### 8.4 Конфигурация в FRR (концептуально)

```
router isis CORE
 fast-reroute ti-lfa
  segment-routing srv6
   locator LOC1
  exit
 exit
!
```

---

## 9. Полный справочник поведений (Behaviours)

Источник: **RFC 8986** (SRv6 Network Programming).

### 9.1 End-поведения (терминирующие)

| Код | FRR-имя | RFC | Назначение |
|-----|---------|-----|-----------|
| End | uN | 8986 §4.1 | Prefix-SID узла. Pop SRH, forward по inner destination. |
| End.DT6 | uDT6 | 8986 §5.1 | IPv6 VPN: decap + lookup в VRF. |
| End.DT4 | uDT4 | 8986 §5.2 | IPv4 VPN: decap + lookup в VRF. |
| End.DT46 | uDT46 | 8986 §5.3 | IPv4+IPv6 VPN: decap, определение AF по payload. |
| End.DX6 | uDX6 | 8986 §5.1.1 | L2 EVPN: cross-connect в L2 bridge domain (IPv6). |
| End.DX4 | uDX4 | 8986 §5.2.1 | L2 EVPN: cross-connect в L2 bridge domain (IPv4). |
| End.B6.Encaps | — | 8986 §4.3 | Binding SID: применить SR Policy, инкапсулировать. |

### 9.2 End.X-поведения (транзитные)

| Код | FRR-имя | RFC | Назначение |
|-----|---------|-----|-----------|
| End.X | uA | 8986 §4.2 | Cross-connect на конкретный L3 adjacency. |
| End.DX2 | — | 8986 | L2 cross-connect без lookup (point-to-point L2VPN). |

### 9.3 Маппинг на MPLS

| MPLS | SRv6 |
|------|------|
| Prefix-SID (Node-SID) | End (uN) |
| Adjacency-SID | End.X (uA) |
| VPN Label | End.DT4 / End.DT6 |
| Binding SID | End.B6.Encaps |

---

## 10. Ссылки на RFC и draft

| Документ | Тема | Ссылка |
|----------|------|--------|
| **RFC 8986** | SRv6 Network Programming (behaviours) | [tools.ietf.org](https://datatracker.ietf.org/doc/html/rfc8986) |
| **RFC 8754** | IPv6 Segment Routing Header (SRH) | [tools.ietf.org](https://datatracker.ietf.org/doc/html/rfc8754) |
| **RFC 9256** | SR Policy Architecture | [tools.ietf.org](https://datatracker.ietf.org/doc/html/rfc9256) |
| **RFC 9350** | IGP Flexible Algorithm | [tools.ietf.org](https://datatracker.ietf.org/doc/html/rfc9350) |
| **RFC 8402** | Segment Routing Architecture | [tools.ietf.org](https://datatracker.ietf.org/doc/html/rfc8402) |
| **draft-ietf-spring-srv6-srh-compression** | uSID / NEXT-C-SID / CSRv6 | [datatracker](https://datatracker.ietf.org/doc/draft-ietf-spring-srv6-srh-compression/) |
| **draft-ietf-bess-srv6-services** | BGP SRv6 services (L3VPN, EVPN) | [datatracker](https://datatracker.ietf.org/doc/draft-ietf-bess-srv6-services/) |
| **Linux kernel seg6 docs** | SRv6 в ядре Linux | [kernel.org](https://docs.kernel.org/networking/seg6.html) |
| **FRR SRv6 docs** | Реализация в FRR | [docs.frrouting.org](https://docs.frrouting.org/en/latest/) |

---

## Минимальный трек для перехода от ЛР7 к advanced

1. Прочитать разделы **1** (SID Structure) и **2** (uSID).
2. Прочитать раздел **3** (SR Policy) до подраздела 3.3.
3. Прочитать раздел **4** (IS-IS TLV) — это даст понимание, «что на самом деле происходит в LSP».
4. Выполнить **ЛР10** (SR Policy).
5. Прочитать разделы **5** (BGP L3VPN) и **6** (Flex-Algo).
6. Выполнить **ЛР11** (BGP SRv6 L3VPN).
7. Остальные разделы — по мере интереса.
