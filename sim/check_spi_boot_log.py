#!/usr/bin/env python3
"""Check whether the SPI boot log shows a real Flash VIP response."""

import re
import sys
from pathlib import Path


def fail(message: str) -> int:
    print(f"FAIL: {message}")
    return 1


def main() -> int:
    if len(sys.argv) != 2:
        return fail("usage: check_spi_boot_log.py <simv.log>")

    log_path = Path(sys.argv[1])
    if not log_path.exists():
        return fail(f"log file does not exist: {log_path}")

    text = log_path.read_text(errors="replace")
    if "TRACE_PC" in text:
        return fail("PC trace is still enabled")

    if "SPI flash cfg valid=1" not in text:
        return fail("SPI Flash VIP configuration was not valid")

    if "[SPI_APB]" not in text:
        return fail("Boot ROM did not program the SPI controller")

    sclk_lines = [line for line in text.splitlines() if "[SPI_PIN_EVT] SCLK" in line]
    if len(sclk_lines) < 8:
        return fail("not enough SPI clock samples were logged")

    first_mosi_bits = []
    for line in sclk_lines[:8]:
        match = re.search(r"mosi=([01xz])", line)
        if not match:
            return fail(f"missing MOSI sample in line: {line}")
        first_mosi_bits.append(match.group(1))

    first_byte = "".join(first_mosi_bits)
    if first_byte != "10011111":
        return fail(f"first MOSI byte was {first_byte}, expected READ_ID 10011111")

    id_match = re.search(r"SPI_READ_ID_OBS.*response=0x([0-9a-fA-F]+)", text)
    if not id_match:
        return fail("READ_ID response word was not logged")

    read_id = int(id_match.group(1), 16)
    if read_id != 0x0102194D:
        return fail(f"READ_ID response was 0x{read_id:08x}, expected 0x0102194d")

    if "Debug finish requested" in text:
        return fail("simulation used +SPI_BOOT_FORCE_FINISH_NS instead of waiting for real EOT")

    if "EOT received, SPI Boot test PASSED" not in text:
        return fail("real SPI boot EOT was not observed")

    print("PASS: SPI boot log shows READ_ID response 0x0102194d and real EOT")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
