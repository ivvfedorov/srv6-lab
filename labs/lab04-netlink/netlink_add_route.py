#!/usr/bin/env python3
"""ЛР4: добавление IPv6-маршрута через netlink (pyroute2)."""

from pyroute2 import IPRoute


def main() -> None:
    dst = "2001:db8:88::/64"
    ifname = "eth1"

    ip = IPRoute()
    try:
        idx = ip.link_lookup(ifname=ifname)[0]
        ip.route("add", dst=dst, oif=idx)
        print(f"Added route {dst} dev {ifname} (ifindex={idx})")
    finally:
        ip.close()


if __name__ == "__main__":
    main()
