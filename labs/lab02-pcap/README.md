# Захват трафика: tcpdump

**lab02** | ~30 мин

## Способ 1. Изнутри контейнера (проще)

```bash
# Поставить tcpdump (образ на Alpine — apk, не apt)
for n in r1 r2 r3; do
  docker exec clab-srv6-$n apk add --no-cache tcpdump
done

# ICMPv6 на линке r1→r2
docker exec clab-srv6-r1 tcpdump -ni eth1 icmp6
```

## Способ 2. С хоста (без установки в контейнеры)

Containerlab создаёт veth-пары: один конец в контейнере (`eth1`/`eth2`), второй на хосте.
`containerlab inspect interfaces` показывает **Index** каждого интерфейса.
На хосте `ip link` показывает `vethXXX@ifN`, где `N` — индекс peer-интерфейса.

**Как найти хостовый veth нужного линка:**

```bash
# Шаг 1 — смотрим индексы интерфейсов
containerlab inspect interfaces -t srv6.yml
# Пример: r1 eth1 → Index 56, r2 eth2 → Index 53

# Шаг 2 — ищем veth с соответствующим @ifN
ip -o link | grep veth | grep '@if56'
# Покажет: 57: vethXXXXXXXX@if56: ...
# Это veth, чей peer — r1 eth1 (Index 56)

# Шаг 3 — захват
tcpdump -ni vethXXXXXXXX icmp6
```

**mgmt-интерфейсы** (eth0) всегда имеют Index 2 и все на бридже `br-*` — их не используйте,
это management-сеть.

## Полезные команды

```bash
# С MAC-адресами (-e), 10 пакетов (-c 10), без DNS (-n)
tcpdump -ni eth1 -e -n -c 10 icmp6

# Сохранить в pcap для Wireshark
tcpdump -ni eth1 -n -w /tmp/link.pcap

# Транзит: захват на r2 eth2 при ping r1→r3
docker exec clab-srv6-r2 tcpdump -ni eth2 icmp6 &
docker exec clab-srv6-r1 ping6 -c 3 2001:db8:23::3

# IS-IS Hello (протокол 124)
tcpdump -ni eth1 proto 124

# Только Echo Request (Type 128, байт 40 IPv6-заголовка)
tcpdump -ni eth1 'icmp6 and ip6[40] == 128'
```

## Что видно в дампе

| Трафик              | Фильтр      | Признак                 |
|---------------------|-------------|-------------------------|
| ICMPv6 Echo Request | `icmp6`     | `echo request`          |
| ICMPv6 Echo Reply   | `icmp6`     | `echo reply`            |
| IS-IS Hello         | `proto 124` | dst `ff02::5`           |
| IS-IS LSP           | `proto 124` | большой пакет (>1000B)  |
| IPv6 ND             | `icmp6`     | type 135 (NS), 136 (NA) |
