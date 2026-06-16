# ЛР8: VPP + DPDK intro

**Неделя 4** | Время: ~3 ч

## Цель

Понять отличие VPP dataplane от kernel+FRR; поработать с `vppctl`.

После выполнения студент должен уметь объяснить, почему VPP требует других команд диагностики
и почему высокая производительность dataplane достигается ценой отказа от части привычного
Linux tooling.

## Что нужно знать заранее

- В ЛР1-ЛР7 dataplane был Linux kernel.
- FRR является control plane и может использовать разные dataplane-подходы.
- DPDK/VPP чаще встречаются в NFV, telco edge и high-throughput packet processing.

Рекомендуемое чтение: [../../docs/theory-foundations.md](../../docs/theory-foundations.md),
разделы 2 и 11.

## Теория

Linux-роутер на ядре обрабатывает ~1 Mpps. Ваш оператор требует 10 Mpps. Как это
возможно без замены железа? Ответ — VPP + DPDK: перенос обработки пакетов из
interrupt-driven kernel в userspace, где пакеты обрабатываются батчами в режиме
polling.

Linux kernel обрабатывает пакеты через программные прерывания (interrupt-driven) —
каждый пакет вызывает переключение контекста. Это универсально, но ограничивает
throughput. VPP + DPDK переносит сетевой стек в userspace и работает по модели
polling — это программный аналог того, как пакеты обрабатываются в pipeline
аппаратного ASIC: непрерывный поток, обработка батчами, без переключения контекста.

Главная ловушка: привычные `tcpdump`, `iptables`, `ip route` не работают на VPP
fast path. Плата за производительность — kernel-инструменты не видят пакеты,
потому что пакет даже не заходит в kernel networking stack. Диагностика требует
новых инструментов: `vppctl`. Без этого знания VPP выглядит как «чёрный ящик,
который непонятно как работает».

| | Kernel stack | VPP + DPDK |
|---|--------------|------------|
| Обработка | interrupt-driven | polling, batch |
| Throughput | умеренный | высокий (Mpps) |
| iptables/nft | да | нет на fast path |
| Типичное use | general purpose | NFV, telco, PE router |

| Вопрос | Linux kernel dataplane | VPP dataplane |
|--------|------------------------|---------------|
| Где принимается решение пересылки? | Kernel networking stack | VPP graph nodes |
| Как смотреть интерфейсы? | `ip link`, `ip addr` | `vppctl show interface` |
| Как смотреть FIB? | `ip route` | `vppctl show ip fib`, `show ip6 fib` |
| Как обрабатываются пакеты? | Interrupts, kernel path | Polling, batches |
| Главный плюс | Универсальность и стандартные инструменты | Производительность |
| Главный минус | Ограничение throughput | Отдельная операционная модель |

В этой ЛР не требуется глубоко настраивать DPDK. Цель — увидеть, что dataplane
может быть не Linux kernel, и что это меняет способ диагностики.

## Развёртывание отдельной лабы

```bash
make vpp
make vpp-status
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

Запишите в отчёт, где виден адрес VPP-интерфейса: в Linux `ip addr` или в `vppctl`. Это
проверяет понимание разделения Linux namespace и VPP dataplane.

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

## Контрольные вопросы

1. Почему `ip route` внутри VPP-контейнера может не показать то, что использует VPP?
2. Что означает polling-модель обработки пакетов?
3. Почему VPP подходит для NFV-сценариев, но сложнее для новичка?
4. Какие команды в VPP являются аналогами `ip link` и `ip route`?

## Требования к отчёту

- Таблица сравнения Linux kernel dataplane и VPP dataplane.
- Вывод `vppctl show interface` и `vppctl show hardware`.
- Короткое объяснение, почему диагностика VPP отличается от диагностики FRR+kernel.

## DPDK (доп. чтение)

- Hugepages: `grep Huge /proc/meminfo` на хосте
- [DPDK programmer's guide](https://doc.dpdk.org/guides/prog_guide/)

