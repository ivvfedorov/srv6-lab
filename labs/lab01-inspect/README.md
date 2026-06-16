# ЛР1: Знакомство с лабораторией

**Неделя 1** | Время: ~2 ч

## Цель

Научиться управлять лабой Containerlab, различать mgmt- и data-сеть, находить veth на хосте.

## Теория

Containerlab создаёт контейнеры, veth-пары и management bridge. Management-сеть нужна для
доступа к контейнерам с хоста (`eth0`, IPv4 из `172.20.20.0/24`), а data-сеть моделирует
реальные линковые интерфейсы маршрутизаторов (`eth1`, `eth2`, IPv6 из `2001:db8:*::/64`).

FRR работает внутри контейнера как набор процессов: `zebra` устанавливает маршруты в kernel,
`isisd` строит IGP-соседства, `watchfrr` следит за демонами. Поэтому базовая диагностика
лаборатории всегда начинается с трёх уровней: контейнеры Containerlab, интерфейсы Linux,
процессы/состояние FRR.

## Предусловия

```bash
make deploy
```

## Задания

### 1. Статус лаборатории

```bash
containerlab inspect -t srv6.yml
containerlab inspect interfaces -t srv6.yml
```

Запишите mgmt IPv4 каждого узла.

### 2. Граф топологии

```bash
containerlab graph -t srv6.yml --mermaid
cat clab-srv6/graph/srv6.mermaid
```

Опционально запустите HTTP-сервер:

```bash
containerlab graph -t srv6.yml --srv 0.0.0.0:50080
```

### 3. Обход узлов

На каждом r1, r2, r3:

```bash
docker exec -it clab-srv6-r1 bash
ip link
ip -6 addr
ip -6 route
ps aux | grep frr
```

### 4. veth на хосте

```bash
ip link | grep -E 'veth|clab'
brctl show 2>/dev/null || ip link show type bridge
```

Найдите bridge mgmt-сети `br-*` (172.20.20.0/24).

### 5. Traceroute r1 → r3

```bash
docker exec clab-srv6-r1 traceroute6 -n 2001:db8:23::3
```

## Expected output

```
traceroute to 2001:db8:23::3, 30 hops max
 1  2001:db8:12::2  ...    # r2
 2  2001:db8:23::3  ...    # r3
```

IS-IS соседи на r1:

```bash
docker exec clab-srv6-r1 vtysh -c "show isis neighbor"
# State: Up, Interface: eth1
```

## Критерий успеха

- [ ] Объяснить разницу `172.20.20.0/24` (mgmt) и `2001:db8:x::/64` (data)
- [ ] Нарисовать топологию r1—r2—r3 с адресами
- [ ] Показать, что FRR запущен (`watchfrr`, `zebra`, `isisd`)
