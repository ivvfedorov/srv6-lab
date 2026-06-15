# ЛР6: SRv6 behaviors

**Неделя 3** | Время: ~2.5 ч

## Цель

Различать End (uN), End.X (uA), понять decapsulation End.DT6; составить таблицу SID.

## Предусловия

SRv6 применён (ЛР5, `apply-srv6.sh`).

## Задания

### 1. Инвентаризация SID

На каждом узле:

```bash
docker exec clab-srv6-r1 vtysh -c "show segment-routing srv6 sid"
docker exec clab-srv6-r2 vtysh -c "show segment-routing srv6 sid"
docker exec clab-srv6-r3 vtysh -c "show segment-routing srv6 sid"
```

Заполните таблицу:

| Node | SID | Behavior | Context |
|------|-----|----------|---------|
| r1 | | uN | |
| r1 | | uA | eth1 |
| r2 | | uN | |
| ... | | | |

### 2. End vs End.X

- **uN (End)**: SID узла, pop и forward по inner destination
- **uA (End.X)**: cross-connect на конкретный interface/adjacency

Найдите uA SID на r2 для eth1 (к r1) и eth2 (к r3).

### 3. Traceroute по locator

```bash
docker exec clab-srv6-r1 traceroute6 -n 2001:db8:2::2
docker exec clab-srv6-r1 traceroute6 -n 2001:db8:3::3
```

### 4. Поломка SID (failure injection)

На r2 временно выключите IS-IS на eth2:

```
configure terminal
 interface eth2
  no ipv6 router isis CORE
 exit
exit
```

Проверьте ping r1→r3 и `show isis neighbor`. Восстановите конфиг:

```
 interface eth2
  ipv6 router isis CORE
 exit
```

### 5. End.DT6 (обзор)

Прочитайте [RFC 8754 — End.DT6](https://datatracker.ietf.org/doc/html/rfc8754). В FRR static behavior:

```
segment-routing
 srv6
  locators
   locator LOC3
    prefix 2001:db8:3::/64
   exit
  exit
  static-sids
   sid 2001:db8:3:fe::/128 locator LOC3 behavior uDT6
  exit
 exit
```

Применение optional — зафиксируйте в `show segment-routing srv6 sid` новую запись.

## Expected output

```
r2# show segment-routing srv6 sid
SID                   Behavior    Context
--------------------  ----------  -----------------
2001:db8:2::          uN          isis(0)
2001:db8:2:e000::     uA          interface eth1
2001:db8:2:e001::     uA          interface eth2
```

## Критерий успеха

- [ ] Таблица SID→behavior→контекст для всех узлов
- [ ] Объяснить разницу uN и uA на примере r2
- [ ] Описать, что произошло при отключении IS-IS на eth2
