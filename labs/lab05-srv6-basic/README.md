# Сценарий 5: Базовая SRv6 connectivity

**Неделя 3** | Время: ~3 ч

## Цель

Включить SRv6 locators через IS-IS на r1—r2—r3, увидеть SID'ы в FRR и kernel.

После выполнения необходимо понимать, чем обычная IPv6-связность отличается от SRv6-
готовой сети, и почему наличие locator/SID нужно проверять отдельно от ping.

## Что нужно знать заранее

- Из Сценарии 1-4: интерфейсы Linux, IPv6-маршруты, FRR RIB, kernel FIB, IS-IS соседства.
- SID в SRv6 — это IPv6-адрес, который кодирует сетевое действие.
- Locator — routable-префикс, по которому сеть доставляет пакет к узлу-владельцу SID.
- SRv6 control plane в этой лаборатории строится через IS-IS.

Рекомендуемое чтение: [../../docs/theory-foundations.md](../../docs/theory-foundations.md),
разделы 7-9.

## Теория

IS-IS сходится, ping идёт — зачем тогда SRv6? Проблема в том, что IGP shortest-path
не даёт управлять трафиком: пакеты всегда идут по кратчайшему пути, и свернуть их
на альтернативный линк нельзя без сложных трюков с метриками. SRv6 решает это через
явный список инструкций в заголовке пакета.

SRv6 SID = Locator + Function.
- **Locator** — routable-префикс, анонсируемый через IGP. Аналог Node-SID в SR-MPLS:
  доставляет пакет к узлу-владельцу SID. В нашем стенде это `/64` префикс:
  `2001:db8:1::/64` для r1.
- **Function** — поведение, которое узел выполняет при получении пакета с данным
  Destination Address. End (uN) — аналог PHP (Penultimate Hop Popping) с обработкой
  на узле. End.X (uA) — аналог Adjacency-SID в SR-MPLS.
- **SID** = Locator + Function. `2001:db8:1:e000::` — это locator r1 + функция
  `e000` (End.X на eth1).

Что ломается без SRv6? Ничего — IGP работает. Но вы не можете сказать пакету
«иди через r2, потом через r4, потом к r3». Только shortest path.

Что ломается при `seg6_enabled=0` в kernel? Самое коварное: locator в FRR показывает
`Up`, IS-IS соседи живы, SID видны — но пакет с SID в Destination Address дропается
ядром. Control plane здоров, data plane парализован.

```text
r1 locator 2001:db8:1::/64    r2 locator 2001:db8:2::/64
         \                      /
    IS-IS анонсирует locator'ы → FRR создаёт SID → zebra ставит seg6local в kernel
                              |
                   r3 locator 2001:db8:3::/64
```

| Результат | Что доказывает | Команда |
|-----------|----------------|---------|
| r1 пингует loopback r3 | Обычная IPv6 reachability работает | `ping6 2001:db8:3::3` |
| Locator `Up` | FRR принял SRv6 locator | `show segment-routing srv6 locator` |
| SID отображается | FRR создал SID behavior | `show segment-routing srv6 sid` |
| `seg6`/`seg6local` виден | Kernel получил SRv6 dataplane state | `ip -6 route show table all` |

## Предусловия

Базовая лаба с IPv6 + IS-IS без SRv6:

```bash
make deploy
make verify
```

Перед применением SRv6 убедитесь, что команда ниже не показывает SRv6 locator в базовом режиме:

```bash
docker exec clab-srv6-r1 vtysh -c "show segment-routing srv6 locator"
```

## Шаги проверки

### 1. Изучите эталонный конфиг

Файлы: `configs/srv6/r1/frr.conf`, `r2`, `r3`.

Ключевые блоки:
- `segment-routing srv6 locators` — prefix locator на zebra
- `router isis CORE / segment-routing srv6 / locator` — привязка к IS-IS

### 2. Примените SRv6

```bash
make srv6
```

Подождите ~30 с для convergence IS-IS.

`make srv6` использует `srv6-reference.yml` и не перезаписывает `configs/r*/frr.conf`.

Альтернативный wrapper для той же операции:

```bash
./labs/lab05-srv6-basic/apply-srv6.sh
```

### 3. Проверка locators и SID

```bash
docker exec clab-srv6-r1 vtysh -c "show segment-routing srv6 locator"
docker exec clab-srv6-r1 vtysh -c "show segment-routing srv6 sid"
docker exec clab-srv6-r2 vtysh -c "show segment-routing srv6 sid"
docker exec clab-srv6-r3 vtysh -c "show segment-routing srv6 sid"
```

### 4. Kernel SRv6

```bash
docker exec clab-srv6-r1 ip -6 route show table all | grep -i seg6 || true
docker exec clab-srv6-r1 sysctl net.ipv6.conf.all.seg6_enabled
```

Интерпретация:

- FRR output отвечает на вопрос “что решил control plane”.
- `ip -6 route show table all` отвечает на вопрос “что получил kernel”.
- `sysctl seg6_enabled` отвечает на вопрос “разрешена ли обработка SRv6 на уровне ядра”.

### 5. Connectivity

```bash
docker exec clab-srv6-r1 ping6 -c 3 2001:db8:3::3
docker exec clab-srv6-r1 traceroute6 -n 2001:db8:3::3
```

### 6. Захват SRH (если encapsulation активен)

```bash
docker exec clab-srv6-r2 tcpdump -ni eth1 -c 20 -vv ip6 2>&1 | head -30
```

Ищите Routing Header Type 4 при policy-based encapsulation.

В этом базовом сценарии SRH может не появиться при обычном ping, потому что обычная reachability до
loopback r3 идёт по IGP shortest path. SRH ожидается в Сценарий 10, когда headend явно добавляет
segment list.

## Expected output

```
r1# show segment-routing srv6 locator
Locator:
Name    ID      Prefix              Status
------  ------  ------------------  ------
LOC1    1       2001:db8:1::/64     Up

r1# show segment-routing srv6 sid
SID                   Behavior    Context
--------------------  ----------  ---------------
2001:db8:1::          uN          isis(0)
2001:db8:1:e000::     uA          interface eth1
```

```
$ ping6 -c 3 2001:db8:3::3
3 packets transmitted, 3 received, 0% packet loss
```

## Критерии валидации

- [ ] Locator `Up` на всех трёх узлах
- [ ] IS-IS neighbors `Up`
- [ ] ping r1 → lo r3 успешен
- [ ] Таблица SID заполнена (uN, uA на adjacency)

Справочник SID: [configs/srv6/README.md](../../configs/srv6/README.md)

## Контрольные вопросы

1. Почему ping r1 -> r3 не доказывает сам по себе, что SRv6 работает?
2. Чем locator отличается от loopback-адреса узла?
3. Почему IS-IS должен анонсировать locator-префиксы?
4. Где проходит граница между SRv6 control plane и kernel dataplane?

## Артефакты диагностики

- Таблица locator'ов r1/r2/r3 со статусом `Up`.
- Таблица SID на каждом узле: SID, behavior, context.
- Сравнение базового режима `make deploy` и SRv6-режима `make srv6`.
- Короткое объяснение, почему SRH не обязан появляться при обычном ping.

