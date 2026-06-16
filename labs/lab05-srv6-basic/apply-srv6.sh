#!/usr/bin/env bash
# Recreate the lab with SRv6 reference configs without modifying tracked files.
set -euo pipefail

LAB_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$LAB_DIR"

echo "Recreating topology with srv6-reference.yml..."
containerlab deploy -t srv6-reference.yml --reconfigure

echo "Waiting for IS-IS/SRv6 convergence..."
sleep 20

echo "SRv6 locator check:"
containerlab exec -t srv6-reference.yml --cmd "vtysh -c 'show segment-routing srv6 locator'"
