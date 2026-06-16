# ЛР4: Netlink hands-on

**Неделя 2** | Время: ~2 ч

## Цель

Понять, что `ip route` и FRR zebra используют netlink (RTNETLINK).

После выполнения студент должен уметь объяснить, почему `ip route`, `pyroute2` и FRR `zebra`
являются разными userspace-клиентами одного kernel API.

## Что нужно знать заранее

- Userspace-программа не меняет таблицу маршрутизации напрямую.
- Linux kernel принимает изменения сетевого состояния через системные вызовы и netlink.
- RTNETLINK — семейство netlink-сообщений для маршрутов, интерфейсов, адресов и соседей.

Рекомендуемое чтение: [../../docs/theory-foundations.md](../../docs/theory-foundations.md),
раздел 6.

## Теория

FRR и `ip route add` меняют маршруты независимо друг от друга. Как ядро понимает, кто что
добавил и кому верить? Ответ — netlink: это единственный телефонный кабель, по которому
userspace-программы (zebra, iproute2, pyroute2) передают команды ядру.

```text
[FRR zebra] --netlink--┐
                        ├--> [kernel FIB]
[ip route add] --netlink-┘
```

Два отправителя, один получатель. Ядро не различает «этот маршрут от FRR, а этот — руками».
Оно просто выполняет команду. Поэтому если вы добавили маршрут через `ip`, он появится в FIB,
но FRR о нём не узнает. При следующей сходимости IS-IS zebra может перезаписать его — и ваш
маршрут исчезнет без предупреждения.

Как вскрыть этот канал:

| Инструмент | Что показывает | Учебный смысл |
|------------|----------------|---------------|
| `ip monitor route` | События изменения маршрутов | Kernel сообщает о NEWROUTE/DELROUTE |
| `strace` | Системные вызовы userspace-процесса | Видно создание netlink socket и `sendmsg` |
| `pyroute2` | Программный доступ к netlink из Python | Можно делать то же, что делает `iproute2` |

`strace` — это прослушка телефонной линии. Он покажет, какие именно сообщения zebra передаёт
ядру, когда IS-IS сходится. Протокол маршрутизации живёт выше — `strace` не знает про IS-IS,
он видит только netlink-сообщения от zebra к kernel.

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

Если вывод `ip monitor route` отличается по форматированию, это нормально. В отчёте важно
показать сам факт появления и удаления маршрута, а также prefix и интерфейс.

### 2. strace

```bash
docker exec clab-srv6-r1 bash -c \
  "apt-get update -qq && apt-get install -y -qq strace"
docker exec clab-srv6-r1 strace -e socket,sendmsg,recvmsg \
  ip -6 route add 2001:db8:66::/64 dev eth1 2>&1 | head -40
docker exec clab-srv6-r1 ip -6 route del 2001:db8:66::/64 dev eth1
```

Найдите `socket(AF_NETLINK, ...)` и `sendmsg`.

Интерпретация:

- `socket(AF_NETLINK, ...)` — процесс открыл канал к kernel netlink.
- `sendmsg(...)` — процесс отправил сообщение с запросом изменить маршрут.
- `recvmsg(...)` — процесс получил ответ kernel об успехе или ошибке.

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

В отчёте отдельно укажите, какой маршрут появился только в kernel, а какой виден в FRR. Это
ключевой эксперимент для понимания различия между RIB и FIB.

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

## Контрольные вопросы

1. Почему netlink нельзя считать протоколом маршрутизации?
2. Чем отличается маршрут, добавленный через `ip`, от маршрута, добавленного через FRR?
3. Почему `pyroute2` может менять маршруты без вызова внешней команды `ip`?
4. Что означает ошибка `RTNETLINK answers: File exists`?

## Требования к отчёту

- Фрагмент `ip monitor route` с добавлением и удалением маршрута.
- Фрагмент `strace`, где видны `AF_NETLINK` и `sendmsg`.
- Вывод `ip -6 route show` после запуска Python-скрипта.
- Объяснение различия между владельцем маршрута в FRR и записью в kernel.
