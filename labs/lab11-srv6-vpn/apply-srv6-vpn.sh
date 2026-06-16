#!/bin/bash
# apply-srv6-vpn.sh — применить конфиги SRv6 + BGP L3VPN
# Использование: ./apply-srv6-vpn.sh

set -e

LAB_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$LAB_DIR/../.." && pwd)"
CONFIG_DIR="$REPO_DIR/configs/srv6"

echo "=== Применяю SRv6 VPN конфигурацию ==="

# 1. Копируем daemons с bgpd=yes
echo "[1/3] Копирую daemons с bgpd=yes..."
docker cp "$CONFIG_DIR/r1/daemons-vpn" clab-srv6-r1:/etc/frr/daemons
docker cp "$CONFIG_DIR/r2/daemons-vpn" clab-srv6-r2:/etc/frr/daemons
docker cp "$CONFIG_DIR/r3/daemons-vpn" clab-srv6-r3:/etc/frr/daemons

# 2. Копируем FRR конфиги с VRF и BGP VPN
echo "[2/3] Копирую FRR конфиги..."
docker cp "$CONFIG_DIR/r1/frr-vpn.conf" clab-srv6-r1:/etc/frr/frr.conf
docker cp "$CONFIG_DIR/r2/frr-vpn.conf" clab-srv6-r2:/etc/frr/frr.conf
docker cp "$CONFIG_DIR/r3/frr-vpn.conf" clab-srv6-r3:/etc/frr/frr.conf

# 3. Перезапускаем FRR на всех узлах
echo "[3/3] Перезапускаю FRR..."
docker exec clab-srv6-r1 /usr/lib/frr/frrinit.sh restart
docker exec clab-srv6-r2 /usr/lib/frr/frrinit.sh restart
docker exec clab-srv6-r3 /usr/lib/frr/frrinit.sh restart

echo ""
echo "=== Готово. Ждём 30 секунд для сходимости IS-IS + BGP..."
sleep 30

echo ""
echo "=== Проверка ==="
echo ""
echo "IS-IS neighbors:"
docker exec clab-srv6-r1 vtysh -c "show isis neighbor"
echo ""
echo "BGP summary (r1):"
docker exec clab-srv6-r1 vtysh -c "show bgp summary"
echo ""
echo "SRv6 SID (r1):"
docker exec clab-srv6-r1 vtysh -c "show segment-routing srv6 sid"
echo ""
echo "=== Проверки ЛР11 ==="
echo "1. Проверьте BGP VPNv6:  vtysh -c 'show bgp ipv6 vpn'"
echo "2. Проверьте VRF:        vtysh -c 'show ipv6 route vrf TENANT_A'"
echo "3. Ping end-to-end:      ping6 -I TENANT_A -c 3 2001:db8:beef::1"
