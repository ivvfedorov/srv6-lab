# Захват трафика: tcpdump

**lab02** | ~30 мин

## Способ 1. С хоста (рекомендуемый)

Containerlab создаёт veth-пары для каждого data-линка. Один конец — в контейнере (там
это `eth1`/`eth2`), второй — на хосте. Узнайте имя хостового конца:

```bash
containerlab inspect interfaces -t srv6.yml
```

В колонке «Host interface» будет имя veth (например `vethXXXX`). Подставьте в tcpdump:

```bash
tcpdump -ni vethXXXX icmp6
```

Без `icmp6` в вывод попадёт IS-IS-трафик (Hello, LSP) — для ICMPv6-экспериментов фильтр
обязателен.

Обычный `ip link | grep veth` показывает **только mgmt-veth** — они все на бридже
`br-*`. Их не используйте: это `eth0`, management-сеть.

## Способ 2. Изнутри контейнера (если host-интерфейс неудобен)

Поставьте tcpdump (образ на Alpine — `apk`, не `apt`):

```bash
for n in r1 r2 r3; do
  docker exec clab-srv6-$n apk add --no-cache tcpdump
done
```

```bash
# ICMPv6 на линке r1→r2
docker exec clab-srv6-r1 tcpdump -ni eth1 icmp6
```

## Полезные команды

```bash
# С MAC-адресами (-e), 10 пакетов (-c 10), без DNS (-n)
tcpdump -ni eth1 -e -n -c 10

# Сохранить в pcap для Wireshark
tcpdump -ni eth1 -n -w /tmp/link.pcap icmp6

# Транзит: захват на r2 eth2 при ping r1→r3
docker exec clab-srv6-r2 tcpdump -ni eth2 icmp6 &
docker exec clab-srv6-r1 ping6 -c 3 2001:db8:23::3

# IS-IS Hello (протокол 124)
tcpdump -ni eth1 proto 124

# Только Echo Request (Type 128, байт 40 IPv6-заголовка)
tcpdump -ni eth1 'icmp6 and ip6[40] == 128'
```

## Что видно в дампе

| Трафик              | Фильтр               | Признак                 |
|---------------------|----------------------|-------------------------|
| ICMPv6 Echo Request | `icmp6`              | `echo request`          |
| ICMPv6 Echo Reply   | `icmp6`              | `echo reply`            |
| IS-IS Hello         | `proto 124`          | dst `ff02::5`           |
| IS-IS LSP           | `proto 124`          | большой пакет (>1000B)  |
| IPv6 ND             | `icmp6`              | type 135 (NS), 136 (NA) |
