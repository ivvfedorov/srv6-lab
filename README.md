# SRv6 Lab — программа обучения

Лабораторная среда для последовательного изучения Linux networking, FRR, IS-IS,
SRv6, VPP и eBPF. Основная топология: Containerlab + FRR, три узла `r1-r2-r3`.

Каждая лабораторная построена по одному учебному циклу:

1. **Теория** — минимальная модель, без которой команды будут механическим повторением.
2. **Предусловия** — какое состояние лаборатории нужно перед стартом.
3. **Практика** — команды и наблюдения, которые нужно выполнить руками.
4. **Expected output** — ориентир нормального результата.
5. **Критерий успеха** — что студент должен уметь объяснить после выполнения.

## Быстрый старт

```bash
make deploy
make status
make verify
```

Если `make` недоступен:

```bash
containerlab deploy -t srv6.yml
containerlab inspect -t srv6.yml
```

Документация: [docs/quickstart.md](docs/quickstart.md) |
[docs/cheatsheet.md](docs/cheatsheet.md) |
[docs/lab-format.md](docs/lab-format.md)

## Программа

| Блок | Тема | Лабораторные |
|------|------|--------------|
| 1 | База Linux и Containerlab | [ЛР1](labs/lab01-inspect/), [ЛР2](labs/lab02-pcap/) |
| 2 | FRR, zebra, netlink | [ЛР3](labs/lab03-frr-zebra/), [ЛР4](labs/lab04-netlink/) |
| 3 | Базовый SRv6 | [ЛР5](labs/lab05-srv6-basic/), [ЛР6](labs/lab06-srv6-behaviors/), [ЛР7](labs/lab07-srv6-troubleshoot/) |
| 4 | Dataplane и kernel observability | [ЛР8](labs/lab08-vpp/), [ЛР9](labs/lab09-ebpf/) |
| 5 | Advanced SRv6 | [ЛР10](labs/lab10-srv6-policy/), [ЛР11](labs/lab11-srv6-vpn/) |

Рекомендуемый порядок: ЛР1-ЛР7 обязательны, ЛР8-ЛР9 дают контекст по dataplane и kernel,
ЛР10-ЛР11 идут после уверенного понимания SID, SRH и control/data plane.

## Развертывание

| Сценарий | Команда | Когда использовать |
|----------|---------|--------------------|
| Основная лаборатория FRR | `make deploy` | ЛР1-ЛР7, ЛР9-ЛР11 |
| Проверка состояния | `make verify` | Перед началом любой ЛР |
| SRv6 reference config | `make srv6` | ЛР5-ЛР7, ЛР10 |
| BGP SRv6 L3VPN | `make vpn` | ЛР11 |
| VPP topology | `make vpp` | ЛР8 |
| Очистка основной лабы | `make clean` | После занятия или перед пересборкой |

## Структура

```
srv6-lab/
├── srv6.yml              # основная топология FRR
├── srv6-vpp.yml          # отдельная VPP-лаба (ЛР8)
├── Makefile              # единые команды развертывания и проверки
├── configs/
│   ├── r{1,2,3}/         # базовый IS-IS (bind-mount)
│   └── srv6/             # эталон SRv6 и VPN-конфиги (ЛР5-ЛР11)
├── docs/
└── labs/
```

## SRv6 reference

```bash
make srv6
```

Подробнее: [configs/srv6/README.md](configs/srv6/README.md)
