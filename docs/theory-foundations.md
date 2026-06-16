# Базовая теория: Linux networking, FRR и SRv6

Этот документ закрывает вводный уровень для инженеров, которые раньше не работали с Linux
networking, Containerlab, FRR и SRv6. Его не нужно читать полностью перед первым сценарием. Лучше
читать разделы по мере прохождения стенда и возвращаться к схемам при разборе вывода команд.

## 1. Как устроена лабораторная сеть

В лаборатории есть три маршрутизатора в контейнерах:

```text
r1 ----- r2 ----- r3
```

У каждого контейнера есть два типа сетей:

| Сеть | Интерфейс | Для чего нужна | Что изучаем |
|------|-----------|----------------|-------------|
| Management | `eth0` | Доступ Docker/Containerlab к контейнеру | Управление стендом |
| Data plane | `eth1`, `eth2` | Передача моделируемого трафика между роутерами | Маршрутизация, FRR, SRv6 |

Management-сеть не является частью моделируемой операторской сети. Если ping идёт по `eth0`, он
не доказывает работоспособность маршрутизации r1-r2-r3. В сценариях нас интересуют
data-интерфейсы и IPv6-префиксы `2001:db8:*::/64`.

## 2. Минимум Linux networking

Linux хранит сетевое состояние в ядре:

| Объект | Команда просмотра | Смысл |
|--------|-------------------|-------|
| Интерфейсы | `ip link show` | Список сетевых устройств и их состояние |
| IPv6-адреса | `ip -6 addr show` | Адреса на интерфейсах |
| Маршруты | `ip -6 route show` | Kernel FIB: что реально использует dataplane |
| Соседи | `ip -6 neigh show` | IPv6 Neighbor Discovery, аналог ARP для IPv6 |

Важное различие:

- **RIB** (Routing Information Base) — таблица маршрутов control plane. В FRR её видно через
  `vtysh -c "show ipv6 route"`.
- **FIB** (Forwarding Information Base) — таблица пересылки в Linux kernel. Её видно через
  `ip -6 route show`.

Если маршрут есть в FRR, но отсутствует в kernel, пакет по нему не пойдёт. Если маршрут есть в
kernel, но FRR его не знает, он мог быть добавлен вручную через `ip route` или другой процесс.

## 3. IPv6, next-hop и traceroute

IPv6-пакет имеет source address, destination address и hop limit. На каждом маршрутизаторе
kernel смотрит destination address, выбирает маршрут и отправляет пакет следующему узлу.

Пример r1 -> r3:

```text
IPv6 packet:
  Source:      2001:db8:12::1
  Destination: 2001:db8:3::3

Path:
  r1 -> r2 -> r3
```

На каждом линке меняется L2-сосед, но IPv6 destination остаётся конечным адресом `r3`.
Именно поэтому в pcap на r2 можно видеть transit-трафик r1 -> r3.

`traceroute6` работает через hop limit: отправляет серию пакетов с маленьким hop limit и
получает ICMPv6 Time Exceeded от промежуточных узлов.

## 4. Что делает FRR

FRRouting (FRR) — это набор routing daemon'ов в userspace:

| Демон | Роль |
|-------|------|
| `zebra` | Центральная RIB FRR, установка маршрутов в Linux kernel через netlink |
| `isisd` | Протокол IS-IS: соседства, LSP, вычисление маршрутов |
| `bgpd` | BGP: междоменная маршрутизация, VPNv6, SRv6 service SID |
| `staticd` | Статические маршруты |
| `watchfrr` | Запуск и контроль процессов FRR |
| `vtysh` | CLI для управления FRR |

Цепочка для обычного маршрута IS-IS:

```text
isisd получает LSP -> вычисляет маршрут -> передаёт zebra -> zebra пишет в kernel через netlink
```

Поэтому диагностика маршрута почти всегда идёт в таком порядке:

1. `show isis neighbor` — есть ли соседство.
2. `show ipv6 route` — появился ли маршрут в FRR RIB.
3. `ip -6 route show` — установлен ли маршрут в kernel FIB.
4. `ping6`/`traceroute6`/`tcpdump` — работает ли dataplane.

## 5. IS-IS в этой лаборатории

IS-IS — link-state IGP. Каждый роутер описывает свои линковые состояния в LSP, все роутеры
собирают одинаковую базу топологии и вычисляют shortest path.

В лаборатории используется level-2-only домен `CORE`:

```text
r1 NET: 49.0001.0000.0000.0001.00
r2 NET: 49.0001.0000.0000.0002.00
r3 NET: 49.0001.0000.0000.0003.00
```

Команды для проверки:

```bash
vtysh -c "show isis neighbor"
vtysh -c "show isis database"
vtysh -c "show ipv6 route"
```

## 6. Что такое netlink

Netlink — механизм обмена сообщениями между userspace и Linux kernel. Команда `ip`, библиотека
`pyroute2` и FRR `zebra` используют RTNETLINK для изменения сетевого состояния.

Когда выполняется:

```bash
ip -6 route add 2001:db8:99::/64 dev eth1
```

утилита `ip` не “настраивает сеть сама”. Она отправляет netlink-сообщение в kernel. Kernel
проверяет запрос и добавляет маршрут в FIB. Это можно наблюдать через:

```bash
ip monitor route
strace -e socket,sendmsg,recvmsg ip -6 route add ...
```

## 7. Что такое SRv6

Segment Routing — это подход, при котором отправитель задаёт путь через список сегментов.
В SRv6 сегмент кодируется обычным IPv6-адресом, который называется SID.

SID логически делится на части:

```text
SID = Locator + Function + Argument
```

| Часть | Назначение | Пример |
|-------|------------|--------|
| Locator | Доставить пакет до нужного узла | `2001:db8:2::/64` для r2 |
| Function | Какое действие выполнить на узле | End, End.X, End.DT6 |
| Argument | Дополнительный контекст, например VRF | tenant/service id |

В базовой SRv6-лаборатории:

| Узел | Locator |
|------|---------|
| r1 | `2001:db8:1::/64` |
| r2 | `2001:db8:2::/64` |
| r3 | `2001:db8:3::/64` |

## 8. SRH: Segment Routing Header

Если headend-узел хочет явно задать путь, он добавляет внешний IPv6-заголовок и SRH
(Segment Routing Header). В SRH лежит Segment List. Поле `Segments Left` показывает, сколько
сегментов ещё нужно обработать.

Упрощённо:

```text
Outer IPv6 DA = текущий активный SID
SRH Segment List = [SID r2, SID r3]
Inner packet = исходный пакет пользователя
```

В pcap SRv6 обычно ищут по признаку:

```text
IPv6 Routing Header, Type 4
```

В tcpdump:

```bash
tcpdump -ni eth1 'ip6[40:1] = 4'
```

## 9. Основные SRv6 behavior

| Behavior | Простое объяснение | Где встречается |
|----------|--------------------|-----------------|
| End / `uN` | Обработать SID узла и продолжить forwarding | Сценарий 5-Сценарий 6 |
| End.X / `uA` | Переслать через конкретную adjacency | Сценарий 6, Сценарий 10 |
| End.DT6 | Деинкапсулировать IPv6 и сделать lookup в VRF | Сценарий 11 |
| End.DT4 | Деинкапсулировать IPv4 и сделать lookup в VRF | Сценарий 11 |

Если инженер не может объяснить, какой behavior выполняет узел, он ещё не понимает SRv6-путь,
даже если ping проходит.

## 10. VRF и L3VPN

VRF — отдельная таблица маршрутизации. Она позволяет нескольким клиентам использовать
пересекающиеся адреса и не видеть маршруты друг друга.

В SRv6 L3VPN:

1. PE получает пакет из VRF клиента.
2. BGP VPNv6 говорит, какой удалённый PE и какой service SID использовать.
3. PE инкапсулирует пакет в SRv6.
4. Удалённый PE получает пакет на End.DT6/End.DT4 SID.
5. Удалённый PE деинкапсулирует и делает lookup во VRF.

Сервисный SID в SRv6 похож по роли на VPN label в MPLS L3VPN: он говорит удалённому PE, в какой
сервисный контекст положить пакет после транспорта.

## 11. VPP и альтернативный dataplane

До Сценарий 8 вся лаборатория использует Linux kernel dataplane: маршруты ставятся в kernel FIB, а
пакеты проходят через стандартный сетевой стек Linux. VPP использует другую модель: пакетная
обработка выполняется в userspace через graph nodes, часто вместе с DPDK.

Ключевое отличие:

```text
FRR + Linux:
  routing protocol -> zebra -> netlink -> kernel FIB -> packet forwarding

VPP:
  VPP control/CLI -> VPP FIB -> VPP graph nodes -> packet forwarding
```

Поэтому стандартные Linux-команды могут не показывать фактическое состояние VPP dataplane.
Для VPP используются `vppctl show interface`, `vppctl show hardware`, `vppctl show ip fib`,
`vppctl show ip6 fib`.

Главный trade-off: VPP даёт высокую производительность и управляемый packet-processing graph,
но требует отдельной операционной модели и отдельной диагностики.

## 12. eBPF и наблюдение kernel path

eBPF — механизм безопасного запуска ограниченных программ в kernel context. В лаборатории он
используется только для наблюдения, без изменения пакетов.

Два базовых способа подключиться к kernel:

| Механизм | Что это | Когда удобен |
|----------|---------|--------------|
| kprobe | Динамическая привязка к функции ядра | Быстрый debug, но зависит от версии kernel |
| tracepoint | Стабильная опубликованная точка трассировки | Более переносимое наблюдение |

eBPF не заменяет FRR, `ip route` или tcpdump. Он отвечает на другой вопрос: “какие kernel events
происходили во время прохождения трафика?”.

Типовая иерархия наблюдения:

```text
FRR show commands -> control plane
iproute2          -> kernel state snapshot
tcpdump/pcap      -> packet on interface
bpftrace/eBPF     -> kernel execution path
```

## 13. Как читать лабораторные

Для каждого сценария держите один и тот же шаблон мышления:

```text
Что должно произойти в control plane?
Где это видно в FRR?
Что должно попасть в kernel?
Где это видно через iproute2?
Какой пакет должен пройти?
Где это видно через ping/traceroute/tcpdump?
```

Такой подход важнее запоминания команд. Команды меняются между FRR/Linux-версиями, а связь
между control plane, kernel FIB и packet capture остаётся основной моделью диагностики.
