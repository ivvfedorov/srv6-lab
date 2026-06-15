# ЛР4: Netlink hands-on

**Неделя 2** | Время: ~2 ч

## Цель

Понять, что `ip route` и FRR zebra используют netlink (RTNETLINK).

## Задания

### 1. Мониторинг netlink

Терминал 1:

```bash
docker exec -it clab-srv6-r1 ip monitor route
```

Терминал 2:

```bash
docker exec clab-srv6-r1 ip -6 route add 2001:db8:77::/64 dev eth1
docker exec clab-srv6-r1 ip -6 route del 2001:db8:77::/64 dev eth1
```

Зафиксируйте события `RTM_NEWROUTE` / `RTM_DELROUTE`.

### 2. strace

```bash
docker exec clab-srv6-r1 bash -c \
  "apt-get update -qq && apt-get install -y -qq strace"
docker exec clab-srv6-r1 strace -e socket,sendmsg,recvmsg \
  ip -6 route add 2001:db8:66::/64 dev eth1 2>&1 | head -40
docker exec clab-srv6-r1 ip -6 route del 2001:db8:66::/64 dev eth1
```

Найдите `socket(AF_NETLINK, ...)` и `sendmsg`.

### 3. Python pyroute2

На хосте (или в контейнере с `pip install pyroute2`):

```bash
pip install pyroute2 --user
docker cp labs/lab04-netlink/netlink_add_route.py clab-srv6-r1:/tmp/
docker exec clab-srv6-r1 bash -c "pip install pyroute2 && python3 /tmp/netlink_add_route.py"
docker exec clab-srv6-r1 ip -6 route show 2001:db8:88::/64
```

### 4. Конфликт FRR vs kernel

Добавьте маршрут через `ip` и через `vtysh`. Сравните `show ipv6 route` — кто владеет записью?

## Expected output

```
[ROUTE]2001:db8:77::/64 dev eth1 proto static metric 1024 pref medium
```

```
socket(AF_NETLINK, SOCK_RAW|SOCK_CLOEXEC, NETLINK_ROUTE) = 3
sendmsg(3, {msg_name=..., msg_iov=[{iov_base=[{nlmsg_len=..., nlmsg_type=RTM_NEWROUTE...
```

## Критерий успеха

- [ ] Объяснить, что netlink — это IPC с ядром, не сокет TCP/UDP
- [ ] Показать событие в `ip monitor route`
- [ ] Добавить маршрут через pyroute2
