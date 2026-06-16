# ЛР3: FRR, zebra и kernel FIB

**Неделя 2** | Время: ~2.5 ч

## Цель

Понять цепочку `isisd → zebra → netlink → kernel FIB`.

## Теория

FRR разделяет control plane и установку маршрутов. `isisd` узнаёт топологию и вычисляет
маршруты IS-IS, но сам не программирует kernel FIB. Он передаёт результат в `zebra`, а `zebra`
через netlink добавляет, изменяет и удаляет маршруты в Linux kernel.

Поэтому один и тот же маршрут нужно уметь проверить в двух местах: `show ipv6 route` показывает
RIB FRR и источник маршрута (`I`, `S`, `C`, `K`), а `ip -6 route show` показывает то, что реально
использует Linux dataplane для пересылки пакетов.

## Задания

### 1. Процессы FRR

```bash
docker exec clab-srv6-r1 ps aux | grep -E 'zebra|isisd|watchfrr|staticd'
```

### 2. Сравнение RIB и FIB

```bash
docker exec clab-srv6-r1 vtysh -c "show ipv6 route"
docker exec clab-srv6-r1 ip -6 route show
docker exec clab-srv6-r1 vtysh -c "show zebra"
```

Найдите маршрут к `2001:db8:3::3/128` (loopback r3). Код `I` = IS-IS.

### 3. IS-IS соседство

```bash
docker exec clab-srv6-r1 vtysh -c "show isis neighbor"
docker exec clab-srv6-r1 vtysh -c "show isis interface"
docker exec clab-srv6-r2 vtysh -c "show isis neighbor"
```

### 4. Статический маршрут через FRR

```bash
docker exec -it clab-srv6-r1 vtysh
```

```
configure terminal
 ipv6 route 2001:db8:99::/64 2001:db8:12::2
exit
write memory
```

Проверка:

```bash
docker exec clab-srv6-r1 vtysh -c "show ipv6 route 2001:db8:99::/64"
docker exec clab-srv6-r1 ip -6 route show 2001:db8:99::/64
```

Удалите тестовый маршрут после проверки:

```
configure terminal
 no ipv6 route 2001:db8:99::/64 2001:db8:12::2
exit
```

### 5. Debug zebra (опционально)

```
configure terminal
 debug zebra kernel
exit
```

Смотрите `/var/log/frr/zebra.log` или `docker logs clab-srv6-r1`. Отключите debug после наблюдения.

## Expected output

```
r1# show isis neighbor
Area CORE:
  System Id      Interface   Lvl  State  Holdtime  SNPA
  0000.0000.0002 eth1        2    Up     xx        xx:xx:xx:xx:xx:xx

r1# show ipv6 route 2001:db8:3::3/128
I>* 2001:db8:3::3/128 [115/20] via 2001:db8:12::2, eth1, weight 1, 00:00:xx
```

## Критерий успеха

- [ ] Нарисовать: `isisd → zebra → netlink → kernel`
- [ ] Объяснить коды K/C/S/I в `show ipv6 route`
- [ ] Показать, что static route появился и в FRR, и в `ip -6 route`
