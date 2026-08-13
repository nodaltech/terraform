#!/bin/bash
set -euxo pipefail
hostnamectl set-hostname nodal-probe

# Sniff NIC is attached as device-index 1 (ens6). Bring it up for VXLAN.
for i in $(seq 1 60); do
  if ip link show ens6 >/dev/null 2>&1; then
    ip link set ens6 up
    break
  fi
  sleep 2
done
