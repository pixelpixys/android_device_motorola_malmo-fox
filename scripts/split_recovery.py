#!/usr/bin/env python3
#
# split_recovery.py — Combines a lean boot/recovery image with an EROFS payload
# into a 128MB recovery partition for Motorola Moto G85 5G (malmo).
#

import os
import sys

OFFSET = 33554432       # 32 MB offset
TOTAL_SIZE = 134217728  # 128 MB partition size

def main():
    if len(sys.argv) < 4:
        print(f"Usage: {sys.argv[0]} <bootimg_path> <erofs_path> <output_path>")
        sys.exit(1)

    bootimg_path = sys.argv[1]
    erofs_path = sys.argv[2]
    output_path = sys.argv[3]

    if not os.path.exists(bootimg_path):
        raise FileNotFoundError(f"Boot image not found: {bootimg_path}")
    if not os.path.exists(erofs_path):
        raise FileNotFoundError(f"EROFS image not found: {erofs_path}")

    with open(bootimg_path, 'rb') as fb:
        boot_data = fb.read()

    boot_len = len(boot_data)
    if boot_len > OFFSET:
        raise ValueError(f"Boot image exceeds offset: {boot_len} > {OFFSET}")

    with open(erofs_path, 'rb') as fe:
        erofs_data = fe.read()

    erofs_len = len(erofs_data)
    if OFFSET + erofs_len > TOTAL_SIZE:
        raise ValueError(f"EROFS image too large: {OFFSET + erofs_len} > {TOTAL_SIZE}")

    with open(output_path, 'wb') as fo:
        fo.write(boot_data)
        fo.write(b'\x00' * (OFFSET - boot_len))
        fo.write(erofs_data)
        fo.write(b'\x00' * (TOTAL_SIZE - (OFFSET + erofs_len)))

    print(f"[+] Successfully assembled {output_path} ({os.path.getsize(output_path)} bytes)")

if __name__ == '__main__':
    main()
