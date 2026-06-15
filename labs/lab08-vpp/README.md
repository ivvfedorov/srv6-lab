# ЛР8: VPP + DPDK intro

**Неделя 4** | Время: ~3 ч

## Цель

Понять отличие VPP dataplane от kernel+FRR; поработать с `vppctl`.

## Теория (кратко)

| | Kernel stack | VPP + DPDK |
|---|--------------|------------|
| Обработка | interrupt-driven | polling, batch |
| Throughput | умеренный | высокий (Mpps) |
| iptables/nft | да | нет на fast path |
| Типичное use | general purpose | NFV, telco, PE router |

## Развёртывание отдельной лабы

```bash
cd /home/ivvfedorov/srv6-lab
containerlab deploy -t srv6-vpp.yml
containerlab inspect -t srv6-vpp.yml
```

Топология: `vpp1` ←eth1→ `host1` (10.0.0.0/24)

## Задания

### 1. VPP CLI

```bash
docker exec -it clab-srv6-vpp-vpp1 vppctl show version
docker exec clab-srv6-vpp-vpp1 vppctl show interface
docker exec clab-srv6-vpp-vpp1 vppctl show hardware
docker exec clab-srv6-vpp-vpp1 vppctl show plugins
```

### 2. Host-interface

VPP-образ создаёт `host-eth1` для порта eth1:

```bash
docker exec clab-srv6-vpp-vpp1 vppctl show interface addr
docker exec clab-srv6-vpp-vpp1 vppctl show int host-eth1
```

Настройте L3 на VPP (пример):

```bash
docker exec clab-srv6-vpp-vpp1 vppctl set int ip address host-eth1 10.0.0.1/24
docker exec clab-srv6-vpp-vpp1 vppctl set int state host-eth1 up
```

### 3. Ping через VPP

```bash
docker exec clab-srv6-vpp-host1 ping -c 3 10.0.0.1
```

Если не работает — проверьте `show ip6 fib` / `show ip fib` и включите ip table.

### 4. Сравнение с FRR (основная srv6 lab)

На `clab-srv6-r1`:

```bash
docker exec clab-srv6-r1 vtysh -c "show version"
docker exec clab-srv6-r1 ps aux | grep zebra
```

Запишите: control plane (FRR) vs dataplane (VPP graph nodes).

### 5. Очистка

```bash
containerlab destroy -t srv6-vpp.yml
```

## Expected output

```
vpp# show version
vpp vXX.XX ...

vpp# show interface
              Name               Idx    State  MTU (L3/IP4/IP6/MPLS)     Counter
host-eth1                         1      up          9000/0/0/0
```

## Критерий успеха

- [ ] Объяснить, зачем DPDK «обходит» kernel
- [ ] Показать `show interface` и `show hardware`
- [ ] Назвать trade-off: скорость vs стандартный Linux tooling

## DPDK (доп. чтение)

- Hugepages: `grep Huge /proc/meminfo` на хосте
- [DPDK programmer's guide](https://doc.dpdk.org/guides/prog_guide/)
