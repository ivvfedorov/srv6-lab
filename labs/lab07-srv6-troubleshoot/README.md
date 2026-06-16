# ЛР7: Troubleshooting SRv6

**Неделя 3** | Время: ~2 ч

## Цель

Систематически диагностировать SRv6: control plane (FRR) и data plane (kernel).

После выполнения студент должен уметь строить диагностическую цепочку от симптома к root cause,
а не случайно запускать команды из шпаргалки.

## Что нужно знать заранее

- Control plane может выглядеть исправным, даже если kernel dataplane не обрабатывает SRv6.
- Locator `Up` — это состояние FRR, а не гарантия прохождения конкретного пакета.
- `sysctl net.ipv6.conf.*.seg6_enabled` влияет на обработку SRv6 в Linux.
- `tcpdump` нужен для подтверждения реального пакета и SRH.

Рекомендуемое чтение: [../../docs/theory-foundations.md](../../docs/theory-foundations.md),
разделы 8-9.

## Теория

В SRv6 возможна ситуация, когда control plane выглядит исправным, но data plane не пересылает
пакеты. Например, locator может быть `Up` в FRR, IS-IS соседства могут быть установлены, но
kernel не будет выполнять SRv6-обработку из-за `seg6_enabled=0` или отсутствия `seg6local`
маршрута.

Диагностика строится слоями: сначала проверяется IGP и locator в FRR, затем SID в FRR, затем
записи kernel FIB, затем реальный пакет через `tcpdump`. Такой порядок помогает отделить
ошибку анонса, ошибку установки маршрута и ошибку обработки пакета.

Методика поиска неисправности:

| Шаг | Вопрос | Команды |
|-----|--------|---------|
| 1 | Контейнеры живы? | `containerlab inspect`, `docker ps` |
| 2 | Интерфейсы и адреса есть? | `ip -6 -br addr`, `ip link` |
| 3 | IS-IS соседство поднято? | `show isis neighbor` |
| 4 | Locator/SID видны в FRR? | `show segment-routing srv6 locator/sid` |
| 5 | Kernel получил SRv6 state? | `ip -6 route show table all \| grep seg6` |
| 6 | Пакет реально идёт? | `ping6`, `traceroute6`, `tcpdump` |

Запрещённый анти-паттерн для отчёта: “не работало, перезапустил, заработало”. Нужно указать
симптом, слой отказа, проверку и конкретное исправление.

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

Ожидаемое противоречие: control plane может продолжать показывать locator `Up`, потому что
IS-IS и FRR не обязательно знают, что kernel SRv6 processing был отключён sysctl-параметром.

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

Минимальная структура:

| Поле | Что написать |
|------|--------------|
| Симптом | Какая команда показала проблему |
| Гипотеза | На каком слое ожидается отказ |
| Проверка | Команда и важный фрагмент вывода |
| Root cause | Почему именно это причина |
| Fix | Команда восстановления и подтверждение |

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

## Контрольные вопросы

1. Почему locator `Up` относится к control plane, а `seg6_enabled` — к data plane?
2. Какая команда доказывает, что kernel видит `seg6local`?
3. Почему tcpdump важен при споре “маршрут есть, но пакет не идёт”?
4. Что нужно проверить первым: BGP/SRv6 или физическое состояние интерфейсов? Почему?

## Требования к отчёту

- Заполненная таблица troubleshooting для искусственной поломки.
- Вывод до и после восстановления `seg6_enabled`.
- Минимум один пример, где FRR output и kernel output показывают разные уровни системы.
