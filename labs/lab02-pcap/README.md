# Захват трафика: tcpdump на хосте

**lab02** | ~30 мин

Не нужно ставить tcpdump в контейнеры. Containerlab создаёт veth-пары — один конец
в контейнере (там он `eth1`, `eth2`), второй конец на хосте. Захват на хосте видит всё,
что проходит через линк.

## Как найти veth нужного линка

```bash
# Все veth, созданные containerlab
ip link | grep 'veth.*clab'

# Какой veth соответствует линку r1 eth1 → r2
containerlab inspect interfaces -t srv6.yml
```

`containerlab inspect interfaces` покажет таблицу: узел, интерфейс, второй конец, MAC.
В колонке «Host interface» — имя veth на хосте. Его и подставляйте в tcpdump.

Если лень разбираться — tcpdump на хосте умеет фильтровать по MAC:

```bash
# MAC r1 на eth1 (узнайте через containerlab inspect interfaces)
tcpdump -ni any ether host 02:xx:xx:xx:xx:xx
```

## Основные команды

```bash
# ICMPv6 между r1 и r2
tcpdump -ni vethXXX icmp6

# Всё, что идёт через линк (ICMPv6 + IS-IS Hello + LSP)
tcpdump -ni vethXXX

# С MAC-адресами (-e)
tcpdump -ni vethXXX -e

# Подробный вывод (-v), с MAC (-e), только 5 пакетов (-c 5)
tcpdump -ni vethXXX -e -v -c 5

# Сохранить в pcap для Wireshark, без DNS-резолвинга (-n)
tcpdump -ni vethXXX -n -w /tmp/link.pcap
```

## Фильтры

```bash
tcpdump -ni vethXXX icmp6                           # только ICMPv6
tcpdump -ni vethXXX ip6                             # любой IPv6
tcpdump -ni vethXXX 'icmp6 and ip6[40] == 128'      # только Echo Request
tcpdump -ni vethXXX 'icmp6 and ip6[40] == 129'      # только Echo Reply
tcpdump -ni vethXXX 'host 2001:db8:12::1'           # от/к конкретному адресу
tcpdump -ni vethXXX 'net 2001:db8:12::/64'          # трафик конкретной сети
tcpdump -ni vethXXX proto 124                       # IS-IS (протокол 124)
```

## Что искать в дампе

| Что видно                 | Как искать                       |
|---------------------------|----------------------------------|
| ICMPv6 Echo Request       | `icmp6`, строка `echo request`   |
| ICMPv6 Echo Reply         | `icmp6`, строка `echo reply`     |
| IS-IS Hello               | `proto 124`, dst `ff02::5`       |
| IS-IS LSP                 | `proto 124`, большой пакет       |
| IPv6 ND (Neighbor Discovery)| `icmp6`, type 135/136          |
| Пакет с низким TTL        | `tcpdump -v`, `hlim 1`           |
