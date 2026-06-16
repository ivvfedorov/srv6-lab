# Quickstart: SRv6 Lab

Команды ниже выполняются из корня репозитория.

```bash
pwd
# .../srv6-lab
```

## Минимальный запуск

```bash
make deploy
make verify
```

Эквивалент без `make`:

```bash
containerlab deploy -t srv6.yml
containerlab exec -t srv6.yml --cmd "hostname; ip -6 -br addr; vtysh -c 'show isis neighbor'"
```

## Топология

```
r1 (mgmt: Containerlab-назначен) --- r2 (mgmt: Containerlab-назначен) --- r3 (mgmt: Containerlab-назначен)
     eth1                  eth1 / eth2              eth1
 2001:db8:12::/64      2001:db8:12::/64         2001:db8:23::/64
                       2001:db8:23::/64
```

| Узел | Контейнер | Mgmt IPv4 | Data IPv6 |
|------|-----------|-----------|-----------|
| r1 | `clab-srv6-r1` | назначается Containerlab | `2001:db8:12::1/64`, lo `2001:db8:1::1/128` |
| r2 | `clab-srv6-r2` | назначается Containerlab | `2001:db8:12::2/64`, `2001:db8:23::2/64`, lo `2001:db8:2::2/128` |
| r3 | `clab-srv6-r3` | назначается Containerlab | `2001:db8:23::3/64`, lo `2001:db8:3::3/128` |

Узнать реальный mgmt IP: `containerlab inspect -t srv6.yml` или `make status`.

## Развёртывание

```bash
# Первый запуск или после изменения srv6.yml
make deploy

# Статус
make status

# Удалить лабу (контейнеры и veth)
make clean
```

После `deploy` FRR читает базовые конфиги из `configs/r*/frr.conf` (bind-mount). Это режим
для ЛР1-ЛР4: IPv6 forwarding и IS-IS есть, SRv6 ещё не включён.
FRR-образ закреплён в topology-файлах как `frrouting/frr:v8.4.0`, чтобы лабораторные не зависели
от изменений Docker-тега `latest`.

Для SRv6-лабораторных используется отдельный topology-файл с тем же именем стенда:

```bash
make srv6
```

Он пересоздаёт контейнеры `clab-srv6-r1..r3`, но монтирует `configs/srv6/r*/frr.conf`.
Так базовый и SRv6-режимы не перезаписывают друг друга в репозитории.

Для BGP SRv6 L3VPN используется третий режим:

```bash
make vpn
```

Он использует `srv6-vpn.yml`, создаёт Linux VRF `TENANT_A` с dummy-интерфейсом `tenant-a`,
включает `bgpd=yes` и монтирует `configs/srv6/r*/frr-vpn.conf`.

## Доступ к узлам

```bash
# Shell в узле
docker exec -it clab-srv6-r1 bash

# FRR CLI
docker exec -it clab-srv6-r1 vtysh

# Команда на всех узлах
containerlab exec -t srv6.yml --cmd "hostname; ip -6 -br addr"
```

## Веб-интерфейсы

### Граф топологии (HTTP)

```bash
make graph
```

Откройте в браузере: `http://<IP_хоста>:50080`

Статические форматы (без сервера):

```bash
containerlab graph -t srv6.yml --mermaid   # clab-srv6/graph/srv6.mermaid
containerlab graph -t srv6.yml --dot        # Graphviz
containerlab graph -t srv6.yml --drawio     # diagrams.net
```

### Web-терминалы (GoTTY)

```bash
containerlab tools gotty attach -t srv6.yml
containerlab tools gotty list
```

## Захват трафика

tcpdump в образе FRR не установлен по умолчанию:

```bash
for n in r1 r2 r3; do
  docker exec clab-srv6-$n bash -c \
    "apt-get update -qq && apt-get install -y -qq tcpdump"
done
```

Пример захвата ICMPv6 на transit-узле r2:

```bash
# Терминал 1 — захват
docker exec clab-srv6-r2 tcpdump -ni eth2 -w /tmp/lab.pcap ip6

# Терминал 2 — трафик
docker exec clab-srv6-r1 ping6 -c 3 2001:db8:23::3

# Скопировать pcap на хост
docker cp clab-srv6-r2:/tmp/lab.pcap ~/lab.pcap
```

## SRv6 reference config

Эталонные конфиги SRv6 для ЛР5-ЛР7 и ЛР10: `configs/srv6/r*/frr.conf`.
Для ЛР11 используются VPN-конфиги `configs/srv6/r*/frr-vpn.conf`.

Переключить стенд в SRv6-режим:

```bash
make srv6
```

Вернуться к базовому режиму без SRv6:

```bash
make redeploy
```

## Программа обучения

| Блок | Тема | Лабораторные |
|------|------|--------------|
| 1 | Unix/Linux, Containerlab | [lab01](../labs/lab01-inspect/), [lab02](../labs/lab02-pcap/) |
| 2 | FRR, netlink | [lab03](../labs/lab03-frr-zebra/), [lab04](../labs/lab04-netlink/) |
| 3 | SRv6 | [lab05](../labs/lab05-srv6-basic/), [lab06](../labs/lab06-srv6-behaviors/), [lab07](../labs/lab07-srv6-troubleshoot/) |
| 4 | VPP, DPDK, eBPF | [lab08](../labs/lab08-vpp/), [lab09](../labs/lab09-ebpf/) |
| 5 | Advanced SRv6 | [lab10](../labs/lab10-srv6-policy/), [lab11](../labs/lab11-srv6-vpn/) |

Перед ЛР1-ЛР4 прочитайте [theory-foundations.md](theory-foundations.md) до раздела 6.
Перед ЛР5-ЛР11 дополнительно прочитайте разделы 7-10.

Подробнее: [cheatsheet.md](cheatsheet.md), [lab-format.md](lab-format.md)
