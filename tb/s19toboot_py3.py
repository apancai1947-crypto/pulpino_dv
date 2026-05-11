#!/usr/bin/env python3
# Ported from s19toboot.py (Python 2) to Python 3

import sys
import math
import os

if len(sys.argv) < 2:
    print("Usage s19toboot_py3.py FILENAME")
    quit()

rom_size      = 1024  # in words (32 bit) — max for 10-bit A port
rom_start     = 0x00008000
rom_end       = rom_start + rom_size * 4 - 1


def s19_parse(filename, s19_dict):
    s19_file = open(filename, 'r')
    for line in s19_file:
        line = line.strip()
        if not line or not line.startswith('S'):
            continue

        rec_type = line[0:2]
        # Skip header (S0), count (S5), and termination (S7/S8/S9) records
        if rec_type in ('S0', 'S5', 'S7', 'S8', 'S9'):
            continue

        # S1/S2/S3 records: type(2) + byte_count(2) + address(4/6/8) + data + checksum(2)
        byte_count = int(line[2:4], 16)
        if rec_type == 'S1':
            addr_hex_len = 4  # 2 bytes = 4 hex chars
        elif rec_type == 'S2':
            addr_hex_len = 6  # 3 bytes
        elif rec_type == 'S3':
            addr_hex_len = 8  # 4 bytes
        else:
            continue

        addr_str = line[4:4 + addr_hex_len]
        addr = int(addr_str, 16)

        # Data starts after type + count + address, ends before checksum
        data_start = 4 + addr_hex_len
        data_end = len(line) - 2  # exclude 2-char checksum
        data_hex = line[data_start:data_end]

        # Parse each data byte
        for i in range(0, len(data_hex), 2):
            s19_dict[addr + (i // 2)] = data_hex[i:i + 2]

    s19_file.close()


def bytes_to_words(byte_dict, word_dict):
    for addr in byte_dict:
        wordaddr = addr >> 2
        data = "00000000"

        if wordaddr in word_dict:
            data = word_dict[wordaddr]

        byte = addr % 4
        byte0 = data[0:2]
        byte1 = data[2:4]
        byte2 = data[4:6]
        byte3 = data[6:8]
        new   = byte_dict[addr]

        if byte == 0:
            data = "%s%s%s%s" % (byte0, byte1, byte2, new)
        elif byte == 1:
            data = "%s%s%s%s" % (byte0, byte1, new, byte3)
        elif byte == 2:
            data = "%s%s%s%s" % (byte0, new, byte2, byte3)
        elif byte == 3:
            data = "%s%s%s%s" % (new, byte1, byte2, byte3)

        word_dict[wordaddr] = data


s19_dict = {}
slm_dict = {}

s19_parse(sys.argv[1], s19_dict)

# fill slm_dict with 0's
for wordaddr in range(rom_start >> 2, (rom_end >> 2) + 1):
    slm_dict[wordaddr] = "00000000"

bytes_to_words(s19_dict, slm_dict)

# word align all addresses
rom_start = rom_start >> 2
rom_end   = rom_end >> 2

addr_width = int(math.log(rom_size, 2))

# Build the SV content as a list of lines
lines = []
lines.append("")
lines.append("module boot_code")
lines.append("(")
lines.append("    input  logic        CLK,")
lines.append("    input  logic        RSTN,")
lines.append("")
lines.append("    input  logic        CSN,")
lines.append("    input  logic [%d:0]  A," % addr_width)
lines.append("    output logic [31:0] Q")
lines.append("  );")
lines.append("")
lines.append("  const logic [0:%d] [31:0] mem = {" % (rom_size - 1))

# Collect data entries
data_lines = []
for addr in sorted(slm_dict.keys()):
    data = slm_dict[addr]
    if addr >= rom_start and addr <= rom_end:
        data_lines.append("    32'h%s" % data)

# Join with commas (last entry has no trailing comma)
lines.append(",\n".join(data_lines))
lines.append("};")
lines.append("")
lines.append("  logic [%d:0] A_Q;" % addr_width)
lines.append("")
lines.append("  always_ff @(posedge CLK, negedge RSTN)")
lines.append("  begin")
lines.append("    if (~RSTN)")
lines.append("      A_Q <= '0;")
lines.append("    else")
lines.append("      if (~CSN)")
lines.append("        A_Q <= A;")
lines.append("  end")
lines.append("")
lines.append("  assign Q = mem[A_Q];")
lines.append("")
lines.append("endmodule")

# Write files
rom_file = open("boot_code.cde", 'w')
rom_file.close()

vlog_file = open("boot_code.sv", 'w')
vlog_file.write("\n".join(lines))
vlog_file.close()

# Generate hex file for $readmemh
hex_file = open("boot_code.hex", 'w')
for addr in sorted(slm_dict.keys()):
    if addr >= rom_start and addr <= rom_end:
        hex_file.write("%s\n" % slm_dict[addr])
hex_file.close()

print("Generated boot_code.sv and boot_code.hex (%d words)" % rom_size)
