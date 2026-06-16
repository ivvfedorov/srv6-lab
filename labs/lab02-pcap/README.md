# Захват трафика: tcpdump

**lab02** | ~30 мин

## Установка и захват

```bash
# Поставить tcpdump (образ Alpine — apk, не apt)
for n in r1 r2 r3; do
  docker exec clab-srv6-$n apk add --no-cache tcpdump
done

# ICMPv6 на линке r1→r2
docker exec clab-srv6-r1 tcpdump -ni eth1 icmp6
```

Захват с хоста бесполезен для data-линков — containerlab соединяет контейнеры напрямую
veth-парами, без выхода в host namespace. То, что видно через `ip link | grep veth`
на хосте — только mgmt (eth0, все на бридже `br-*`), а не data-трафик.

## Полезные команды

```bash
# С MAC-адресами (-e), 10 пакетов (-c 10), без DNS (-n)
docker exec clab-srv6-r1 tcpdump -ni eth1 -e -n -c 10 icmp6

# Сохранить в pcap для Wireshark
docker exec clab-srv6-r1 tcpdump -ni eth1 -n -w /tmp/link.pcap

# Транзит: захват на r2 eth2 при ping r1→r3
docker exec clab-srv6-r2 tcpdump -ni eth2 icmp6 &
docker exec clab-srv6-r1 ping6 -c 3 2001:db8:23::3

# IS-IS Hello (протокол 124)
docker exec clab-srv6-r1 tcpdump -ni eth1 proto 124

# Только Echo Request (Type 128, байт 40 IPv6-заголовка)
docker exec clab-srv6-r1 tcpdump -ni eth1 'icmp6 and ip6[40] == 128'
```

## Что видно в дампе

| Трафик              | Фильтр      | Признак                 |
|---------------------|-------------|-------------------------|
| ICMPv6 Echo Request | `icmp6`     | `echo request`          |
| ICMPv6 Echo Reply   | `icmp6`     | `echo reply`            |
| IS-IS Hello         | `proto 124` | dst `ff02::5`           |
| IS-IS LSP           | `proto 124` | большой пакет (>1000B)  |
| IPv6 ND             | `icmp6`     | type 135 (NS), 136 (NA) |
