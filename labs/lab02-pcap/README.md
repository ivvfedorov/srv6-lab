# Сценарий 2: Захват и разбор пакетов

**Неделя 1** | Время: ~2 ч

## Цель

Доказать маршрут пакета через захват — не верить `ping`, а увидеть пакет своими глазами
на конкретном интерфейсе.

## Предусловия

```bash
make deploy
for n in r1 r2 r3; do
  docker exec clab-srv6-$n apk add --no-cache tcpdump
done
```

FRR-образ на Alpine — `apk`, не `apt`.

## Шаги

### 1. Негативный тест: eth0 пустой, а ping идёт

Терминал 1 — захват на mgmt-интерфейсе r1:

```bash
docker exec clab-srv6-r1 tcpdump -ni eth0 icmp6
```

Терминал 2 — ping по data-сети:

```bash
docker exec clab-srv6-r1 ping6 -c 3 2001:db8:12::2
```

**Результат**: ping успешен, tcpdump на eth0 — тишина.

Вывод: пакет пошёл через data-интерфейс (`eth1`), а не через management (`eth0`).
Это главная ловушка — `ping` работает, а где именно — показывает только tcpdump.

### 2. Захват на правильном интерфейсе

Терминал 1:

```bash
docker exec clab-srv6-r1 tcpdump -ni eth1 icmp6
```

Терминал 2:

```bash
docker exec clab-srv6-r1 ping6 -c 3 2001:db8:12::2
```

Ожидаемый вывод tcpdump:

```
10:00:00.100000 IP6 2001:db8:12::1 > 2001:db8:12::2: ICMP6, echo request, seq 1, length 64
10:00:00.100100 IP6 2001:db8:12::2 > 2001:db8:12::1: ICMP6, echo reply, seq 1, length 64
```

Запишите в тетрадь: source IP → destination IP, кто ответил, задержка между запросом
и ответом (из timestamp).

Флаги tcpdump: `-n` (без DNS), `-i eth1` (конкретный интерфейс), `icmp6` (фильтр BPF,
отсекает IS-IS-шум).

### 3. Wireshark (опционально)

Если есть графический клиент — сохраните pcap и откройте локально:

```bash
docker exec clab-srv6-r1 tcpdump -ni eth1 -w /tmp/lab02.pcap icmp6 &
docker exec clab-srv6-r1 ping6 -c 3 2001:db8:12::2
docker cp clab-srv6-r1:/tmp/lab02.pcap ~/lab02.pcap
```

В Wireshark разверните один Echo Request и заполните:

| Поле       | Значение          | Почему          |
|------------|-------------------|-----------------|
| Src MAC    | MAC r1 на eth1    | Отправитель кадра |
| Dst MAC    | MAC r2 на eth1    | Next-hop на этом L2-сегменте |
| EtherType  | `0x86dd`          | IPv6            |
| Src IPv6   | `2001:db8:12::1`  | Неизменен сквозь все хопы |
| Dst IPv6   | `2001:db8:12::2`  | Неизменен сквозь все хопы |
| Hop Limit  | 64                | Уменьшится на r2 |
| Next Hdr   | 58                | ICMPv6          |
| ICMP Type  | 128               | Echo Request    |
| ICMP Code  | 0                 | Для Echo Request всегда 0 |

### 4. Transit-захват: главное доказательство

Захват на r2, на выходном интерфейсе в сторону r3:

```bash
docker exec clab-srv6-r2 tcpdump -ni eth2 icmp6 &
docker exec clab-srv6-r1 ping6 -c 3 2001:db8:23::3
```

Ожидаемый вывод:

```
IP6 2001:db8:12::1 > 2001:db8:23::3: ICMP6, echo request, seq 1, length 64
IP6 2001:db8:23::3 > 2001:db8:12::1: ICMP6, echo reply, seq 1, length 64
```

**Ключевое наблюдение**: source IPv6 — `2001:db8:12::1` (r1), **НЕ** `2001:db8:23::2` (r2).
IPv6-адреса отправителя и получателя не изменились при проходе через r2. Это hop-by-hop
forwarding: маршрутизатор меняет только MAC-адреса (L2), IPv6-заголовок (L3) остаётся
сквозным. Hop Limit при этом уменьшается на 1.

Сравните с шагом 2: на линке r1↔r2 destination был `2001:db8:12::2`, а здесь —
`2001:db8:23::3`. Пакет один и тот же (source не меняется), а линки разные.

### 5. IS-IS-трафик: контрольная плоскость на том же проводе

Уберите фильтр `icmp6` и посмотрите, что ещё идёт по data-интерфейсу:

```bash
docker exec clab-srv6-r1 tcpdump -ni eth1 -c 20
```

Среди прочего увидите:

```
IP6 fe80::... > ff02::5: OSI, IS-IS, length ...
IP6 fe80::... > ff02::5: OSI, IS-IS, length ...
```

Это IS-IS Hello-пакеты. Они ходят по тем же интерфейсам `eth1`/`eth2`, что и данные,
но с link-local-адресов (`fe80::`) на multicast `ff02::5` (all IS-IS routers).

Вывод: data-plane и control-plane делят один физический линк. tcpdump видит и то и другое,
поэтому для ICMPv6-экспериментов нужен фильтр.

## Критерии валидации

- [ ] Шаг 1: объяснить, почему tcpdump на eth0 молчит при работающем ping
- [ ] Шаг 2: назвать source/destination IPv6, задержку, направление (request/reply)
- [ ] Шаг 4: показать, что source IPv6 не изменился при проходе r2
- [ ] Шаг 5: найти IS-IS Hello в выводе tcpdump без фильтра

## Контрольные вопросы

1. Почему tcpdump на `eth0` не видит ICMPv6, хотя ping успешен?
2. MAC-адреса меняются на каждом линке, а IPv6 destination — нет. Почему?
3. Что станет с Hop Limit после прохождения r2?
4. Какой multicast-адрес используют IS-IS Hello и почему он не требует маршрутизации?

## Артефакты диагностики

- Вывод tcpdump из шага 2 (Echo Request + Echo Reply) с комментариями к полям.
- Вывод tcpdump из шага 4 (transit) с объяснением, почему source не изменился.
- Одна строка IS-IS Hello из шага 5 с пометкой link-local адресов.
