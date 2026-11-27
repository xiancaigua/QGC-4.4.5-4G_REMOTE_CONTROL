"""Local, unarmed MAVLink endpoint for QGC UI/command-path tests.

This is not PX4 SITL and never drives a flight controller. Bind only to
127.0.0.1. Captures MANUAL_CONTROL, PARAM_SET, and DO_SET_ACTUATOR traffic.
"""

import json
import math
import socket
import struct
import time
from datetime import datetime, timezone
from pathlib import Path


ADDRESS = ("127.0.0.1", 14560)
QGC = ("127.0.0.1", 14550)
CAPTURE = Path(__file__).with_name("mavlink_control_mock_capture.jsonl")
PARAMS = {
    "COM_RC_IN_MODE": (0, 6),
    "COM_DL_LOSS_T": (10, 6),
    "NAV_DLL_ACT": (2, 6),
    "COM_FAIL_ACT_T": (5.0, 9),
    "COM_RC_LOSS_T": (0.5, 9),
    "NAV_RCL_ACT": (2, 6),
    "COM_RCL_EXCEPT": (0, 6),
}
CRC_EXTRA = {0: 50, 22: 220, 65: 118, 77: 143}


def checksum(data):
    crc = 0xFFFF
    for byte in data:
        tmp = byte ^ (crc & 0xFF)
        tmp ^= (tmp << 4) & 0xFF
        crc = ((crc >> 8) ^ (tmp << 8) ^ (tmp << 3) ^ (tmp >> 4)) & 0xFFFF
    return crc


def packet(seq, msgid, payload):
    frame = bytes((len(payload), seq & 255, 1, 1, msgid)) + payload
    return b"\xfe" + frame + struct.pack("<H", checksum(frame + bytes((CRC_EXTRA[msgid],))))


def messages(datagram):
    offset = 0
    while offset < len(datagram):
        magic = datagram[offset]
        if magic == 0xFE and offset + 8 <= len(datagram):
            length = datagram[offset + 1]
            end = offset + 6 + length + 2
            if end > len(datagram):
                break
            yield datagram[offset + 5], datagram[offset + 6:offset + 6 + length]
            offset = end
        elif magic == 0xFD and offset + 12 <= len(datagram):
            length = datagram[offset + 1]
            signed = bool(datagram[offset + 2] & 1)
            end = offset + 10 + length + 2 + (13 if signed else 0)
            if end > len(datagram):
                break
            msgid = int.from_bytes(datagram[offset + 7:offset + 10], "little")
            yield msgid, datagram[offset + 10:offset + 10 + length]
            offset = end
        else:
            offset += 1


def log(stream, kind, **fields):
    record = {"utc": datetime.now(timezone.utc).isoformat(), "kind": kind, **fields}
    stream.write(json.dumps(record, allow_nan=True) + "\n")
    stream.flush()
    print(json.dumps(record, allow_nan=True), flush=True)


def main():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(ADDRESS)
    sock.settimeout(0.1)
    seq = 0
    manual_count = 0
    last_axes = None

    def send(msgid, payload):
        nonlocal seq
        sock.sendto(packet(seq, msgid, payload), QGC)
        seq = (seq + 1) & 255

    def param_value(name):
        value, param_type = PARAMS[name]
        encoded = float(value) if param_type == 9 else struct.unpack("<f", struct.pack("<i", int(value)))[0]
        index = list(PARAMS).index(name)
        send(22, struct.pack("<fHH16sB", encoded, len(PARAMS), index, name.encode().ljust(16, b"\0"), param_type))

    with CAPTURE.open("w", encoding="utf-8") as stream:
        log(stream, "start", address=str(ADDRESS))
        next_heartbeat = 0.0
        next_params = 0.0
        next_rc = 0.0
        while True:
            now = time.monotonic()
            if now >= next_heartbeat:
                send(0, struct.pack("<IBBBBB", 0, 2, 12, 0, 3, 3))
                next_heartbeat = now + 1
            if now >= next_params:
                for name in PARAMS:
                    param_value(name)
                next_params = now + 5
            if now >= next_rc:
                send(65, struct.pack("<I18HBB", int(now * 1000) & 0xFFFFFFFF, *([1500] * 18), 18, 80))
                next_rc = now + 0.5
            try:
                data, _ = sock.recvfrom(65535)
            except (socket.timeout, ConnectionResetError):
                continue
            for msgid, payload in messages(data):
                if msgid == 69 and len(payload) >= 10:
                    x, y, z, r, _ = struct.unpack_from("<hhhhH", payload)
                    manual_count += 1
                    axes = (x, y, z, r)
                    if axes != last_axes or manual_count % 25 == 0:
                        log(stream, "manual_control", count=manual_count, x=x, y=y, z=z, r=r)
                    last_axes = axes
                elif msgid == 23 and len(payload) >= 23:
                    value_bits = payload[:4]
                    name = payload[6:22].split(b"\0", 1)[0].decode("ascii", "ignore")
                    if name in PARAMS:
                        value = struct.unpack("<f", value_bits)[0] if PARAMS[name][1] == 9 else struct.unpack("<i", value_bits)[0]
                        PARAMS[name] = (value, PARAMS[name][1])
                        log(stream, "param_set", name=name, value=value)
                        param_value(name)
                elif msgid == 21:
                    for name in PARAMS:
                        param_value(name)
                elif msgid == 20 and len(payload) >= 20:
                    name = payload[4:20].split(b"\0", 1)[0].decode("ascii", "ignore")
                    if name in PARAMS:
                        param_value(name)
                elif msgid == 76 and len(payload) >= 33:
                    values = struct.unpack_from("<7f", payload)
                    command = struct.unpack_from("<H", payload, 28)[0]
                    if command == 187:
                        log(stream, "actuator_command", values=list(values),
                            other_outputs_nan=all(math.isnan(v) for v in values[1:6]))
                        send(77, struct.pack("<HB", 187, 0))


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
