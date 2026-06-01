#define UART_CASE_NAME "tc_uart_irq_to_plic"
#include "../uart_vfl_common.h"

int main(void) {
  uart_vfl_finish(uart_vfl_run_rx_irq());
  return 0;
}
