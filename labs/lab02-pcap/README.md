# ЛР2: Захват и разбор пакетов

**Неделя 1** | Время: ~2 ч

## Цель

Установить tcpdump, захватить ICMPv6, разобрать Ethernet/IPv6/ICMPv6 в Wireshark.

## Теория

Packet capture показывает data plane таким, каким его видит интерфейс Linux. Для ICMPv6 Echo
Request/Echo Reply в pcap нужно различать три уровня: Ethernet-кадр между соседними узлами,
IPv6-заголовок между конечными адресами и ICMPv6-сообщение как полезную нагрузку.

На transit-узле r2 MAC-адреса будут принадлежать соседям на конкретном линке, но IPv6 source
и destination останутся адресами r1 и r3. Это ключевая разница между L2 next-hop forwarding
и L3 end-to-end адресацией.

## Задания

### 1. Установка tcpdump

```bash
for n in r1 r2 r3; do
  docker exec clab-srv6-$n bash -c \
    "apt-get update -qq && apt-get install -y -qq tcpdump"
done
```

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
