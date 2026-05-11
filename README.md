# PULPino DV — RISC-V SoC Verification Workspace

A UVM-based verification environment for the [PULPino](https://github.com/pulp-platform/pulpino) RISC-V SoC from ETH Zurich / PULP platform.

`repo/pulpino/` is a git submodule containing the original RTL; all verification code lives in the outer workspace.

## Supported Cores

| Core | Pipeline | ISA | Use Case |
|------|----------|-----|----------|
| **RISCY** | 4-stage | RV32IMF + PULP extensions | Performance |
| **zero-riscy** | 2-stage | RV32IMC | Ultra-low-area |

Selected via `USE_ZERO_RISCY` parameter (0=RISCY, 1=zero-riscy).

## Quick Start

### Prerequisites

- Synopsys VCS (simulator)
- Synopsys SVT VIPs:
  - UART (`svt_uart`)
  - SPI (`svt_spi`)
  - I2C, GPIO (optional)
- `riscv64-linux-gnu-gcc` toolchain
- Python 3.6+

### Run Tests

```bash
# List all available tests
python sim/run_case.py --list

# Run a single UART test
python sim/run_case.py tc_uart_tx_single_test

# Run SPI parameterized tests
python sim/run_case.py tc_spi_data_transfer

# Run all tests with a specific tag
python sim/run_case.py --tag spi

# Parallel jobs (default 10)
python sim/run_case.py tc_uart_hello_test -j 4
```

### Legacy Makefile Flow

```bash
cd sim
make fw    # compile C firmware
make comp  # VCS compile
make sim   # run simulation
make dump  # run with FSDB waveform
make verdi # open Verdi viewer
```

## Architecture

### Two-Layer Test System

| Layer | Language | Location | Purpose |
|-------|----------|----------|---------|
| **Python case manager** | Python | `sim/case_manager/` + `test/*.py` | Build/Test classes, VCS compile, parallel sim, results |
| **UVM test classes** | SystemVerilog | `tests/*.sv` | UVM test logic: env setup, stimulus, checking |

### Test Data Flow

```
python sim/run_case.py <test_spec>
  -> discovers test/*.py -> Build + Test classes
  -> auto-generates firmware: make -C c CTEST=<c_test> -> firmware.slm
  -> VCS compiles RTL (sim/filelist.f) -> simv
  -> runs simv with +UVM_TESTNAME + plusargs
     -> tb_top.sv: backdoor memory preload ($readmemh firmware.slm)
     -> CPU boots from 0x80, C firmware runs on RISC-V core
     -> Scoreboard: monitors bus activity or UART strings for PASS/FAIL
```

### SPI Boot Mode Flow

```
python sim/run_case.py tc_spi_boot --tag spi
  -> Build: spi_boot_build (defines SPI_VIP_EN + SPI_BOOT_EN)
  -> make -C c CTEST=tc_spi_boot BOOT_MODE=1 -> boot_image.memh
     -> elf2flash.py: ELF -> flat hex image with 32-byte header
  -> VCS compiles with SPI_BOOT_EN define
  -> runs simv:
     -> boot address NOT forced (uses default 0x8080 = Boot ROM entry)
     -> backdoor memory preload SKIPPED
     -> CPU boots from Boot ROM, runs boot_code.c
     -> check_spi_flash() sends READ_ID (0x9F) to Flash VIP
        -> SPI VIP returns 0x0102194D (Spansion S25FL128S ID)
     -> reads flash header, copies firmware to instr/data RAM
     -> jumps to user code -> prints "SPI Boot Successful!" -> EOT
```

### UVM Environment

```
soc_env
+-- axi_agent (core_master_agent)    <- Passive, monitors core2axi
+-- axi_agent (periph_slave_agent)   <- Passive, monitors peripherals
+-- apb_agent (apb_mon_agent)        <- Passive, monitors APB bus
+-- uart_mon                         <- Bit-level sampling for UART TUBE
+-- stdout_mon                       <- APB write monitor for printf debugging
+-- svt_uart_agent (dce_agent)       <- Synopsys SVT UART VIP
+-- svt_spi_agent (spi_master_agent) <- Synopsys SVT SPI VIP (Slave role)
+-- svt_spi_agent (spi_slave_agent)  <- Synopsys SVT SPI VIP (Master role)
+-- soc_scoreboard                   <- Global verification scoreboard
```

### Boot Sequence (Force-based, no JTAG)

1. `force boot_adr_q = 0x0000_0000` -- bypass JTAG
2. `$readmemh` backdoor loads firmware into DUT RAM
3. `fetch_enable = 1` -- CPU starts executing from `0x80`

### SPI Boot Sequence (Boot from Flash VIP)

1. Boot address uses default `0x8080` (Boot ROM entry) — not forced
2. Backdoor memory preload is **skipped**
3. CPU executes `boot_code.c` from Boot ROM
4. `check_spi_flash()` sends READ_ID (`0x9F`) to SPI Flash VIP — expects `0x0102194D`
5. Boot code reads flash header (32 bytes), copies firmware blocks to instr/data RAM
6. Jumps to user code (`instr_base = 0x00000000`, CPU address `0x80`)
7. User code runs and signals EOT via stdout monitor

### Boot ROM Build Toolchain

The Boot ROM is compiled from C source (`repo/pulpino/sw/apps/boot_code/boot_code.c`) using a RISC-V cross-compiler, then converted to a hex file for `$readmemh` loading:

```bash
# Run inside Docker container with riscv64-linux-gnu-gcc
docker exec <container> bash -c "cd /root/work/dv-flow/pulpino_dv/tb && bash build_boot_rom.sh"
```

Build pipeline:
1. Cross-compile `boot_code.c` + sys_lib (spi.c, uart.c, gpio.c) with `-march=rv32i -mabi=ilp32`
2. Link with `link.boot.ld` (ROM at 0x8000, max 8KB)
3. `objcopy` → S19 record file
4. `s19toboot_py3.py` → `boot_code.hex` (1024 words) + `boot_code.sv`

Key files:
| File | Purpose |
|------|---------|
| `tb/build_boot_rom.sh` | Cross-compile script (runs in Docker) |
| `tb/s19toboot_py3.py` | S19 → hex/sv converter (`rom_size=1024`) |
| `tb/boot_code.hex` | ROM content for `$readmemh` (1024 lines) |
| `tb/boot_code_patched.sv` | Patched ROM module using `$readmemh` (replaces repo's `boot_code.sv`) |

The patched `boot_code_patched.sv` replaces the repo's `boot_code.sv` via `sim/filelist.f`, using `$readmemh` to load `boot_code.hex` instead of hardcoding ROM contents in SystemVerilog.

## Project Structure

```
pulpino_dv/
+-- c/                    # C firmware for tests
|   +-- tests/uart_tests/ # UART test programs
|   +-- tests/spi_tests/  # SPI parameterized test programs
|   +-- tests/tc_spi_boot/# SPI Boot test firmware
|   +-- elf2flash.py      # ELF -> SPI flash image converter
|   +-- lib/retarget.c    # printf redirect, end_of_test()
+-- test/                 # Python Build/Test class definitions
+-- sim/
|   +-- run_case.py       # main entry for regression and debug
|   +-- case_manager/     # discovery, runner, and CLI logic
+-- tb/                   # UVM testbench structure
|   +-- env/              # soc_env, scoreboard, agents
|   +-- tb_top.sv         # testbench top (DUT, interfaces, boot sequence)
+-- tests/                # UVM test classes (.sv)
+-- repo/pulpino/         # git submodule (DO NOT MODIFY)
```

## Adding a New Test

1. Create firmware in `c/tests/<module>_tests/<name>/main.c`.
2. Add a Python Test class in `test/pulpino_<module>_test.py`.
3. Inherit from base classes to leverage parallel sim and auto-compilation.

## Key Configuration

| Parameter | Default | Notes |
|-----------|---------|-------|
| `USE_ZERO_RISCY` | 0 | 0=RISCY, 1=zero-riscy |
| `UART_DIVISOR` | 31 | Baud rate config |
| `TIMEOUT_NS` | 10000000 | Watchdog timeout |

## Key Defines

| Define | Set By | Purpose |
|--------|--------|---------|
| `+define+VERILATOR` | build system | Selects SV UART (`apb_uart_sv`) instead of VHDL UART |
| `+define+SPI_VIP_EN` | `spi_base_build` | Enables SPI VIP agents in UVM env |
| `+define+SPI_BOOT_EN` | `spi_boot_build` | Enables SPI boot mode (Flash VIP, skip backdoor load) |
| `+define+TRACE_PC` | build system | Enables PC tracing in `tb_top` for debug |
| `+define+FSDB_DUMP` | `--dump` flag | Enables FSDB waveform dump via Verdi |

## SPI Flash VIP Integration Notes

When configuring the SPI VIP as a Flash slave for boot mode, the Flash ID must be set via the **catalog system** — direct field assignment alone does not work:

```systemverilog
// Load Spansion catalog first (initializes Flash model internals)
spi_cfg.spi_mem_cfg.load_prop_vals({dw_home, "/vip/svt/spi_svt/latest/catalog/spi/nor/Spansion/S25FL512S_HPLC.cfg"});
// Then override ID fields for target chip
spi_cfg.spi_mem_cfg.mode_register_cfg.manufacturer_id        = 8'h01;
spi_cfg.spi_mem_cfg.mode_register_cfg.device_id_memory_type  = 8'h02;
spi_cfg.spi_mem_cfg.mode_register_cfg.device_id_memory_capacity = 8'h19;
spi_cfg.spi_mem_cfg.mode_register_cfg.device_id              = 8'h4D;
```

See `doc/synopsys_svt_qspi_vip_general_guide.md` §7 for full details.

## Rules

- **Do not** modify files within `repo/pulpino/`. All verification work goes in the outer workspace.
