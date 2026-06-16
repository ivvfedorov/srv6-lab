# SRv6 Lab — программа обучения

Лабораторная среда для последовательного изучения Linux networking, FRR, IS-IS,
SRv6, VPP и eBPF. Основная топология: Containerlab + FRR, три узла `r1-r2-r3`.

Курс рассчитан на студентов, которые не работали с SRv6 и могут иметь минимальный опыт Linux.
Материал построен от наблюдения базовой сети к настройке control plane, затем к SRv6 dataplane
и сервисным сценариям L3VPN.

Каждая лабораторная построена по одному учебному циклу:

1. **Теория** — минимальная модель, без которой команды будут механическим повторением.
2. **Предусловия** — какое состояние лаборатории нужно перед стартом.
3. **Практика** — команды и наблюдения, которые нужно выполнить руками.
4. **Expected output** — ориентир нормального результата.
5. **Критерий успеха** — что студент должен уметь объяснить после выполнения.

## Минимальные требования

| Компонент | Минимальная версия | Проверка |
|-----------|--------------------|----------|
| **ОС** | macOS 12+ (Apple Silicon / Intel), Linux (Ubuntu 20.04+ / Debian 11+) | `uname -s` |
| **Docker** | 20.10+ с включённым Docker Engine | `docker version` |
| **Containerlab** | 0.41+ | `containerlab version` |
| **git** | 2.30+ | `git --version` |
| **make** | — (опционально, можно без него через `containerlab` напрямую) | `make --version` |

**Аппаратные требования:**

| Ресурс | Минимум | Комфортно |
|--------|---------|-----------|
| RAM | 4 GB | 8+ GB |
| CPU | 2 ядра (x86-64 / ARM64) | 4 ядра |
| Диск | 2 GB свободно | 5+ GB |

FRR-контейнеры потребляют ~64 MB RAM каждый, основная нагрузка — сам Docker Engine.

### Установка зависимостей

**macOS (Homebrew):**

```bash
brew install --cask docker          # Docker Desktop
brew install containerlab git make
```

**Ubuntu / Debian:**

```bash
# Docker: https://docs.docker.com/engine/install/ubuntu/
sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Containerlab: https://containerlab.dev/install/
sudo bash -c "$(curl -sL https://get.containerlab.dev)"

sudo apt-get install -y git make
```

### Проверка перед первым запуском

```bash
docker version      # Docker должен быть запущен
containerlab version
git clone https://github.com/ivvfedorov/srv6-lab.git
cd srv6-lab
```

## Быстрый старт

```bash
make deploy
make status
make verify
```

Без `make`:

```bash
containerlab deploy -t srv6.yml
containerlab inspect -t srv6.yml
```

Основная документация:

- [docs/quickstart.md](docs/quickstart.md) — запуск стенда и доступ к узлам.
- [docs/theory-foundations.md](docs/theory-foundations.md) — вводная теория для новичков.
- [docs/theory-srv6-advanced.md](docs/theory-srv6-advanced.md) — углублённая теория SRv6.
- [docs/lab-format.md](docs/lab-format.md) — формат выполнения и отчёта.
- [docs/cheatsheet.md](docs/cheatsheet.md) — команды для повторения.

FRR-топологии закреплены на образе `frrouting/frr:v8.4.0`, чтобы вывод CLI и SRv6 behavior
оставались воспроизводимыми между занятиями. VPP-лаба использует отдельный образ из `srv6-vpp.yml`.

## Программа

| Блок | Тема | Что должен понять студент | Лабораторные |
|------|------|---------------------------|--------------|
| 1 | База Linux и Containerlab | Интерфейсы, маршруты, pcap, отличие mgmt/data сети | [ЛР1](labs/lab01-inspect/), [ЛР2](labs/lab02-pcap/) |
| 2 | FRR, zebra, netlink | Как control plane попадает в kernel FIB | [ЛР3](labs/lab03-frr-zebra/), [ЛР4](labs/lab04-netlink/) |
| 3 | Базовый SRv6 | Locator, SID, SRH, behavior, troubleshooting | [ЛР5](labs/lab05-srv6-basic/), [ЛР6](labs/lab06-srv6-behaviors/), [ЛР7](labs/lab07-srv6-troubleshoot/) |
| 4 | Dataplane и kernel observability | Почему dataplane бывает разным и как его наблюдать | [ЛР8](labs/lab08-vpp/), [ЛР9](labs/lab09-ebpf/) |
| 5 | Advanced SRv6 | SR Policy, Candidate Path, BSID, BGP SRv6 L3VPN | [ЛР10](labs/lab10-srv6-policy/), [ЛР11](labs/lab11-srv6-vpn/) |

Рекомендуемый порядок: ЛР1-ЛР7 обязательны, ЛР8-ЛР9 дают контекст по dataplane и kernel,
ЛР10-ЛР11 идут после уверенного понимания SID, SRH и control/data plane.

## Развертывание

| Сценарий | Команда | Когда использовать |
|----------|---------|--------------------|
| Базовая лаборатория FRR | `make deploy` | ЛР1-ЛР4 |
| Проверка состояния | `make verify` | Перед началом любой ЛР |
| SRv6 reference config | `make srv6` | ЛР5-ЛР7, ЛР10 |
| BGP SRv6 L3VPN | `make vpn` | ЛР11 |
| VPP topology | `make vpp` | ЛР8 |
| Очистка основной лабы | `make clean` | После занятия или перед пересборкой |

## Структура

```
srv6-lab/
├── srv6.yml              # основная топология FRR
├── srv6-reference.yml    # та же топология с SRv6 bind-mount configs/srv6
├── srv6-vpn.yml          # SRv6 + BGP L3VPN режим для ЛР11
├── srv6-vpp.yml          # отдельная VPP-лаба (ЛР8)
├── Makefile              # единые команды развертывания и проверки
├── configs/
│   ├── r{1,2,3}/         # базовый IPv6 + IS-IS без SRv6
│   └── srv6/             # эталон SRv6 и VPN-конфиги (ЛР5-ЛР11)
├── docs/
└── labs/
```

## SRv6 reference

```bash
make srv6
```

Подробнее: [configs/srv6/README.md](configs/srv6/README.md)

Вернуться к базовой лаборатории без SRv6:

```bash
make redeploy
```
