import os
import sys
import unittest


PROJECT_ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(PROJECT_ROOT, "sim"))

from case_manager.discovery import discover


UART_VFL_CASES = {
    "tc_uart_tx_single",
    "tc_uart_rx_single",
    "tc_uart_tx_continuous",
    "tc_uart_rx_continuous",
    "tc_uart_baudrate_switch",
    "tc_uart_frame_8n1",
    "tc_uart_data_all0",
    "tc_uart_data_all1",
    "tc_uart_data_random",
    "tc_uart_tx_fifo_flag",
    "tc_uart_rx_neq_irq",
    "tc_uart_fifo_threshold",
    "tc_uart_tx_empty_irq",
    "tc_uart_frame_error",
    "tc_uart_overrun_error",
    "tc_uart_fake_start_bit",
    "tc_uart_break_detect",
    "tc_uart_irq_to_plic",
    "tc_uart_reset_default",
    "tc_uart_loopback",
    "tc_uart_multi_peri_concurrent",
    "tc_uart_long_stress",
    "tc_uart_max_baud_stress",
}


class UartVflCasesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.discovered = discover(os.path.join(PROJECT_ROOT, "test"))["tests"]

    def test_vfl_uart_cases_are_discoverable(self):
        missing = sorted(UART_VFL_CASES - set(self.discovered))
        self.assertEqual([], missing)

    def test_discovered_vfl_uart_cases_have_firmware(self):
        missing = []
        for name in sorted(UART_VFL_CASES):
            if name not in self.discovered:
                continue
            c_test = self.discovered[name].c_test
            firmware_dir = os.path.join(PROJECT_ROOT, "c", "tests", "uart_tests", c_test)
            if not os.path.exists(os.path.join(firmware_dir, "main.c")):
                missing.append(f"{name}: {c_test}")
        self.assertEqual([], missing)


if __name__ == "__main__":
    unittest.main()
