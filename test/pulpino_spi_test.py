import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "sim"))
from case_manager import Build, Test
from case_manager.base import InheritableMeta

# ===== Build 层 =====

class spi_base_build(Build):
    name = "spi_base"
    tag = ["spi"]
    vlog_opt = (
        "+vcs+lic+wait "
        "-full64 -sverilog -ntb_opts uvm-1.2 "
        "-timescale=1ns/1ps "
        "+define+SVT_SPI_IO_WIDTH=4 "
        "+define+SVT_SPI_MAX_NUM_SLAVES=4 "
        "+define+SVT_SPI_DATA_WIDTH=8 "
        "+define+SPI_VIP_EN "
    )
    elab_opt = "-debug_access+pp"
    simulator = "vcs"


class spi_boot_build(spi_base_build):
    name = "spi_boot"
    tag = ["spi", "boot"]
    vlog_opt = spi_base_build.vlog_opt + "+define+SPI_BOOT_EN +define+TRACE_PC "


# ===== Test 层 =====

class spi_base_test(Test):
    name = "spi_base"
    tag = ["spi"]
    build = spi_base_build
    uvm_test = "pulpino_spi_test"
    c_test = "tc_qspi_master_write"
    sim_opt = (
        "+TIMEOUT_NS=10000000 "
    )


# ----- TF_SPI_001~004, 010~013: Data Transfer -----

class tc_spi_std_wr_1word(spi_base_test):
    name = "tc_spi_std_wr_1word"
    tag += ["data_transfer", "write", "standard", "p0"]
    c_test = "tc_spi_data_transfer"
    c_defines = {"SPI_CMD_TYPE": 1, "DATA_WORDS": 1, "DATA_PATTERN": 0}


class tc_spi_std_rd_1word(spi_base_test):
    name = "tc_spi_std_rd_1word"
    tag += ["data_transfer", "read", "standard", "p0"]
    c_test = "tc_spi_data_transfer"
    c_defines = {"SPI_CMD_TYPE": 0, "DATA_WORDS": 1, "DATA_PATTERN": 0}


class tc_spi_std_wr_4word(spi_base_test):
    name = "tc_spi_std_wr_4word"
    tag += ["data_transfer", "write", "standard", "burst", "p1"]
    c_test = "tc_spi_data_transfer"
    c_defines = {"SPI_CMD_TYPE": 1, "DATA_WORDS": 4, "DATA_PATTERN": 0}


class tc_spi_std_rd_4word(spi_base_test):
    name = "tc_spi_std_rd_4word"
    tag += ["data_transfer", "read", "standard", "burst", "p1"]
    c_test = "tc_spi_data_transfer"
    c_defines = {"SPI_CMD_TYPE": 0, "DATA_WORDS": 4, "DATA_PATTERN": 0}


class tc_spi_qwr_4word(spi_base_test):
    name = "tc_spi_qwr_4word"
    tag += ["data_transfer", "write", "qspi", "p0"]
    c_test = "tc_spi_data_transfer"
    c_defines = {"SPI_CMD_TYPE": 3, "DATA_WORDS": 4, "DATA_PATTERN": 0}


class tc_spi_qrd_4word(spi_base_test):
    name = "tc_spi_qrd_4word"
    tag += ["data_transfer", "read", "qspi", "p1"]
    c_test = "tc_spi_data_transfer"
    c_defines = {"SPI_CMD_TYPE": 2, "DATA_WORDS": 4, "DATA_PATTERN": 0}


# ----- SPI Boot Test -----

class tc_spi_boot(spi_base_test):
    name = "tc_spi_boot"
    tag = ["spi", "boot", "p0"]
    build = spi_boot_build
    uvm_test = "pulpino_spi_boot_test"
    c_test = "tc_spi_boot"
    extra_make_opt = "BOOT_MODE=1"
    sim_opt = "+TIMEOUT_NS=20000000"


class tc_spi_qwr_all_zero(spi_base_test):
    name = "tc_spi_qwr_all_zero"
    tag += ["data_transfer", "write", "qspi", "pattern", "p1"]
    c_test = "tc_spi_data_transfer"
    c_defines = {"SPI_CMD_TYPE": 3, "DATA_WORDS": 4, "DATA_PATTERN": 1}


class tc_spi_qwr_all_one(spi_base_test):
    name = "tc_spi_qwr_all_one"
    tag += ["data_transfer", "write", "qspi", "pattern", "p1"]
    c_test = "tc_spi_data_transfer"
    c_defines = {"SPI_CMD_TYPE": 3, "DATA_WORDS": 4, "DATA_PATTERN": 2}


# ----- TF_SPI_020~023: Frame Config -----

for _clkdiv in [0, 5, 10, 100]:
    _name = f"tc_spi_clkdiv_{_clkdiv}"
    _cls = InheritableMeta(_name, (spi_base_test,), {
        "name": _name,
        "tag": spi_base_test.tag + ["frame_config", "clkdiv", "p1"],
        "c_test": "tc_spi_frame_config",
        "c_defines": {"CFG_CLKDIV": _clkdiv},
    })
    sys.modules[__name__].__dict__[_name] = _cls


class tc_spi_frame_cmdlen(spi_base_test):
    name = "tc_spi_frame_cmdlen"
    tag += ["frame_config", "cmdlen", "p2"]
    c_test = "tc_spi_frame_config"
    c_defines = {"CFG_CMDLEN": 8}


class tc_spi_frame_addrlen(spi_base_test):
    name = "tc_spi_frame_addrlen"
    tag += ["frame_config", "addrlen", "p2"]
    c_test = "tc_spi_frame_config"
    c_defines = {"CFG_ADDRLEN": 24}


class tc_spi_frame_dummy(spi_base_test):
    name = "tc_spi_frame_dummy"
    tag += ["frame_config", "dummy", "p2"]
    c_test = "tc_spi_frame_config"
    c_defines = {"CFG_DUMMY": 8}


# ----- TF_SPI_030~031: CS Control -----

class tc_spi_cs0(spi_base_test):
    name = "tc_spi_cs0"
    tag += ["cs_control", "cs0", "p1"]
    c_test = "tc_spi_cs_control"
    c_defines = {"TARGET_CS": 0}


class tc_spi_multi_cs(spi_base_test):
    name = "tc_spi_multi_cs"
    tag += ["cs_control", "multi_cs", "p2"]
    c_test = "tc_spi_cs_control"
    c_defines = {"TARGET_CS": 0, "TEST_MULTI_CS": 1}


# ----- TF_SPI_040~041: FIFO Stress -----

class tc_spi_tx_fifo_full(spi_base_test):
    name = "tc_spi_tx_fifo_full"
    tag += ["fifo", "tx", "stress", "p2"]
    c_test = "tc_spi_fifo_stress"
    c_defines = {"TEST_MODE": 0}


class tc_spi_rx_fifo_drain(spi_base_test):
    name = "tc_spi_rx_fifo_drain"
    tag += ["fifo", "rx", "stress", "p2"]
    c_test = "tc_spi_fifo_stress"
    c_defines = {"TEST_MODE": 1}


# ----- TF_SPI_050~051: IRQ -----

class tc_spi_irq_trigger(spi_base_test):
    name = "tc_spi_irq_trigger"
    tag += ["irq", "trigger", "p2"]
    c_test = "tc_spi_irq_test"
    c_defines = {"TEST_IRQ_CLEAR": 0}


class tc_spi_irq_clear(spi_base_test):
    name = "tc_spi_irq_clear"
    tag += ["irq", "clear", "p2"]
    c_test = "tc_spi_irq_test"
    c_defines = {"TEST_IRQ_CLEAR": 1}


# ----- TF_SPI_060: Timeout -----

class tc_spi_timeout(spi_base_test):
    name = "tc_spi_timeout"
    tag += ["timeout", "exception", "p3"]
    c_test = "tc_spi_timeout"


# ----- TF_SPI_070~072: System Integration -----

class tc_spi_reset_default(spi_base_test):
    name = "tc_spi_reset_default"
    tag += ["sys_integration", "reset", "p3"]
    c_test = "tc_spi_sys_integration"
    c_defines = {"TEST_MODE": 0}


class tc_spi_uart_concurrent(spi_base_test):
    name = "tc_spi_uart_concurrent"
    tag += ["sys_integration", "concurrent", "p3"]
    c_test = "tc_spi_sys_integration"
    c_defines = {"TEST_MODE": 1}


class tc_spi_pin_mux(spi_base_test):
    name = "tc_spi_pin_mux"
    tag += ["sys_integration", "pin_mux", "p3"]
    c_test = "tc_spi_sys_integration"
    c_defines = {"TEST_MODE": 2}
