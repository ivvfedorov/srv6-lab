# Исследование Data Plane через PCAP

**lab02** | ~1.5 ч

## Предусловия

```bash
make deploy
for n in r1 r2 r3; do
  docker exec clab-srv6-$n apk add --no-cache tcpdump
done
```

## Задача 1. L3-адреса на transit-узле

Утверждение: маршрутизатор при hop-by-hop forwarding не меняет IPv6 Source и Destination.
Докажите или опровергните захватом.

**Захват** — tcpdump на выходном интерфейсе r2, пинг от r1 до loopback r3:

```bash
# Терминал 1
docker exec clab-srv6-r2 tcpdump -ni eth2 icmp6

# Терминал 2
docker exec clab-srv6-r1 ping6 -c 3 2001:db8:23::3
```

Ожидаемый результат:

```
IP6 2001:db8:12::1 > 2001:db8:23::3: ICMP6, echo request …
IP6 2001:db8:23::3 > 2001:db8:12::1: ICMP6, echo reply …
```

**Вывод**: Source = `2001:db8:12::1` (адрес r1, не r2). Destination = `2001:db8:23::3` (loopback r3).
Маршрутизатор перезаписал MAC, но не тронул L3 — транзит прозрачен для IP.

## Задача 2. L2-заголовки на разных интерфейсах r2

Возьмите дампы на обоих data-интерфейсах r2 **одновременно**, пока идёт ping r1→r3.

Сохраните в pcap:

```bash
docker exec clab-srv6-r2 tcpdump -ni eth1 -w /tmp/eth1.pcap icmp6 &
docker exec clab-srv6-r2 tcpdump -ni eth2 -w /tmp/eth2.pcap icmp6 &
docker exec clab-srv6-r1 ping6 -c 3 2001:db8:23::3
wait
docker cp clab-srv6-r2:/tmp/eth1.pcap ~/eth1.pcap
docker cp clab-srv6-r2:/tmp/eth2.pcap ~/eth2.pcap
```

Сравните Ethernet-заголовки одного и того же ICMPv6 Echo Request на входе (eth1) и выходе (eth2) r2.

| Поле      | eth1 (вход r2)  | eth2 (выход r2) |
|-----------|-----------------|------------------|
| Src MAC   | MAC r1          | MAC r2           |
| Dst MAC   | MAC r2          | MAC r3           |
| Src IPv6  | 2001:db8:12::1  | 2001:db8:12::1   |
| Dst IPv6  | 2001:db8:23::3  | 2001:db8:23::3   |

MAC-адреса разные, потому что каждый L2-сегмент (r1–r2 и r2–r3) — независимый Ethernet-домен.
Маршрутизатор обязан перезаписать Src MAC на свой и Dst MAC на next-hop.

## Задача 3. Hop Limit на транзите

Возьмите захват на r2 eth1 (вход) и eth2 (выход) для одного и того же Echo Request.
Сравните значение **Hop Limit** в IPv6-заголовке.

```bash
# Быстрый захват без pcap — сравнить прямо в терминале
docker exec clab-srv6-r2 tcpdump -ni eth1 -c 1 -v icmp6 &
docker exec clab-srv6-r2 tcpdump -ni eth2 -c 1 -v icmp6 &
docker exec clab-srv6-r1 ping6 -c 1 2001:db8:23::3
```

Флаг `-v` включает подробный вывод. Найдите строку `hlim 64` на eth1 и `hlim 63` на eth2.

Если Hop Limit стал 0 — в сети петля. Если уменьшился на >1 — transit-узел делает что-то
нестандартное. Штатное поведение: −1 за каждый hop.

## Справка: фильтры Wireshark

| Фильтр                   | Что показывает                             |
|--------------------------|--------------------------------------------|
| `icmpv6`                 | Только ICMPv6 (Echo, ND, Error)            |
| `icmpv6.type == 128`     | Echo Request                               |
| `icmpv6.type == 129`     | Echo Reply                                 |
| `ipv6.src == 2001:db8:12::1` | Пакеты от r1                           |
| `eth.src == aa:bb:cc:…`  | Кадры с конкретным MAC-отправителем        |
| `eth.dst == aa:bb:cc:…`  | Кадры с конкретным MAC-получателем         |
| `isis`                   | IS-IS PDU (Hello, LSP, SNP)                |

## Инженерная памятка: что означает каждый симптом в дампе

| Симптом                                  | Диагноз                             |
|------------------------------------------|-------------------------------------|
| Dst MAC не совпадает с ожидаемым next-hop | L2-проблема: ARP/ND не отработал, не тот интерфейс |
| Hop Limit = 0 в пришедшем пакете         | Петля маршрутизации                 |
| Destination IP не соответствует задуманному | Ошибка в RIB/FIB или FIB не синхронизирован с RIB |
| Пакет есть на eth1, нет на eth2 r2      | FIB r2 не содержит маршрута к destination — пакет дропнут |
| Пакет есть на data-интерфейсе, нет в tcpdump на eth0 | Норма: mgmt-сеть изолирована от data |
| IS-IS Hello есть, icmp6 нет              | Control plane жив, data plane сломан (например, ip6tables) |
| Только Echo Request, нет Reply           | Обратный маршрут отсутствует или фильтр на обратном пути |
