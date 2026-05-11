#!/bin/bash
# Build boot ROM from boot_code.c source
# Run inside Docker container with riscv64-linux-gnu-gcc

set -e

PULPINO=/root/work/dv-flow/pulpino_dv/repo/pulpino
WORK=/root/work/dv-flow/pulpino_dv/tb/boot_build
TB_DIR=/root/work/dv-flow/pulpino_dv/tb

CC=riscv64-linux-gnu-gcc
OBJCOPY=riscv64-linux-gnu-objcopy

CFLAGS="-march=rv32i -mabi=ilp32 -O2 -ffreestanding -nostdlib -DBOOT -D__riscv__"
INC="-I${PULPINO}/sw/libs/sys_lib/inc -I${PULPINO}/sw/libs/string_lib/inc"

mkdir -p ${WORK}
cd ${WORK}

echo "=== Step 1: Compile crt0.boot.S ==="
${CC} ${CFLAGS} ${INC} -c ${PULPINO}/sw/ref/crt0.boot.S -o crt0_boot.o

echo "=== Step 2: Compile sys_lib sources ==="
for src in spi.c uart.c gpio.c; do
    echo "  Compiling ${src}..."
    ${CC} ${CFLAGS} ${INC} -c ${PULPINO}/sw/libs/sys_lib/src/${src} -o ${src%.c}.o
done

echo "=== Step 3: Create libsys.a ==="
${CC%-gcc}-ar rcs libsys.a spi.o uart.o gpio.o

echo "=== Step 4: Compile boot_code.c ==="
${CC} ${CFLAGS} ${INC} -c ${PULPINO}/sw/apps/boot_code/boot_code.c -o boot_code.o

echo "=== Step 5: Link ==="
${CC} -march=rv32i -mabi=ilp32 -ffreestanding -nostdlib \
    -T ${PULPINO}/sw/ref/link.boot.ld \
    -nostartfiles -Wl,--gc-sections -Wl,--build-id=none \
    crt0_boot.o boot_code.o -L. -lsys -lgcc -o boot_code.elf

echo "=== Step 6: Generate S19 ==="
${OBJCOPY} --srec-len 1 --output-target=srec boot_code.elf boot_code.s19

echo "=== Step 7: Convert to SystemVerilog ==="
cd ${TB_DIR}
python3 ${TB_DIR}/s19toboot_py3.py ${WORK}/boot_code.s19

echo "=== Done ==="
echo "Generated: ${TB_DIR}/boot_code.sv"
wc -l ${TB_DIR}/boot_code.sv
