#!/usr/bin/env bash
# apply-srv6-vpn.sh — recreate the lab with SRv6 + BGP L3VPN configs.
# Использование: ./apply-srv6-vpn.sh

set -euo pipefail

LAB_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$LAB_DIR/../.." && pwd)"
cd "$REPO_DIR"

echo "=== Применяю SRv6 VPN конфигурацию ==="

echo "[1/3] Recreating topology with srv6-vpn.yml..."
containerlab deploy -t srv6-vpn.yml --reconfigure

echo ""
echo "[2/3] Reloading FRR after Linux VRF interfaces are created..."
sleep 5
containerlab exec -t srv6-vpn.yml --cmd "vtysh -b"

echo ""
echo "[3/3] Waiting 25 seconds for IS-IS + BGP convergence..."
sleep 25

echo ""
echo "=== Проверка ==="
echo ""
echo "VRF links:"
docker exec clab-srv6-r1 ip -br link show tenant-a
docker exec clab-srv6-r3 ip -br link show tenant-a
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
