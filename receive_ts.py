#!/usr/bin/env python
import sys, os, socket, random, struct, time
import binascii, uuid, json
from datetime import datetime
import calendar
import argparse

from scapy.all import sniff, sendp, send, hexdump, get_if_list, get_if_hwaddr, bind_layers
from scapy.all import Packet, IPOption
from scapy.all import PacketListField, ShortField, IntField, LongField, BitField, FieldListField, FieldLenField, ByteField
from scapy.all import Ether, IP, UDP, TCP, Raw
from scapy.layers.inet6 import IPv6
from scapy.fields import *

from binascii import hexlify

SRC = 0
DST = 1
DSCP = 2

BOS = 0
LABEL1 = 1

ICMP_PROTO = 1
TCP_PROTO = 6
UDP_PROTO = 17

MAC_ENO3 = "ac:1f:6b:62:b9:66"
MAC_ENO4 = "ac:1f:6b:62:b9:67"
MAC_PD   = "dd:aa:bb:ee:ff:aa"

parser = argparse.ArgumentParser(description='Process some parameters')

parser.add_argument('-e', '--ethernet', type=str, help='Ethernet src/dst addresses')
parser.add_argument('-m', '--mpls', type=str, help='Enable MPLS header and add parameters')
parser.add_argument('-i', '--ip', type=str, help='Add IPv4 parameters')
parser.add_argument('-t', '--tcp', type=int, action='store', help='Enable TCP header and add parameters')
parser.add_argument('-u', '--udp', type=int, action='store', help='Enable UDP header and add parameters')
parser.add_argument('-p', '--packets', type=int, action='store', help='Number of packets to send')
parser.add_argument('-b', '--bytes', type=int, action='store', help='Bytes for the payload')
parser.add_argument('-r', '--randbytes', const=True, action='store_const',  help='Add random bytes to the payload')
parser.add_argument('-f', '--filename', type=str, help='Path for the filename')
parser.add_argument('-x', '--filter', type=str, help='Filter criteria')
parser.add_argument('-c', '--interface', type=str, help='Name of the interface to send the packet to')

args = parser.parse_args()

class PORTDOWN(Packet):
    name = "PORTDOWN"
    fields_desc = [
        BitField("pad1", 0, 3), #name, default, size
        BitField("pipe_id", 0, 2),
        BitField("app_id", 0, 3),
        BitField("pad2", 0, 15),
        BitField("port_num", 0, 9),
        BitField("packet_id", 0, 16)
    ]
class TS_INGRESS(Packet):
    name = "TS_INGRESS"
    fields_desc = [
        BitField("ts2", 0, 32),
        BitField("ts1", 0, 32),
        BitField("ts4", 0, 32),
        BitField("ts3", 0, 32)
    ]


bind_layers(Ether, PORTDOWN, type=0x1113)
bind_layers(PORTDOWN,TS_INGRESS)


def get_if():
    ifs=get_if_list()
    iface=None
    for i in get_if_list():
        if args.interface in i:
            iface=i
            break;
    if not iface:
        print("Cannot find  interface")
        exit(1)
    return iface

def handle_pkt(packet, flows, counters):

    info = { }

    info["rec_time"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")

    pkt = bytes(packet)
    print ("## PACKET RECEIVED ##")

    eth_h = None
    packetPayload = None

    ETHERNET_HEADER_LENGTH = 14 # bytes
    PORTDOWN_HEADER_LENGTH = 6
    TS_INGRESS_HEADER_LENGHT = 16

    ETHERNET_OFFSET = 0 + ETHERNET_HEADER_LENGTH
    PORTDOWN_OFFSET = ETHERNET_OFFSET + PORTDOWN_HEADER_LENGTH
    TS_INGRESS_OFFSET = PORTDOWN_OFFSET + TS_INGRESS_HEADER_LENGHT

    eth_h = Ether(pkt[0:ETHERNET_OFFSET])
    pd_h = PORTDOWN(pkt[ETHERNET_OFFSET:PORTDOWN_OFFSET])
    ts_h = TS_INGRESS(pkt[PORTDOWN_OFFSET:TS_INGRESS_OFFSET])
    eth_h.show()
    pd_h.show()
    ts_h.show()

    sys.stdout.flush()
    print(f'FRT_1={ts_h.ts2-ts_h.ts1} ns')
    print(f'FRT_2={ts_h.ts4-ts_h.ts3} ns')

    f = open ('timestampDP.txt', 'a')
    f.write(f'ts1={ts_h.ts1}\n')
    f.write(f'ts2={ts_h.ts2}\n')
    f.write(f'ts3={ts_h.ts3}\n')
    f.write(f'ts4={ts_h.ts4}\n')
    f.write(f'FRT_1={ts_h.ts2-ts_h.ts1}\n')
    f.write(f'FRT_2={ts_h.ts4-ts_h.ts3}\n')
    f.close()

def main():
    flows = {}
    counters = {}

    print("sniffing on %s" % args.interface)
    sys.stdout.flush()
    sniff(
        lfilter = lambda d: d.dst == MAC_PD,#'aa:bb:cc:dd:ee:ff',
        iface = args.interface,
        prn = lambda x: handle_pkt(x, flows, counters))

if __name__ == '__main__':
    main()
