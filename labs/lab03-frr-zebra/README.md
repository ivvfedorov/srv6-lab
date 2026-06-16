# ЛР3: FRR, zebra и kernel FIB

**Неделя 2** | Время: ~2.5 ч

## Цель

Понять цепочку `isisd → zebra → netlink → kernel FIB`.

После выполнения студент должен уметь показать один маршрут в FRR RIB и тот же маршрут в
Linux kernel FIB, объяснив, какой процесс за что отвечает.

## Что нужно знать заранее

- FRR — userspace routing stack, а не часть Linux kernel.
- IS-IS — протокол control plane, который вычисляет маршруты.
- Kernel FIB — таблица, по которой реально пересылаются пакеты.
- Netlink — канал, через который `zebra` программирует kernel.

Рекомендуемое чтение: [../../docs/theory-foundations.md](../../docs/theory-foundations.md),
разделы 4-6.

## Теория

FRR разделяет control plane и установку маршрутов. `isisd` узнаёт топологию и вычисляет
маршруты IS-IS, но сам не программирует kernel FIB. Он передаёт результат в `zebra`, а `zebra`
через netlink добавляет, изменяет и удаляет маршруты в Linux kernel.

Поэтому один и тот же маршрут нужно уметь проверить в двух местах: `show ipv6 route` показывает
RIB FRR и источник маршрута (`I`, `S`, `C`, `K`), а `ip -6 route show` показывает то, что реально
использует Linux dataplane для пересылки пакетов.

Архитектура этой ЛР:

```text
IS-IS Hello/LSP
      |
      v
isisd строит LSDB и вычисляет shortest path
      |
      v
zebra хранит общую RIB FRR
      |
      v
RTNETLINK
      |
      v
Linux kernel FIB
      |
      v
packet forwarding
```

Коды маршрутов в FRR показывают происхождение записи:

| Код | Источник | Пример интерпретации |
|-----|----------|----------------------|
| `C` | Connected | Сеть напрямую подключена к интерфейсу |
| `I` | IS-IS | Маршрут получен из IGP |
| `S` | Static | Маршрут задан администратором |
| `K` | Kernel | Запись пришла из kernel в FRR |

Для новичка главный вывод: routing protocol не “двигает пакеты” сам. Он создаёт информацию,
которая через `zebra` превращается в kernel FIB.

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

Запишите три факта:

1. Кто источник маршрута в FRR?
2. Какой next-hop выбран?
3. Есть ли совпадающая запись в `ip -6 route show`?

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

Пояснение: этот шаг нужен, чтобы увидеть обратное направление управления. В первом случае
маршрут появился из протокола IS-IS, во втором — из ручной конфигурации FRR. В обоих случаях
установка в kernel всё равно идёт через `zebra`.
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

## Контрольные вопросы

1. Почему `show ipv6 route` и `ip -6 route show` могут отличаться?
2. Какой daemon FRR отвечает за установку маршрутов в kernel?
3. Что произойдёт с dataplane, если IS-IS знает маршрут, но zebra не смог записать его в kernel?
4. Почему connected-маршруты появляются без IS-IS?

## Требования к отчёту

- Схема цепочки `isisd -> zebra -> netlink -> kernel FIB`.
- Таблица для маршрута к loopback r3: FRR code, next-hop, outgoing interface, kernel route.
- Короткое объяснение, что изменилось после добавления статического маршрута.
