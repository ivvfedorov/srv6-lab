# ЛР7: Troubleshooting SRv6

**Неделя 3** | Время: ~2 ч

## Цель

Систематически диагностировать SRv6: control plane (FRR) и data plane (kernel).

## Теория

В SRv6 возможна ситуация, когда control plane выглядит исправным, но data plane не пересылает
пакеты. Например, locator может быть `Up` в FRR, IS-IS соседства могут быть установлены, но
kernel не будет выполнять SRv6-обработку из-за `seg6_enabled=0` или отсутствия `seg6local`
маршрута.

Диагностика строится слоями: сначала проверяется IGP и locator в FRR, затем SID в FRR, затем
записи kernel FIB, затем реальный пакет через `tcpdump`. Такой порядок помогает отделить
ошибку анонса, ошибку установки маршрута и ошибку обработки пакета.

## Предусловия

SRv6 включён:

```bash
make srv6
```

## Задания

### 1. Пройдите чеклист

Откройте [checklist.md](checklist.md) и отметьте каждый пункт на r1.

### 2. Сломанная лаба (self-inflicted)

На r3:

```bash
docker exec clab-srv6-r3 sysctl -w net.ipv6.conf.all.seg6_enabled=0
```

Проверьте `show segment-routing srv6 locator` (должен быть Up) vs ping/traffic.

Восстановите:

```bash
docker exec clab-srv6-r3 sysctl -w net.ipv6.conf.all.seg6_enabled=1
```

### 3. Manual kernel encap

На r1 (если SID'ы в kernel):

```bash
docker exec clab-srv6-r1 ip -6 route add 2001:db8:3::3/128 encap seg6 mode encap \
  segs 2001:db8:2::2,2001:db8:3::3 dev eth1 2>&1 || echo "encap failed — check SIDs"
```

Захват на r2:

```bash
docker exec clab-srv6-r2 tcpdump -ni eth1 -c 5 -vv 'ip6[40:1]=4' 2>&1
docker exec clab-srv6-r1 ping6 -c 1 2001:db8:3::3
```

### 4. Логи

```bash
docker exec clab-srv6-r1 tail -30 /var/log/frr/isisd.log 2>/dev/null || \
  docker logs clab-srv6-r1 2>&1 | tail -30
```

### 5. Отчёт

Напишите 1 страницу: симптом → проверка → root cause → fix (для задания 2).

## Expected output

```
$ sysctl net.ipv6.conf.all.seg6_enabled
net.ipv6.conf.all.seg6_enabled = 1

r1# show segment-routing srv6 locator
LOC1    1    2001:db8:1::/64    Up
```

## Критерий успеха

- [ ] Чеклист пройден на всех узлах
- [ ] Объяснить, почему locator Up не гарантирует working encap
- [ ] Восстановить connectivity после `seg6_enabled=0`
