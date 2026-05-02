#!/usr/bin/env python3
"""Extract a 32KB binary from the a2u12.asm disassembly listing."""
import re, sys

rom = bytearray(32768)
with open(sys.argv[1] if len(sys.argv) > 1 else "a2u12.asm") as f:
    for line in f:
        m = re.match(r'([0-9a-fA-F]{4}):\s+((?:[0-9a-fA-F]{2}\s)+)', line)
        if m:
            addr = int(m.group(1), 16)
            for i, hb in enumerate(m.group(2).strip().split()):
                offset = addr + i
                if 0 <= offset < 32768:
                    rom[offset] = int(hb, 16)

out = sys.argv[2] if len(sys.argv) > 2 else "a2u12.bin"
with open(out, "wb") as f:
    f.write(rom)
print(f"Wrote {len(rom)} bytes to {out}")
