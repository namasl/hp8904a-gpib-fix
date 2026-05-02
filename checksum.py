#!/usr/bin/env python3
"""
Compute and fix the HP 8904A A2U12 ROM checksum.

The self-test routine at $5CA9 computes:

    X = $7FFF; B = 0; C = 0 (CLRB clears carry)
    loop:
        X = X + 1           (LEAX — does NOT affect carry)
        B = B + [X] + C     (ADCB — add with carry)
        CMPX #$FFFF         (OVERWRITES carry: C=1 if X<$FFFF, C=0 if X=$FFFF)
        BNE loop

    result: B must equal 0

Because CMPX overwrites the ADCB carry every iteration, the carry fed
into each ADCB is always 1 — except for the very first byte ($8000)
which gets carry=0 from CLRB.

This simplifies to:
    (sum_of_all_32768_bytes + 32767) mod 256 == 0
i.e.
    sum_of_all_bytes mod 256 == 1
"""

import re
import sys

def extract_rom_bytes(asm_path):
    """Parse the .asm listing and extract all 32768 ROM bytes."""
    rom = bytearray(32768)
    filled = set()

    with open(asm_path) as f:
        for line in f:
            # Format: "ADDR: HH HH HH ...    MNEMONIC"
            m = re.match(r'([0-9a-fA-F]{4}):\s+((?:[0-9a-fA-F]{2}\s)+)', line)
            if not m:
                continue
            addr = int(m.group(1), 16)
            hex_bytes = m.group(2).strip().split()
            for i, hb in enumerate(hex_bytes):
                offset = addr + i
                if 0 <= offset < 32768:
                    rom[offset] = int(hb, 16)
                    filled.add(offset)

    return rom, filled


def compute_checksum(rom):
    """
    Reproduce the 6809 ADCB checksum exactly.

    Because CMPX overwrites carry each iteration:
      - byte at offset 0 ($8000): carry_in = 0
      - bytes at offsets 1..32767: carry_in = 1
    """
    b = 0
    for i in range(32768):
        carry_in = 0 if i == 0 else 1
        temp = b + rom[i] + carry_in
        b = temp & 0xFF
    return b


def main():
    asm_path = sys.argv[1] if len(sys.argv) > 1 else "a2u12.asm"

    print(f"Reading {asm_path}...")
    rom, filled = extract_rom_bytes(asm_path)
    print(f"  Extracted {len(filled)} byte positions out of 32768")

    # Show the patched area
    print(f"\nBytes at $2ACC-$2AD4 (patched area):")
    print(f"  {' '.join(f'{rom[0x2ACC+i]:02X}' for i in range(9))}")

    # Compute current checksum
    cksum = compute_checksum(rom)
    print(f"\nCurrent checksum result: ${cksum:02X} ({'PASS' if cksum == 0 else 'FAIL'})")

    if cksum == 0:
        print("Checksum already passes — no compensation needed.")
        return

    # The simple sum condition: sum mod 256 must equal 1
    byte_sum = sum(rom) % 256
    print(f"Simple byte sum mod 256: ${byte_sum:02X} (need $01)")

    # Find compensation byte in the $FF padding area ($7FCF-$7FEF)
    # These are unused bytes between the halt loop at $7FCD and vectors at $7FF0
    padding_start = 0x7FCF
    padding_end = 0x7FEF

    print(f"\nPadding area ${padding_start:04X}-${padding_end:04X}:")
    print(f"  {' '.join(f'{rom[padding_start+i]:02X}' for i in range(min(16, padding_end-padding_start+1)))}")

    # Calculate needed compensation
    # We need: (current_sum + delta) mod 256 == 1
    # delta = (1 - byte_sum) mod 256
    delta = (1 - byte_sum) % 256
    print(f"\nNeed to increase byte sum by ${delta:02X} ({delta} decimal)")

    # Change byte at padding_start from its current value
    comp_offset = padding_start
    old_val = rom[comp_offset]
    new_val = (old_val + delta) & 0xFF
    print(f"Compensation: change byte at ${comp_offset:04X} from ${old_val:02X} to ${new_val:02X}")

    # Apply and verify
    rom[comp_offset] = new_val
    cksum2 = compute_checksum(rom)
    print(f"\nAfter compensation, checksum: ${cksum2:02X} ({'PASS' if cksum2 == 0 else 'FAIL'})")

    if cksum2 == 0:
        print(f"\n=== SUMMARY ===")
        print(f"To fix the checksum, change the byte at ROM offset ${comp_offset:04X}")
        print(f"  from ${old_val:02X} to ${new_val:02X}")
        print(f"In the .asm file, this is the line starting with '{comp_offset:04x}:'")
    else:
        print("ERROR: compensation failed, manual investigation needed")


if __name__ == "__main__":
    main()
