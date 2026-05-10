#!/usr/bin/env python3
import sys
import os
import struct

def pad_to_4kb(data):
    padding_size = (4096 - (len(data) % 4096)) % 4096
    return data + b'\x00' * padding_size

def main():
    if len(sys.argv) < 4:
        print("Usage: elf2flash.py <instr_bin> <data_bin> <output_hex>")
        sys.exit(1)

    instr_bin_path = sys.argv[1]
    data_bin_path = sys.argv[2]
    output_hex_path = sys.argv[3]

    with open(instr_bin_path, 'rb') as f:
        instr_data = f.read()
    
    with open(data_bin_path, 'rb') as f:
        data_data = f.read()

    # Align to 4KB blocks as expected by boot_code.c
    instr_data_padded = pad_to_4kb(instr_data)
    data_data_padded = pad_to_4kb(data_data)

    instr_blocks = len(instr_data_padded) // 4096
    data_blocks = len(data_data_padded) // 4096

    # Flash Layout:
    # 0x00: Header (32 bytes / 8 words)
    # 0x20: Instruction Data
    # 0x20 + len(instr_data_padded): Data Data

    instr_start = 32
    instr_base = 0x00000000
    instr_size = len(instr_data)

    data_start = instr_start + len(instr_data_padded)
    data_base = 0x00100000
    data_size = len(data_data)

    # Header: 8 words (little-endian for the boot_code.c read_fifo)
    # Wait, PULPino SPI is usually MSB first, and spi_read_fifo fills words.
    # boot_code.c: int header_ptr[8]; spi_read_fifo(header_ptr, 8 * 32);
    # We should output words in the format $readmemh expects.
    # $readmemh expects 32-bit hex values.
    
    header = [
        instr_start,
        instr_base,
        instr_size,
        instr_blocks,
        data_start,
        data_base,
        data_size,
        data_blocks
    ]

    with open(output_hex_path, 'w') as f:
        # Write header (8 words, each word as 4 bytes in little-endian)
        for val in header:
            # Output 4 bytes for each 32-bit word, LSB first
            f.write(f"{(val >> 0) & 0xFF:02x}\n")
            f.write(f"{(val >> 8) & 0xFF:02x}\n")
            f.write(f"{(val >> 16) & 0xFF:02x}\n")
            f.write(f"{(val >> 24) & 0xFF:02x}\n")
        
        # Write instruction and data (already byte sequences)
        def write_data_bytes(data):
            for b in data:
                f.write(f"{b:02x}\n")

        write_data_bytes(instr_data_padded)
        write_data_bytes(data_data_padded)

    print(f"Flash image generated: {output_hex_path}")
    print(f"  Instr: {instr_size} bytes ({instr_blocks} blocks) at Flash 0x{instr_start:x}")
    print(f"  Data:  {data_size} bytes ({data_blocks} blocks) at Flash 0x{data_start:x}")

if __name__ == "__main__":
    main()
