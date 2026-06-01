import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "sim"))
from case_manager import Build, Test
from case_manager.base import InheritableMeta

# ===== Build 层 =====

class uart_base_build(Build):
    name = "uart_base"
    tag = ["uart"]
    vlog_opt = (
        "+vcs+lic+wait "
        "-full64 -sverilog -ntb_opts uvm-1.2 "
        "-timescale=1ns/1ps "
    )
    elab_opt = "-debug_access+pp"
    simulator = "vcs"


class uart_loopback_build(uart_base_build):
    name = "uart_loopback"
    vlog_opt += " +define+LOOPBACK"
    # -xprop=tmerge removed: use --xprop CLI flag when license supports it


# ===== Test 层 =====

class uart_base_test(Test):
    name = "uart_base"
    tag = ["uart"]
    build = uart_base_build
    uvm_test = "pulpino_uart_test"
    c_test = "tc_uart_hello"
    sim_opt = (
        "+UART_DATA_WIDTH=8 "
        "+UART_PARITY_TYPE=0 "
        "+UART_STOP_BIT=0 "
        "+UART_DISABLE_HW_HANDSHAKE "
        "+TIMEOUT_NS=10000000 "
    )


class tc_uart_rx_single_test(uart_base_test):
    name = "tc_uart_rx_single"
    tag += ["rx", "single"]
    c_test = "tc_uart_data_pattern"
    c_defines = {"UART_DIVISOR": 31, "NUM_BYTES": 5, "DATA_MODE": 1}
    sim_opt += "+UART_DATA_WIDTH=8"


class tc_uart_tx_single_test(uart_base_test):
    name = "tc_uart_tx_single"
    tag += ["tx", "single"]
    c_test = "tc_uart_data_pattern"
    c_defines = {"UART_DIVISOR": 31, "TX_DATA": 0xA5}
    sim_opt += "+UART_DATA_WIDTH=8"


class tc_uart_reset_default_test(uart_base_test):
    name = "tc_uart_reset_default"
    tag += ["reset", "config"]
    c_test = "tc_uart_reset_default"


class tc_uart_tx_fifo_flag_test(uart_base_test):
    name = "tc_uart_tx_fifo_flag"
    tag += ["fifo", "tx"]
    c_test = "tc_uart_tx_fifo_flag"


class tc_uart_baudrate_switch_test(uart_base_test):
    name = "tc_uart_baudrate_switch"
    tag += ["baudrate", "config"]
    c_test = "tc_uart_baudrate_switch"


class tc_uart_external_loopback_test(uart_base_test):
    name = "tc_uart_external_loopback"
    tag = ["loopback", "external"]
    build = uart_loopback_build
    c_test = "tc_uart_data_pattern"
    c_defines = {"UART_DIVISOR": 31}


class tc_uart_loopback_test(uart_base_test):
    name = "tc_uart_loopback"
    tag += ["loopback", "internal"]
    build = uart_base_build
    c_test = "tc_uart_data_pattern"
    c_defines = {"UART_DIVISOR": 31, "TX_DATA": 0xAB, "USE_INTERNAL_LOOPBACK": 1}


class tc_uart_tx_continuous_test(uart_base_test):
    name = "tc_uart_tx_continuous"
    tag += ["tx", "continuous"]
    c_test = "tc_uart_data_pattern"
    c_defines = {"UART_DIVISOR": 31, "NUM_BYTES": 32, "DATA_MODE": 1}


class tc_uart_rx_continuous_test(uart_base_test):
    name = "tc_uart_rx_continuous"
    tag += ["rx", "continuous"]
    c_test = "tc_uart_rx_continuous"
    c_defines = {"UART_DIVISOR": 31, "NUM_BYTES": 32, "DATA_MODE": 1}


class tc_uart_frame_8n1_test(uart_base_test):
    name = "tc_uart_frame_8n1"
    tag += ["frame", "8n1"]
    c_test = "tc_uart_frame_8n1"
    c_defines = {"UART_DIVISOR": 31, "NUM_BYTES": 4, "DATA_MODE": 1}
    sim_opt += "+UART_DATA_WIDTH=8 +UART_PARITY_TYPE=0 +UART_STOP_BIT=0 "


class tc_uart_rx_neq_irq_test(uart_base_test):
    name = "tc_uart_rx_neq_irq"
    tag += ["irq", "rx"]
    c_test = "tc_uart_rx_neq_irq"
    c_defines = {"UART_DIVISOR": 31, "TX_DATA": 0x36}


class tc_uart_fifo_threshold_test(uart_base_test):
    name = "tc_uart_fifo_threshold"
    tag += ["fifo", "irq", "rx"]
    c_test = "tc_uart_fifo_threshold"
    c_defines = {"UART_DIVISOR": 31, "NUM_BYTES": 4, "DATA_MODE": 1}


class tc_uart_tx_empty_irq_test(uart_base_test):
    name = "tc_uart_tx_empty_irq"
    tag += ["irq", "tx"]
    c_test = "tc_uart_tx_empty_irq"
    c_defines = {"UART_DIVISOR": 31, "TX_DATA": 0xC3}


class tc_uart_frame_error_test(uart_base_test):
    name = "tc_uart_frame_error"
    tag += ["error", "frame"]
    c_test = "tc_uart_frame_error"
    c_defines = {"UART_DIVISOR": 31, "TX_DATA": 0x81}


class tc_uart_overrun_error_test(uart_base_test):
    name = "tc_uart_overrun_error"
    tag += ["error", "overrun"]
    c_test = "tc_uart_overrun_error"
    c_defines = {"UART_DIVISOR": 31, "NUM_BYTES": 8, "DATA_MODE": 1}


class tc_uart_fake_start_bit_test(uart_base_test):
    name = "tc_uart_fake_start_bit"
    tag += ["error", "start"]
    c_test = "tc_uart_fake_start_bit"
    c_defines = {"UART_DIVISOR": 31, "TX_DATA": 0x7E}


class tc_uart_break_detect_test(uart_base_test):
    name = "tc_uart_break_detect"
    tag += ["error", "break"]
    c_test = "tc_uart_break_detect"
    c_defines = {"UART_DIVISOR": 31, "TX_DATA": 0x00}


class tc_uart_irq_to_plic_test(uart_base_test):
    name = "tc_uart_irq_to_plic"
    tag += ["irq", "plic"]
    c_test = "tc_uart_irq_to_plic"
    c_defines = {"UART_DIVISOR": 31, "TX_DATA": 0x5C}


class tc_uart_multi_peri_concurrent_test(uart_base_test):
    name = "tc_uart_multi_peri_concurrent"
    tag += ["integration", "concurrent"]
    c_test = "tc_uart_multi_peri_concurrent"
    c_defines = {"UART_DIVISOR": 31, "NUM_BYTES": 8, "DATA_MODE": 1}


class tc_uart_long_stress_test(uart_base_test):
    name = "tc_uart_long_stress"
    tag += ["stress", "long"]
    c_test = "tc_uart_long_stress"
    c_defines = {"UART_DIVISOR": 31, "NUM_BYTES": 256, "DATA_MODE": 2, "UART_TIMEOUT_POLLS": 500000}
    sim_opt += "+TIMEOUT_NS=200000000 "


class tc_uart_max_baud_stress_test(uart_base_test):
    name = "tc_uart_max_baud_stress"
    tag += ["stress", "baudrate"]
    c_test = "tc_uart_max_baud_stress"
    c_defines = {"UART_DIVISOR": 1, "NUM_BYTES": 64, "DATA_MODE": 2, "UART_TIMEOUT_POLLS": 500000}
    sim_opt += "+TIMEOUT_NS=100000000 "


# 循环生成（需要回环，继承 tc_uart_external_loopback_test）
import random as _random

for _data in ["all0", "all1", "random"]:
    _name = f"tc_uart_data_{_data}"
    _val = 0x00 if _data == "all0" else 0xFF if _data == "all1" else _random.randint(1, 254)
    _cls = InheritableMeta(_name, (tc_uart_external_loopback_test,), {
        "name": _name,
        "tag": tc_uart_external_loopback_test.tag + ["data", _data],
        "c_defines": {"UART_DIVISOR": 31, "TX_DATA": _val},
        "sim_opt": tc_uart_external_loopback_test.sim_opt + f"+UART_DATA_PATTERN={_data} ",
    })
    sys.modules[__name__].__dict__[_name] = _cls
del _random
