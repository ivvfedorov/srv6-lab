# ЛР10: SR Policy — явный путь, Candidate Path, BSID

**Неделя 3+ (advanced)** | Время: ~3 ч

## Цель

Понять и сконструировать SR Policy вручную: явный segment list через ядро Linux,
изучить концепцию Candidate Path и Binding SID, сравнить явный путь с IGP shortest-path.

После выполнения студент должен уметь объяснить, кто выбирает путь в IGP, кто выбирает путь
в SR Policy, и почему статический kernel-encap не является полноценной динамической TE-системой.

## Что нужно знать заранее

- Из ЛР5: locator и SID должны быть доступны через IS-IS.
- Из ЛР6: End/uN и End.X/uA отличаются по смыслу и context.
- Из ЛР7: SRH нужно подтверждать packet capture, а не только успешным ping.
- `ip -6 route ... encap seg6` создаёт статическую dataplane-политику в Linux kernel.

Рекомендуемое чтение: [../../docs/theory-foundations.md](../../docs/theory-foundations.md),
разделы 7-9, и [../../docs/theory-srv6-advanced.md](../../docs/theory-srv6-advanced.md),
раздел 3.

## Теория

IGP shortest-path выбирает путь по топологии и метрикам протокола маршрутизации. SR Policy
переносит выбор пути на headend-узел: он инкапсулирует пакет и задаёт Segment List, через
который пакет должен пройти. В production SR Policy описывается через `(headend, color,
endpoint)`, Candidate Path и Binding SID; в этой ЛР мы воспроизводим механику вручную через
Linux `seg6 mode encap`.

Главная идея для проверки: обычный ping к r3 идёт по маршруту IGP без SRH, а policy-маршрут
создаёт внешний IPv6-заголовок и SRH со списком SID. Поэтому доказательство Policy — это не
только успешный ping, но и захват Routing Header Type 4 в pcap.

Подробнее: [расширенная теория, раздел 3](../../docs/theory-srv6-advanced.md#3-sr-policy-основа-source-routing).

Термины, которые нужно различать:

| Термин | Академическое значение | В этой ЛР |
|--------|------------------------|-----------|
| Headend | Узел, который применяет policy и инкапсулирует пакет | r1 |
| Endpoint | Конечная точка policy | loopback r3 `2001:db8:3::3` |
| Segment List | Упорядоченный список SID | `[r2 End.X, r3 End]` |
| Candidate Path | Вариант пути внутри policy | Эмулируется разными route entries |
| BSID | SID, ссылающийся на policy | Эмулируется policy routing |

Ограничение лабораторной модели: Linux static seg6 encap показывает механику SRH, но не
реализует полноценный SR Policy control plane с preference, liveness detection и автоматическим
переключением. Это важно указать в отчёте.

## Предусловия

SRv6 включён, IS-IS сходится, SID выделены.

```bash
make deploy
make srv6

# Проверка перед началом
docker exec clab-srv6-r1 vtysh -c "show segment-routing srv6 sid"
docker exec clab-srv6-r1 vtysh -c "show isis neighbor"
```

## Задания

### 1. Shortest-path vs Explicit-path: зафиксируйте разницу

**А. IGP shortest path** (обычный ping — без Policy):

```bash
docker exec clab-srv6-r1 traceroute6 -n 2001:db8:3::3
# Ожидаемый результат:
# 1. 2001:db8:12::2  (r2 eth1)
# 2. 2001:db8:23::3  (r3 eth1)
# 3. 2001:db8:3::3   (r3 lo)
```

Запишите hop-by-hop путь: **r1 → r2 → r3**.

**Б. Постройте таблицу доступных SID**:

```bash
docker exec clab-srv6-r1 vtysh -c "show segment-routing srv6 sid"
docker exec clab-srv6-r2 vtysh -c "show segment-routing srv6 sid"
docker exec clab-srv6-r3 vtysh -c "show segment-routing srv6 sid"
```

Заполните (у вас могут быть другие конкретные значения):

| Node | SID | Behavior | Context |
|------|-----|----------|---------|
| r1 | `2001:db8:1::` | uN | isis(0) |
| r1 | `2001:db8:1:e000::` | uA | eth1 (→ r2) |
| r2 | `2001:db8:2::` | uN | isis(0) |
| r2 | `2001:db8:2:e000::` | uA | eth1 (→ r1) |
| r2 | `2001:db8:2:e001::` | uA | eth2 (→ r3) |
| r3 | `2001:db8:3::` | uN | isis(0) |
| r3 | `2001:db8:3:e000::` | uA | eth1 (→ r2) |

### 2. Ручной SR Policy через kernel encap

Создайте на r1 **явный маршрут** (SR Policy) к loopback r3 с segment list'ом `[End.X r2→r3, End r3]`:

```bash
docker exec clab-srv6-r1 ip -6 route add 2001:db8:3::3/128 \
  encap seg6 mode encap \
  segs 2001:db8:2:e001::,2001:db8:3:: \
  dev eth1
```

**Разбор**: `2001:db8:2:e001::` — End.X SID на r2 в сторону r3 (uA, interface eth2).
`2001:db8:3::` — End SID узла r3 (uN).

Проверьте, что маршрут появился:

```bash
docker exec clab-srv6-r1 ip -6 route show 2001:db8:3::3
```

Ожидаемый вывод:

```
2001:db8:3::3 encap seg6 mode encap segs 2 [ 2001:db8:2:e001:: 2001:db8:3:: ] dev eth1 ...
```

### 3. Захват SRH и анализ Segment List

На r2 запустите захват:

```bash
docker exec -d clab-srv6-r2 tcpdump -ni eth1 -c 5 -vv 'ip6[40:1]=4' -w /tmp/policy-srh.pcap
```

На r1 выполните ping через Policy:

```bash
docker exec clab-srv6-r1 ping6 -c 3 2001:db8:3::3
```

Скопируйте pcap на хост и откройте в Wireshark:

```bash
docker cp clab-srv6-r2:/tmp/policy-srh.pcap /tmp/policy-srh.pcap
```

**Вопросы для анализа в Wireshark**:

1. Какой Destination Address в IPv6-заголовке? Почему именно этот?
2. Сколько SID в Segment List внутри SRH?
3. Какой Segments Left? Почему он уменьшается на каждом hop'е?
4. Сравните DA в захвате на r2:eth1 vs r2:eth2 (если захватить на обоих интерфейсах).

**Бонус**: захватите одновременно на r2:eth1 и r2:eth2, сравните DA:

```bash
# Терминал 1: захват на eth1
docker exec clab-srv6-r2 tcpdump -ni eth1 -c 3 'ip6[40:1]=4'
# Терминал 2: захват на eth2
docker exec clab-srv6-r2 tcpdump -ni eth2 -c 3 'ip6[40:1]=4'
# Терминал 3: ping
docker exec clab-srv6-r1 ping6 -c 1 2001:db8:3::3
```

### 4. Candidate Path: добавьте альтернативный путь

Создайте **второй маршрут** — альтернативный SR Policy с другой метрикой (weight).
Используйте таблицу маршрутизации с ECMP (multipath):

```bash
# Удалите предыдущий маршрут
docker exec clab-srv6-r1 ip -6 route del 2001:db8:3::3/128

# Создайте два Candidate Path с весами
docker exec clab-srv6-r1 ip -6 route add 2001:db8:3::3/128 \
  encap seg6 mode encap \
  segs 2001:db8:2:e001::,2001:db8:3:: \
  dev eth1 \
  metric 100

# Второй путь (shorter — меньше SID, но та же метрика = ECMP)
docker exec clab-srv6-r1 ip -6 route append 2001:db8:3::3/128 \
  encap seg6 mode encap \
  segs 2001:db8:3:: \
  dev eth1 \
  metric 100
```

Проверьте multipath:

```bash
docker exec clab-srv6-r1 ip -6 route show 2001:db8:3::3
```

Ожидаемый вывод: **две** записи `nexthop ... weight 1`.

### 5. Binding SID (BSID) — концептуально

BSID позволяет ссылаться на Policy через короткий идентификатор. В нашем случае без полноценной
реализации в FRR, BSID можно эмулировать как статический маршрут на самом узле.

**Идея**: создайте на r1 статический End-подобный маршрут к BSID `2001:db8:1:b001::`,
который форвардит в kernel-encap Policy:

```bash
# Шаг 1: создайте dummy-интерфейс, представляющий BSID
docker exec clab-srv6-r1 ip link add bs1 type dummy
docker exec clab-srv6-r1 ip -6 addr add 2001:db8:1:b001::/128 dev bs1
docker exec clab-srv6-r1 ip link set bs1 up

# Шаг 2: привяжите BSID к Policy (через ip rule + ip route)
docker exec clab-srv6-r1 ip -6 rule add to 2001:db8:1:b001:: lookup 100
docker exec clab-srv6-r1 ip -6 route add 2001:db8:3::3/128 \
  encap seg6 mode encap \
  segs 2001:db8:2:e001::,2001:db8:3:: \
  dev eth1 \
  table 100

# Шаг 3: проверьте — ping на BSID должен приводить к тому же результату
docker exec clab-srv6-r1 ping6 -c 1 2001:db8:1:b001::
# Ожидаем: ping успешен (через policy routing table 100)
```

### 6. Сравнительный анализ

Заполните таблицу:

| Критерий | IGP Shortest Path | SR Policy (kernel encap) |
|----------|------------------|--------------------------|
| Путь r1→r3 | | |
| SRH в пакете? | | |
| Segment Left в SRH | | |
| Кто решает путь? | | |
| Меняется ли при падении линка? | | |
| Где настраивается? | | |

После таблицы напишите 5-7 предложений: в каком случае оператору достаточно IGP shortest path,
а в каком нужна явная SR Policy.

### 7. Очистка

```bash
docker exec clab-srv6-r1 ip -6 route del 2001:db8:3::3/128
docker exec clab-srv6-r1 ip -6 rule del to 2001:db8:1:b001:: lookup 100
docker exec clab-srv6-r1 ip link del bs1 2>/dev/null
```

## Expected output

```
# После шага 2:
$ docker exec clab-srv6-r1 ip -6 route show 2001:db8:3::3
2001:db8:3::3 encap seg6 mode encap segs 2 [ 2001:db8:2:e001:: 2001:db8:3:: ] dev eth1 metric 1024 pref medium

# После шага 3 (ping через Policy):
$ docker exec clab-srv6-r1 ping6 -c 1 2001:db8:3::3
PING 2001:db8:3::3(2001:db8:3::3) 56 data bytes
64 bytes from 2001:db8:3::3: icmp_seq=1 ttl=63 time=0.123 ms

--- 2001:db8:3::3 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss

# После шага 4 (multipath):
$ docker exec clab-srv6-r1 ip -6 route show 2001:db8:3::3
2001:db8:3::3
        nexthop encap seg6 mode encap segs 2 [ 2001:db8:2:e001:: 2001:db8:3:: ] dev eth1 weight 1
        nexthop encap seg6 mode encap segs 1 [ 2001:db8:3:: ] dev eth1 weight 1
```

## Критерий успеха

- [ ] Таблица SID составлена, все uN и uA идентифицированы
- [ ] Manual kernel encap создан, ping через Policy успешен
- [ ] SRH захвачен в Wireshark, Segment List проанализирован (Segments Left меняется)
- [ ] Multipath Policy создан, `ip -6 route show` показывает два nexthop
- [ ] BSID эмулирован через policy routing table
- [ ] Таблица сравнения Shortest Path vs SR Policy заполнена
- [ ] Объяснить, почему при Policy путь не меняется при падении линка
      (подсказка: kernel-encap — статический, нет динамической защиты)

## Контрольные вопросы

1. Почему SR Policy называется source routing?
2. Чем End.X SID удобен для задания явного next-hop?
3. Почему успешный ping через policy нужно дополнять pcap с SRH?
4. Чем лабораторная эмуляция Candidate Path отличается от production SR Policy?
5. Что произойдёт со статическим `encap seg6` маршрутом при отказе r2-r3?

## Требования к отчёту

- Таблица всех SID, использованных в policy, с behavior и context.
- Вывод kernel route с `encap seg6`.
- pcap или tcpdump-вывод, где виден Routing Header Type 4.
- Сравнительная таблица IGP shortest path vs SR Policy.
- Отдельный абзац про ограничения статической реализации.

## Дополнительно: SR Policy в FRR (pathd)

В FRR 8.4+ полноценный SR Policy доступен через демон `pathd` (PCEP-клиент)
или через статическую конфигурацию в `segment-routing`. Для этого требуется:

1. Включить `pathd=yes` в daemons.
2. Сконфигурировать PCE (Path Computation Element) или статический Candidate Path.
3. Использовать `show segment-routing srv6 policy` для верификации.

Это тема для **ЛР12** (SR Policy через pathd/PCEP) при расширении топологии до 5 узлов.

## Ссылки

- [Расширенная теория, раздел 3 — SR Policy](../../docs/theory-srv6-advanced.md#3-sr-policy-основа-source-routing)
- [Cheatsheet (advanced)](../../docs/cheatsheet.md)
- [RFC 9256 — SR Policy Architecture](https://datatracker.ietf.org/doc/html/rfc9256)
- [Linux kernel seg6 encap docs](https://docs.kernel.org/networking/seg6.html)
