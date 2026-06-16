# Сценарий 6: SRv6 behaviors

**Неделя 3** | Время: ~2.5 ч

## Цель

Различать End (uN), End.X (uA), понять decapsulation End.DT6; составить таблицу SID.

После выполнения необходимо уметь прочитать вывод `show segment-routing srv6 sid` и
объяснить не только адрес SID, но и действие, которое выполнит узел при получении пакета.

## Что нужно знать заранее

- SID — это IPv6-адрес с привязанным behavior.
- Locator доставляет пакет до узла, function задаёт действие на узле.
- IS-IS в этой лаборатории автоматически создаёт часть SID для node и adjacency.
- End.DT6 появляется в сервисных сценариях VRF/L3VPN, а не в простой reachability.

Рекомендуемое чтение: [../../docs/theory-foundations.md](../../docs/theory-foundations.md),
раздел 9.

## Теория

Один и тот же IPv6-адрес `2001:db8:2::` может быть просто loopback'ом, а может быть
SID с поведением End. Как понять, что адрес реально делает с пакетом? Ответ — behavior:
действие, которое узел выполняет, когда Destination Address равен локальному SID.

Три поведения:
- **End (uN)** — терминирующий SID: пакет достиг узла, SRH обработан, выполняется
  lookup по внутреннему заголовку (inner IPv6). Аналог PHP в MPLS.
- **End.X (uA)** — cross-connect SID: пакет перебрасывается через конкретный
  L3-adjacency без lookup. Аналог Adjacency-SID в SR-MPLS: пакет уходит в заданный
  интерфейс, минуя таблицу маршрутизации.
- **End.DT6 (uDT6)** — VPN-терминирующий SID: аналог Pop + VPN-label lookup в MPLS.
  Деинкапсуляция внешнего IPv6/SRH и lookup внутреннего пакета в VRF. Детально
  разбирается в Сценарий 11.

Поломка наглядна: отключите IS-IS на eth2 у r2. End.X SID `2001:db8:2:e001::`
(adjacency в сторону r3) исчезает из таблицы. Пакет, идущий через этот SID,
больше не может пройти — чёрная дыра до восстановления соседства.

| Behavior в FRR | Академическое имя | Простая интерпретация | Где проверять |
|----------------|-------------------|-----------------------|---------------|
| `uN` | End/uN | «Это SID самого узла» | locator/node SID |
| `uA` | End.X/uA | «Перешли через конкретную adjacency» | context `interface ethX` |
| `uDT6` | End.DT6 | «Деинкапсулировать IPv6 в VRF» | Сценарий 11, VRF service SID |

Частое заблуждение: «SID — это просто адрес». В SRv6 адрес важен только вместе
с behavior. Один и тот же формат IPv6-адреса может означать совершенно разные действия.

## Предусловия

SRv6 применён:

```bash
make srv6
```

## Шаги проверки

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

В артефактах не оставляйте пустой context. Если context неочевиден, укажите вывод команды полностью
и объясните, почему behavior классифицирован как node или adjacency SID.

### 2. End vs End.X

- **uN (End)**: SID узла, pop и forward по inner destination
- **uA (End.X)**: cross-connect на конкретный interface/adjacency

Найдите uA SID на r2 для eth1 (к r1) и eth2 (к r3).

Важная проверка понимания: r2 имеет два adjacency SID, потому что у r2 два data-интерфейса.
r1 и r3 в этой топологии имеют по одному adjacency SID, потому что у каждого один data-линк.

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

Прочитайте [RFC 8986 — End.DT6](https://datatracker.ietf.org/doc/html/rfc8986). В FRR static behavior:

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

End.DT6 пока рассматривается концептуально. Полная проверка появится в Сценарий 11, где VRF `TENANT_A`
будет связан с service SID и BGP VPNv6.

## Expected output

```
r2# show segment-routing srv6 sid
SID                   Behavior    Context
--------------------  ----------  -----------------
2001:db8:2::          uN          isis(0)
2001:db8:2:e000::     uA          interface eth1
2001:db8:2:e001::     uA          interface eth2
```

## Критерии валидации

- [ ] Таблица SID→behavior→контекст для всех узлов
- [ ] Объяснить разницу uN и uA на примере r2
- [ ] Описать, что произошло при отключении IS-IS на eth2

## Контрольные вопросы

1. Почему у r2 больше adjacency SID, чем у r1?
2. Что означает `Context: interface eth2` в выводе SID?
3. Чем End.DT6 принципиально отличается от End.X?
4. Почему отключение IS-IS на интерфейсе влияет на SID/locator reachability?

## Артефакты диагностики

- Полная таблица SID по r1/r2/r3.
- Отдельное объяснение для каждого behavior: `uN`, `uA`, `uDT6`.
- Краткий анализ failure injection: симптом, какие команды это показали, как восстановили.

