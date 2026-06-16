# ЛР2: Захват и разбор пакетов

**Неделя 1** | Время: ~2 ч

## Цель

Установить tcpdump, захватить ICMPv6, разобрать Ethernet/IPv6/ICMPv6 в Wireshark.

После выполнения студент должен уметь доказать путь пакета не только через `ping`, но и через
пакетный захват на конкретном интерфейсе.

## Что нужно знать заранее

- Ethernet-кадр доставляется только в пределах одного L2-сегмента.
- IPv6-пакет может пройти через несколько маршрутизаторов, сохраняя конечный destination.
- ICMPv6 Echo Request/Echo Reply используется командой `ping6`.
- `tcpdump` видит пакеты на выбранном интерфейсе, а не “во всей сети сразу”.

Рекомендуемое чтение: [../../docs/theory-foundations.md](../../docs/theory-foundations.md),
разделы 2-3.

## Теория

FRR говорит “всё ок”, ping идёт — но где доказательство, что пакет действительно
прошёл через r2, а не ушёл коротким путём по management-сети? Единственный судья — tcpdump:
он показывает пакет таким, каким его реально видит интерфейс.

Разбирать пакет проще по схеме “конверт, адрес, письмо”:
- **Ethernet-кадр** (конверт) — показывает соседей на конкретном линке. MAC-адреса
  принадлежат r1 и r2, а не конечным отправителю и получателю.
- **IPv6-заголовок** (адрес на конверте) — показывает сквозной путь r1→r3.
  Source и Destination НЕ меняются на transit-узлах.
- **ICMPv6** (само письмо) — полезная нагрузка: Echo Request (Type 128) или Reply (Type 129).

```text
[Ethernet: Src=r1_MAC Dst=r2_MAC] [IPv6: Src=r1 Dst=r3] [ICMPv6: Echo Request]
```

Если захват сделан не на том интерфейсе — вы видите только management-трафик (eth0),
а data-сеть остаётся невидимой. Самая частая ошибка: `tcpdump -ni eth0` на r2 при
ping r1→r3 — пакет идёт через eth1/eth2, а на eth0 его просто нет.

| Уровень | Что смотреть | Почему важно |
|---------|--------------|--------------|
| Ethernet | Src/Dst MAC, EtherType `0x86dd` | Показывает соседей на конкретном линке |
| IPv6 | Source, Destination, Hop Limit, Next Header | Показывает L3-путь и уменьшение Hop Limit |
| ICMPv6 | Type 128/129, identifier, sequence | Показывает Echo Request или Echo Reply |

## Задания

### 1. Установка tcpdump

```bash
for n in r1 r2 r3; do
  docker exec clab-srv6-$n bash -c \
    "apt-get update -qq && apt-get install -y -qq tcpdump"
done
```

Пояснение: базовый FRR-образ минимальный, поэтому инструменты анализа пакетов часто ставятся
отдельно. Это нормальная практика для лабораторной среды, но в production-среде установка
пакетов на сетевые узлы обычно контролируется отдельно.

### 2. Захват на r1 (линк r1—r2)

Терминал 1:

```bash
docker exec clab-srv6-r1 tcpdump -ni eth1 -w /tmp/lab02.pcap icmp6
```

Терминал 2:

```bash
docker exec clab-srv6-r1 ping6 -c 5 2001:db8:12::2
```

Остановите tcpdump (Ctrl+C), скопируйте файл:

```bash
docker cp clab-srv6-r1:/tmp/lab02.pcap ~/lab02.pcap
```

### 3. Разбор в Wireshark

Откройте `lab02.pcap`. Запишите для одного Echo Request:

| Поле | Значение |
|------|----------|
| Src MAC | |
| Dst MAC | |
| Src IPv6 | |
| Dst IPv6 | |
| Hop Limit | |
| ICMP Type | 128 (Echo Request) |

Дополнительно запишите:

| Поле | Вопрос |
|------|--------|
| Ethernet Type | Почему это IPv6? |
| Next Header | Почему это ICMPv6? |
| ICMP Code | Почему он равен 0 для Echo Request? |
| Frame length | Сколько байт занимает пакет на линке? |

### 4. Transit capture

Повторите захват на r2 eth2 при ping r1 → r3:

```bash
docker exec clab-srv6-r2 tcpdump -ni eth2 -c 10 icmp6 &
docker exec clab-srv6-r1 ping6 -c 3 2001:db8:23::3
```

## Expected output

```
$ docker exec clab-srv6-r1 ping6 -c 3 2001:db8:12::2
PING 2001:db8:12::2(...): 56 data bytes
64 bytes from 2001:db8:12::2: icmp_seq=1 ttl=64 time=0.xxx ms
...
3 packets transmitted, 3 received, 0% packet loss
```

## Критерий успеха

- [ ] pcap содержит ICMPv6 Echo Request и Echo Reply
- [ ] Объяснить, почему на r2 виден transit-трафик r1↔r3
- [ ] Указать разницу между eth0 (mgmt) и eth1/eth2 (data)

## Контрольные вопросы

1. Почему MAC-адреса меняются от линка к линку, а IPv6 destination остаётся конечным?
2. Что произойдёт с Hop Limit при прохождении r2?
3. Почему tcpdump на `eth0` не подходит для доказательства работы data-сети?
4. Чем ICMPv6 Echo Request отличается от Echo Reply в поле Type?

## Требования к отчёту

- Скриншот или текстовая таблица полей одного Echo Request из Wireshark.
- Объяснение, почему выбран именно интерфейс захвата.
- Сравнение локального захвата r1-r2 и transit-захвата r1-r3 через r2.
