# SRv6 Reference Configuration

Эталонные конфиги для ЛР5–ЛР7. Базовые конфиги (без SRv6): `configs/r*/frr.conf`.

## Locator plan

| Node | Locator name | Prefix | Loopback |
|------|--------------|--------|----------|
| r1 | LOC1 | `2001:db8:1::/64` | `2001:db8:1::1/128` |
| r2 | LOC2 | `2001:db8:2::/64` | `2001:db8:2::2/128` |
| r3 | LOC3 | `2001:db8:3::/64` | `2001:db8:3::3/128` |

## IS-IS NET

| Node | NET |
|------|-----|
| r1 | `49.0001.0000.0000.0001.00` |
| r2 | `49.0001.0000.0000.0002.00` |
| r3 | `49.0001.0000.0000.0003.00` |

## Автовыделенные SID (после apply)

IS-IS SRv6 автоматически создаёт:

| Behavior | RFC name | Назначение |
|----------|----------|------------|
| uN | End (uSID) | Prefix-SID узла |
| uA | End.X (uSID) | Adjacency SID на интерфейсе |

Проверка: `vtysh -c "show segment-routing srv6 sid"`

## Применение

```bash
./labs/lab05-srv6-basic/apply-srv6.sh
```

## Откат к базовому IS-IS (без SRv6)

```bash
cd /home/ivvfedorov/srv6-lab
containerlab deploy -t srv6.yml --reconfigure
```

## Kernel encap (ручной тест, lab07)

```bash
# На r1 — отправка через segment list [r2, r3]
ip -6 route add 2001:db8:3::3/128 encap seg6 mode encap \
  segs 2001:db8:2::2,2001:db8:3::3 dev eth1
```

Требует, что SID'ы установлены в kernel (через zebra/FRR).
