# ЛР5: Базовая SRv6 connectivity

**Неделя 3** | Время: ~3 ч

## Цель

Включить SRv6 locators через IS-IS на r1—r2—r3, увидеть SID'ы в FRR и kernel.

## Предусловия

Базовая лаба с IS-IS (конфиги `configs/r*/frr.conf` после `containerlab deploy`).

## Задания

### 1. Изучите эталонный конфиг

Файлы: `configs/srv6/r1/frr.conf`, `r2`, `r3`.

Ключевые блоки:
- `segment-routing srv6 locators` — prefix locator на zebra
- `router isis CORE / segment-routing srv6 / locator` — привязка к IS-IS

### 2. Примените SRv6

```bash
cd /home/ivvfedorov/srv6-lab
chmod +x labs/lab05-srv6-basic/apply-srv6.sh
./labs/lab05-srv6-basic/apply-srv6.sh
```

Подождите ~30 с для convergence IS-IS.

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

## Критерий успеха

- [ ] Locator `Up` на всех трёх узлах
- [ ] IS-IS neighbors `Up`
- [ ] ping r1 → lo r3 успешен
- [ ] Таблица SID заполнена (uN, uA на adjacency)

Справочник SID: [configs/srv6/README.md](../../configs/srv6/README.md)
