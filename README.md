# SRv6 Lab — программа обучения (4 недели)

Лабораторная среда: Containerlab + FRR 8.4, топология r1—r2—r3.

## Быстрый старт

```bash
cd /home/ivvfedorov/srv6-lab
containerlab deploy -t srv6.yml
```

Документация: [docs/quickstart.md](docs/quickstart.md) | [docs/cheatsheet.md](docs/cheatsheet.md)

## Программа

| Неделя | Тема | Лабы |
|--------|------|------|
| 1 | Unix/Linux, Containerlab, pcap | [lab01](labs/lab01-inspect/) [lab02](labs/lab02-pcap/) |
| 2 | FRR, zebra, netlink | [lab03](labs/lab03-frr-zebra/) [lab04](labs/lab04-netlink/) |
| 3 | SRv6 | [lab05](labs/lab05-srv6-basic/) [lab06](labs/lab06-srv6-behaviors/) [lab07](labs/lab07-srv6-troubleshoot/) |
| 4 | VPP, DPDK, eBPF | [lab08](labs/lab08-vpp/) [lab09](labs/lab09-ebpf/) |

## Структура

```
srv6-lab/
├── srv6.yml              # основная топология FRR
├── srv6-vpp.yml          # отдельная VPP-лаба (ЛР8)
├── configs/
│   ├── r{1,2,3}/         # базовый IS-IS (bind-mount)
│   ├── srv6/             # эталон SRv6 (ЛР5–7)
│   └── vpp-lab/          # конфиг FRR для расширенной VPP-топологии
├── docs/
└── labs/
```

## SRv6 reference

```bash
./labs/lab05-srv6-basic/apply-srv6.sh
```

Подробнее: [configs/srv6/README.md](configs/srv6/README.md)
