#!/usr/bin/env bash
# Apply SRv6 reference configs to running lab containers.
set -euo pipefail

LAB_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$LAB_DIR"

for r in r1 r2 r3; do
  echo "Copying configs/srv6/${r}/frr.conf -> configs/${r}/frr.conf"
  cp "configs/srv6/${r}/frr.conf" "configs/${r}/frr.conf"
done

echo "Reloading FRR on all nodes..."
for r in r1 r2 r3; do
  docker exec "clab-srv6-${r}" vtysh -b
done

echo "Waiting for IS-IS/SRv6 convergence..."
sleep 20

echo "Done. Verify with:"
echo "  docker exec clab-srv6-r1 vtysh -c 'show segment-routing srv6 locator'"
