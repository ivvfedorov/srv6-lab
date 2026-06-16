# ЛР9: eBPF — мягкий вход в kernel

**Неделя 4** | Время: ~2 ч

## Цель

Наблюдать kernel networking через eBPF/bpftrace без написания LKM.

После выполнения студент должен понимать eBPF как инструмент наблюдения за kernel path, а не
как “магическую” замену tcpdump, strace или FRR-команд.

## Что нужно знать заранее

- Kernel обрабатывает сетевые пакеты через функции и tracepoint'ы.
- `tcpdump` показывает пакет на интерфейсе, но не показывает внутренний путь в kernel.
- `strace` показывает userspace syscall'ы, но не показывает все kernel events.
- eBPF/bpftrace позволяет безопасно подписываться на kernel events.

Рекомендуемое чтение: [../../docs/theory-foundations.md](../../docs/theory-foundations.md),
раздел 12.

## Теория

eBPF позволяет безопасно запускать небольшие программы в kernel context и наблюдать события
без сборки kernel module. `kprobe` цепляется к функции ядра по имени и удобен для быстрых
экспериментов, но зависит от внутренней реализации ядра. `tracepoint` стабильнее как интерфейс
наблюдения, потому что это заранее опубликованная точка трассировки.

В этой ЛР eBPF используется только для observability: мы не меняем пакеты, а считаем события
сетевого стека. Для SRv6 это полезно как следующий уровень после FRR, `ip -6 route` и pcap:
можно увидеть, что пакет действительно проходит через kernel networking path.

Сравнение инструментов наблюдения:

| Инструмент | Что видит | Что не видит |
|------------|-----------|--------------|
| `vtysh` | Control plane FRR | Внутренние kernel-функции |
| `ip -6 route` | Kernel FIB snapshot | Историю прохождения пакета |
| `tcpdump` | Пакеты на интерфейсе | Внутренние kernel-события |
| `strace` | Syscall'ы процесса | Обработку пакетов после syscall |
| `bpftrace` | Kernel functions/tracepoints | Полный pcap без отдельной логики |

В production eBPF часто используют для observability: latency, drops, counts, top talkers,
debug конкретных code path. В этой ЛР мы делаем только безопасный read-only tracing.

## Предусловия

На **хосте** (не в контейнере FRR):

```bash
which bpftrace || sudo apt-get install -y bpftrace
```

## Задания

### 1. kprobe: netif_receive_skb

Пока идёт ping по srv6 lab:

```bash
sudo bpftrace -e 'kprobe:netif_receive_skb /comm == "ping6" || comm == "ping"/ { @[comm] = count(); }'
```

В другом терминале:

```bash
docker exec clab-srv6-r1 ping6 -c 5 2001:db8:23::3
```

Ctrl+C — смотрите счётчики.

Интерпретация: счётчик показывает, что во время генерации трафика kernel вызывал функцию
приёма пакетов. Значение счётчика не обязано равняться количеству ICMP-пакетов один к одному,
потому что kernel path включает служебные события и особенности namespace/bridge.

### 2. Tracepoint: netif_receive_skb (если доступен)

```bash
sudo bpftrace -l 'tracepoint:net:*' | grep -i netif | head
sudo bpftrace -e 'tracepoint:net:netif_receive_skb { @[comm] = count(); }'
```

### 3. Syscall tracing

```bash
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_write /comm == "vtysh"/ { printf("vtysh write: %d bytes\n", args->fd); }'
```

Запустите `docker exec clab-srv6-r1 vtysh -c "show version"`.

### 4. Карта для kernel programming

После eBPF следующие шаги (за пределами 4 недель):

1. Hello-world loadable module (`insmod` / `dmesg`)
2. netlink genl listener
3. Изучение `net/ipv6/seg6*.c` в kernel source

## Expected output

```
@ping6]: 10
```

## Критерий успеха

- [ ] Запустить bpftrace без ошибок
- [ ] Объяснить разницу kprobe и tracepoint
- [ ] Назвать 3 инструмента kernel debug: `dmesg`, `tracepoint`, `bpftrace`

## Контрольные вопросы

1. Почему tracepoint обычно стабильнее kprobe?
2. Чем bpftrace отличается от tcpdump?
3. Почему eBPF-программы проходят verifier перед запуском?
4. Что можно доказать счётчиком `netif_receive_skb`, а что нельзя?

## Требования к отчёту

- Команда bpftrace и вывод счётчиков после генерации ping.
- Краткое сравнение kprobe и tracepoint.
- Объяснение, на каком уровне observability находится eBPF относительно FRR и tcpdump.

## Связь с SRv6

Kernel SRv6 code path: packet → `netif_receive_skb` → IPv6 → seg6 local/encap.

Для глубокого tracing SRv6 понадобятся tracepoints в `net/ipv6/` или BTF-enabled bpftrace.
