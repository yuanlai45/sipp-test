#!/usr/bin/env python3
"""
UDP listener: prints any SIP message received on the given port.
Usage: python3 udp_listen.py [port]
"""
import socket, sys, time

port = int(sys.argv[1]) if len(sys.argv) > 1 else 10001
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("0.0.0.0", port))
s.settimeout(60)
print(f"[udp_listen] Listening on UDP port {port}...", flush=True)
try:
    while True:
        try:
            data, addr = s.recvfrom(4096)
            first_line = data.decode("utf-8", errors="replace").split("\r\n")[0]
            print(f"[udp_listen] PKT from {addr[0]}:{addr[1]}  => {first_line}", flush=True)
        except socket.timeout:
            print("[udp_listen] 60s timeout, no packet received.", flush=True)
            break
except KeyboardInterrupt:
    pass
finally:
    s.close()
