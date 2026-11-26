"""Local MAVLink heartbeat endpoint for QGC keyboard-joystick tests.

This only emits an unarmed PX4-style heartbeat on 127.0.0.1 and records
MANUAL_CONTROL frames received from QGC. It is not a flight simulator.
"""

import csv
import socket
import struct
import sys
import time
from datetime import datetime, timezone
from pathlib import Path


PORT = 14560
QGC = ("127.0.0.1", 14550)
OUTPUT = Path(__file__).with_name("mavlink_loopback_capture.csv")


def x25(data: bytes) -> int:
    crc = 0xFFFF
    for byte in data:
        tmp = byte ^ (crc & 0xFF)
        tmp ^= (tmp << 4) & 0xFF
        crc = ((crc >> 8) ^ (tmp << 8) ^ (tmp << 3) ^ (tmp >> 4)) & 0xFFFF
    return crc


def heartbeat(seq: int) -> bytes:
    # MAVLink 1 HEARTBEAT: quadrotor, PX4 autopilot, unarmed standby.
    payload = struct.pack("<IBBBBB", 0, 2, 12, 0, 3, 3)
    frame = bytes((len(payload), seq & 0xFF, 1, 1, 0)) + payload
    return b"\xfe" + frame + struct.pack("<H", x25(frame + bytes((50,))))


def messages(datagram: bytes):
    offset = 0
    while offset < len(datagram):
        magic = datagram[offset]
        if magic == 0xFE and offset + 8 <= len(datagram):
            length = datagram[offset + 1]
            end = offset + 6 + length + 2
            if end > len(datagram):
                break
            yield datagram[offset + 5], datagram[offset + 6 : offset + 6 + length]
            offset = end
        elif magic == 0xFD and offset + 12 <= len(datagram):
            length = datagram[offset + 1]
            signed = bool(datagram[offset + 2] & 1)
            end = offset + 10 + length + 2 + (13 if signed else 0)
            if end > len(datagram):
                break
            msgid = int.from_bytes(datagram[offset + 7 : offset + 10], "little")
            yield msgid, datagram[offset + 10 : offset + 10 + length]
            offset = end
        else:
            offset += 1


def main() -> int:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(("127.0.0.1", PORT))
    sock.settimeout(0.1)
    with OUTPUT.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.writer(stream)
        writer.writerow(("utc", "x_pitch", "y_roll", "z_throttle", "r_yaw", "buttons"))
        stream.flush()
        next_heartbeat = 0.0
        seq = 0
        count = 0
        print(f"Listening on 127.0.0.1:{PORT}; capture={OUTPUT}", flush=True)
        while True:
            now = time.monotonic()
            if now >= next_heartbeat:
                sock.sendto(heartbeat(seq), QGC)
                seq = (seq + 1) & 0xFF
                next_heartbeat = now + 1.0
            try:
                data, _ = sock.recvfrom(65535)
            except (socket.timeout, ConnectionResetError):
                continue
            for msgid, payload in messages(data):
                if msgid == 69 and len(payload) >= 10:
                    x, y, z, r, buttons = struct.unpack_from("<hhhhH", payload)
                    writer.writerow((datetime.now(timezone.utc).isoformat(), x, y, z, r, buttons))
                    stream.flush()
                    count += 1
                    if count % 25 == 0:
                        print(f"MANUAL_CONTROL frames={count} last={x},{y},{z},{r}", flush=True)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(0)
