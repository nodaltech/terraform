#!/bin/sh
set -eux

sudo cloud-init status --wait || true

for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
  if ip link show ens6 >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

# ens6 is often DOWN when attached after boot; Traffic Mirror needs it UP.
if ip link show ens6 >/dev/null 2>&1; then
  sudo ip link set ens6 up
  ip link show ens6
fi

sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y unzip

test -f /home/ubuntu/probe.zip
ls -la /home/ubuntu/probe.zip

unzip -o /home/ubuntu/probe.zip -d /home/ubuntu

INSTALL_SH=$(find /home/ubuntu -type f -name install.sh -print -quit)
if [ -z "${INSTALL_SH}" ]; then
  echo "install.sh not found after unzipping probe.zip. Archive contents:" >&2
  find /home/ubuntu -maxdepth 4 -print >&2
  exit 1
fi

echo "Running installer: ${INSTALL_SH}"
chmod +x "${INSTALL_SH}"
cd "$(dirname "${INSTALL_SH}")"
sudo ./install.sh

echo "Probe install finished. Files under /home/ubuntu:"
ls -la /home/ubuntu

rm -f /home/ubuntu/probe.zip
