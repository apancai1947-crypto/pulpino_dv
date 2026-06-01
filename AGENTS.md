# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## What This Is

UVM-based verification environment for the PULPino RISC-V SoC (ETH Zurich / PULP platform). RTL lives in `repo/pulpino/` as a read-only git submodule — all verification code stays in the outer workspace.

## Common Commands

**Primary test runner** (run from project root):
```bash
python sim/run_case.py --list                         # list all tests
python sim/run_case.py tc_uart_tx_single_test         # run one test
python sim/run_case.py tc_spi_boot --tag spi          # run by tag
python sim/run_case.py tc_uart_hello_test -j 4        # parallel jobs
python sim/run_case.py tc_uart_hello_test --dump      # FSDB waveform dump
python sim/run_case.py tc_uart_hello_test --dry-run   # preview commands only
```

**Legacy Makefile flow** (from `sim/`):
```bash
make fw    # compile C firmware only
make comp  # VCS compile only
make sim   # run simulation only
make dump  # run with FSDB waveform
make verdi # open Verdi viewer
make all   # fw + comp + sim
make clean # remove build artifacts
```

**Single test via Makefile**: `make sim TEST=pulpino_uart_test CTEST=tc_uart_hello`

## Architecture

### Two-Layer Test System

1. **Python case manager** (`sim/case_manager/` + `test/*.py`): `Build` class controls VCS compile options; `Test` class maps to a UVM test name + C firmware test. `InheritableMeta` metaclass enables `+=` on class attributes for clean inheritance. Discovery scans `test/` for `Build`/`Test` subclasses.

2. **UVM test classes** (`tests/*.sv`): Each extends `base_test`. The SV test sets up the UVM environment, connects VIP monitors, and waits for test completion.

### Test Data Flow

```
python sim/run_case.py <test_spec>
  -> discovers test/*.py -> Build + Test classes
  -> make -C c CTEST=<c_test> -> firmware.slm
  -> VCS compiles RTL (sim/filelist.f) -> simv
  -> runs simv with +UVM_TESTNAME + plusargs
     -> tb_top.sv: $readmemh loads firmware into DUT RAM
     -> CPU boots from 0x80, C firmware runs on RISC-V core
     -> stdout_monitor: monitors APB writes to 0x1A111000
     -> EOT (0x04) triggers eot_event -> test ends
     -> base_test report_phase prints PASS/FAIL
```

### SPI Boot Mode Flow (Boot from Flash VIP)

```
python sim/run_case.py tc_spi_boot --tag spi
  -> Build: spi_boot_build (defines SPI_VIP_EN + SPI_BOOT_EN)
  -> make -C c CTEST=tc_spi_boot BOOT_MODE=1 -> boot_image.memh
     -> elf2flash.py: ELF -> flat hex image with 32-byte header
  -> VCS compiles with SPI_BOOT_EN define
  -> runs simv:
     -> tb_top: boot address NOT forced (uses default 0x8080 = Boot ROM)
     -> tb_top: backdoor memory preload SKIPPED
     -> CPU boots from Boot ROM (0x8080), runs boot_code.c
     -> boot_code: check_spi_flash() sends READ_ID (0x9F) to Flash VIP
        -> SPI VIP (catalog-loaded S25FL512S + overridden IDs) returns 0x0102194D
     -> boot_code: reads flash header, copies firmware to instr/data RAM
     -> boot_code: jumps to user code (instr_base = 0x00000000)
     -> user code: prints "SPI Boot Successful!" -> EOT -> test passes
```

### Memory-Mapped I/O for TB Communication

- `0x1A111000` (STDOUT_ADDR): `printf()` output — 4 chars packed per word, parsed by `stdout_monitor`
- `0x1A111004` (RAW_DATA_REG): Raw data port for self-checking — `ref_data_send()` in `c/lib/spi_ext.c` writes reference data here, TB reads via `ref_data_ap`
- EOT character `0x04` signals test completion

### C Firmware Conventions

- Toolchain: `riscv64-linux-gnu-gcc -march=rv32i -mabi=ilp32`
- Linker script: `.vectors` at `0x0`, `.text` at `0x80`, stack at `0x2000`
- `c/lib/retarget.c`: redirects `printf` to memory-mapped stdout, provides `end_of_test()`
- Tests print `INFO:` prefixed messages; signal pass/fail with `TEST PASSED:` / `TEST FAILED:`
- Parameterized tests use compile-time macros (`-D` flags from `c_defines` in Python Test class)

### UVM Environment Structure

```
soc_env
├── axi_agent (core_master_agent)    — Passive, monitors core2axi
├── axi_agent (periph_slave_agent)   — Passive, monitors peripheral AXI
├── apb_agent (apb_mon_agent)        — Passive, monitors APB bus
├── uart_monitor                     — Bit-level UART TX sampling
├── stdout_monitor                   — APB write monitor for printf/EOT
├── svt_uart_agent (dce_agent)       — Synopsys SVT UART VIP (DCE role)
├── svt_spi_agent (spi_master_agent) — Synopsys SVT SPI VIP (slave role)
├── svt_spi_agent (spi_slave_agent)  — Synopsys SVT SPI VIP (master role)
└── soc_scoreboard                   — Global scoreboard
```

### Key Defines

| Define | Purpose |
|--------|---------|
| `+define+VERILATOR` | Selects SV UART (`apb_uart_sv`) instead of VHDL UART |
| `+define+SPI_VIP_EN` | Enables SPI VIP in UVM env (set by `spi_base_build`) |
| `+define+SPI_BOOT_EN` | Enables SPI boot mode (set by `spi_boot_build`) |
| `+define+TRACE_PC` | Enables PC tracing in `tb_top` |
| `+define+FSDB_DUMP` | Enables FSDB waveform dump |

## Adding a New Test

1. Create C firmware: `c/tests/<module>_tests/<name>/main.c`
2. Define Python Test class in `test/pulpino_<module>_test.py` — set `uvm_test`, `c_test`, `c_defines`, inherit from appropriate base
3. If a new UVM test is needed: create `tests/pulpino_<name>_test.sv`, extend `base_test`, add to `sim/filelist.f`

### SPI Boot Mode Details

When `SPI_BOOT_EN` is defined:
- **tb_top.sv**: Boot address is NOT forced to 0x0 (uses default 0x8080 = Boot ROM entry); backdoor memory preload is skipped; SPI APB monitor is enabled
- **soc_env.sv**: SPI Master VIP configured as Active Flash Slave with catalog-loaded Spansion model (`load_prop_vals`) and overridden Flash ID fields (`manufacturer_id=0x01, device_id_memory_type=0x02, device_id_memory_capacity=0x19, device_id=0x4D`)
- **pulpino_spi_boot_test.sv**: Loads `fw/boot_image.memh` into VIP memory via `backdoor.load()`
- **C firmware**: `c/tests/tc_spi_boot/main.c` — user code executed after boot_code copies it from flash
- **Image generator**: `c/elf2flash.py` — converts ELF to flat hex with 32-byte header (instr_start, instr_base, instr_size, instr_blocks, data_start, data_base, data_size, data_blocks)

## Key Constraints

- **Never modify** `repo/pulpino/` — it's a git submodule
- All paths in `sim/filelist.f` are relative to the project root
- The simulation environment runs inside Docker; `windows_docker_bridge.bat` proxies commands into the container
- Build hash caching in the runner means `simv` is only recompiled when build options change
- `svt_uart_agent` operates in DCE mode — it drives RX back to DUT, enabling loopback-style testing
- SPI VIP is conditionally compiled (gated by `SPI_VIP_EN` define)

## Known Environment Variables

| Variable | Purpose |
|----------|---------|
| `DESIGNWARE_HOME` | Synopsys VIP installation root |
| `SVT_VIP_BASE` | SVT VIP base path (default `/opt/sv_pkgs/uvm/svt_2018.09`) |
| `VCS_HOME` | VCS installation directory |
| `VERDI_HOME` | Verdi installation directory (for `--dump`) |
