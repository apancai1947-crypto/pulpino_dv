#!/bin/bash
set -e

SW=/root/work/dv-flow/pulpino_dv/repo/pulpino/sw
PRJ=/root/work/dv-flow/pulpino_dv
OUT=/tmp/boot_rom_build
mkdir -p $OUT

echo "=== Step 1: Compiling boot code ==="
riscv64-linux-gnu-gcc \
  -march=rv32ic -mabi=ilp32 -mcmodel=medany \
  -ffreestanding -O2 \
  -DBOOT -D__riscv__ \
  -Wl,--build-id=none \
  -I$SW/libs/sys_lib/inc \
  -T $SW/ref/link.boot.ld \
  -nostartfiles -nostdlib \
  $SW/ref/crt0.boot.S \
  $PRJ/sw_overlay/boot_code.c \
  $SW/libs/sys_lib/src/spi.c \
  $SW/libs/sys_lib/src/uart.c \
  $SW/libs/sys_lib/src/gpio.c \
  -o $OUT/boot_code.elf

echo "=== Step 2: Extracting S19 ==="
riscv64-linux-gnu-objcopy -O srec $OUT/boot_code.elf $OUT/boot_code.s19

echo "=== Step 3: Generating boot_code.sv with python3 ==="
cd $OUT
python3 $PRJ/scripts/s19toboot_py3.py boot_code.s19

echo "=== Step 4: Copying generated boot_code.sv to overlay rtl/ ==="
mkdir -p $PRJ/rtl
cp $OUT/boot_code.sv $PRJ/rtl/boot_code.sv

echo "=== Boot Code ROM built successfully! ==="
