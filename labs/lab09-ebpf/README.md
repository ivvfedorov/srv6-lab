# ЛР9: eBPF — мягкий вход в kernel

**Неделя 4** | Время: ~2 ч

## Цель

Наблюдать kernel networking через eBPF/bpftrace без написания LKM.

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

## Связь с SRv6

Kernel SRv6 code path: packet → `netif_receive_skb` → IPv6 → seg6 local/encap.

Для глубокого tracing SRv6 понадобятся tracepoints в `net/ipv6/` или BTF-enabled bpftrace.
