#!/usr/bin/python3
"""Advertise the TV remote proxy on the Steam Deck's Wi-Fi interface."""
import ipaddress
import signal
import socket
import struct
import sys
import time

lan_ip = str(ipaddress.IPv4Address(sys.argv[1]))
service = '_androidtvremote2._tcp.local'
instance = 'Steam Deck Android TV.' + service
host = 'steamdeck-androidtv.local'
group = ('224.0.0.251', 5353)
running = True

def stop(*_):
    global running
    running = False

signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)

def dns_name(value):
    return b''.join(bytes([len(label.encode())]) + label.encode() for label in value.split('.')) + b'\0'

def record(name, kind, data, ttl=120, unique=True):
    return dns_name(name) + struct.pack('!HHIH', kind, 0x8001 if unique else 1, ttl, len(data)) + data

def reply(ttl=120, message_id=0, enumerate_services=False):
    if enumerate_services:
        records = [record('_services._dns-sd._udp.local', 12, dns_name(service), ttl, False)]
    else:
        records = [
            record(service, 12, dns_name(instance), ttl, False),
            record(instance, 33, struct.pack('!HHH', 0, 0, 6466) + dns_name(host), ttl),
            record(instance, 16, b'\x14bt=3C:5A:B4:01:02:03', ttl),
            record(host, 1, socket.inet_aton(lan_ip), ttl),
        ]
    return struct.pack('!6H', message_id, 0x8400, 0, len(records), 0, 0) + b''.join(records)

def read_name(packet, offset, depth=0):
    if depth > 12:
        raise ValueError('DNS compression loop')
    labels = []
    while True:
        size = packet[offset]
        offset += 1
        if size == 0:
            return '.'.join(labels), offset
        if size & 0xC0 == 0xC0:
            pointer = ((size & 0x3F) << 8) | packet[offset]
            suffix, _ = read_name(packet, pointer, depth + 1)
            labels.append(suffix)
            return '.'.join(labels), offset + 1
        if size > 63:
            raise ValueError('Invalid DNS label')
        labels.append(packet[offset:offset + size].decode('utf-8'))
        offset += size

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 255)
sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_IF, socket.inet_aton(lan_ip))
sock.bind(('', 5353))
sock.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP, socket.inet_aton(group[0]) + socket.inet_aton(lan_ip))
sock.settimeout(1)
print(f'Publishing {instance} at {lan_ip}:6466', flush=True)
next_announcement = 0
try:
    while running:
        if time.monotonic() >= next_announcement:
            sock.sendto(reply(), group)
            next_announcement = time.monotonic() + 60
        try:
            packet, peer = sock.recvfrom(9000)
        except TimeoutError:
            continue
        try:
            message_id, flags, count, *_ = struct.unpack_from('!6H', packet)
            if flags & 0x8000:
                continue
            offset = 12
            for _ in range(min(count, 64)):
                name, offset = read_name(packet, offset)
                kind, qclass = struct.unpack_from('!HH', packet, offset)
                offset += 4
                if name.lower() not in (service.lower(), instance.lower(), host.lower(), '_services._dns-sd._udp.local'):
                    continue
                destination = peer if (qclass & 0x8000 or peer[1] != 5353) else group
                sock.sendto(reply(message_id=message_id if peer[1] != 5353 else 0,
                                  enumerate_services=name.lower() == '_services._dns-sd._udp.local'), destination)
        except (ValueError, IndexError, UnicodeDecodeError, struct.error):
            continue
finally:
    sock.sendto(reply(ttl=0), group)
    sock.close()
