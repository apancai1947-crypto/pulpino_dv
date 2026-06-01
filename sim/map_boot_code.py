import struct, re

with open("/root/work/dv-flow/pulpino_dv/repo/pulpino/rtl/boot_code.sv", encoding="utf-8", errors="replace") as f:
    content = f.read()

hexvals = re.findall(r"32'h([0-9A-Fa-f]+)", content)
base = 0x8000

jal_targets = set()
ret_addrs = []
prologues = {}

for i, h in enumerate(hexvals):
    addr = base + i * 4
    val = int(h, 16)
    opcode = val & 0x7F

    if opcode == 0x6F:
        rd = (val >> 7) & 0x1F
        if rd == 1:
            imm20 = (val >> 31) & 1
            imm10_1 = (val >> 21) & 0x3FF
            imm11 = (val >> 20) & 1
            imm19_12 = (val >> 12) & 0xFF
            imm = (imm20 << 20) | (imm19_12 << 12) | (imm11 << 11) | (imm10_1 << 1)
            if imm & (1 << 20):
                imm -= (1 << 21)
            target = addr + imm
            jal_targets.add(target)

    if val == 0x00008067:
        ret_addrs.append(addr)

    if (val & 0xFFFFF07F) == 0xFF010113:
        imm = (val >> 20) & 0xFFF
        if imm & 0x800:
            imm = imm - 0x1000
        if imm < 0:
            prologues[addr] = -imm

# Known function names from v1.0.16 compilation (matching by order and MMIO)
# These are approximate - exact addresses differ but order should match
ref_names = [
    (0x808C, "_stext (default_exc_handler)"),
    (0x8090, "reset_handler"),
    (0x8114, "_start (BSS clear)"),
    (0x8134, "main_entry"),
    (0x8140, "check_spi_flash"),
    (0x81C4, "load_block"),
    (0x8220, "jump_and_start"),
    (0x8234, "uart_send_block_done"),
    (0x82A4, "spi_setup_slave"),
    (0x82F0, "spi_setup_master"),
    (0x838C, "spi_setup_cmd_addr"),
    (0x83D0, "spi_setup_dummy"),
    (0x83E0, "spi_set_datalen"),
    (0x8410, "spi_start_transaction"),
    (0x8440, "spi_get_status"),
    (0x845C, "spi_write_fifo"),
    (0x84D8, "spi_read_fifo"),
    (0x8554, "uart_set_cfg"),
    (0x85B0, "uart_send"),
    (0x85E8, "uart_getchar"),
    (0x8608, "uart_sendchar"),
    (0x8624, "uart_wait_tx_done"),
    (0x863C, "set_pin_function"),
    (0x8684, "get_pin_function"),
    (0x86B0, "set_gpio_pin_direction"),
    (0x8710, "get_gpio_pin_direction"),
    (0x8740, "set_gpio_pin_value"),
    (0x87A0, "get_gpio_pin_value"),
    (0x87CC, "set_gpio_pin_irq_en"),
    (0x87F8, "set_gpio_pin_irq_type"),
    (0x8854, "get_gpio_irq_status"),
    (0x8860, "eoc"),
    (0x88C0, "exit"),
    (0x88D0, "sleep_busy"),
    (0x88FC, "cpu_perf_set"),
    (0x8908, "cpu_perf_get"),
    (0x89CC, "qprinti"),
    (0x8D58, "putchar"),
    (0x8D84, "printf"),
    (0x9620, "puts"),
    (0x967C, "strcmp"),
    (0x96C0, "strcpy"),
    (0x96E0, "strlen"),
    (0x971C, "main"),
]

print("=== Existing boot_code.sv: Function Map ===")
print()

# Find actual function entries in the existing boot_code.sv
sorted_targets = sorted(jal_targets)
print("JAL call targets (function entries):")
for t in sorted_targets:
    if t >= base and t < base + len(hexvals) * 4:
        idx = (t - base) // 4
        frame = prologues.get(t, 0)
        print("  0x%08X [%3d] frame=%d" % (t, idx, frame))

print()
print("ret instructions at:")
for r in ret_addrs:
    idx = (r - base) // 4
    print("  0x%08X [%3d]" % (r, idx))

print()
print("=== Key landmark instructions ===")
for i, h in enumerate(hexvals):
    addr = base + i * 4
    val = int(h, 16)
    opcode = val & 0x7F

    # Stack init: auipc sp, 0x100
    if val == 0x00100117:
        print("  0x%08X: auipc sp, 0x100  (stack init)" % addr)
    # Stack init follow-up
    elif val == 0xEF410113:
        print("  0x%08X: addi sp, sp, -268  (stack init cont)" % addr)
    # main_entry: li a0, 0; li a1, 0
    elif val == 0x00000513 and i > 60:
        # Check if next is li a1, 0
        if i+1 < len(hexvals) and int(hexvals[i+1], 16) == 0x00000593:
            print("  0x%08X: main_entry (argc=0, argv=0)" % addr)
    # SPI command 0x9F (READ_ID)
    elif (val >> 20) == 0x09F and (val & 0x7F) == 0x13:
        print("  0x%08X: li a0, 0x9F  (SPI READ_ID cmd)" % addr)
    # UART printf string references
