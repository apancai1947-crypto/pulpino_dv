#define UART_CASE_NAME "tc_uart_tx_empty_irq"
#include "../uart_vfl_common.h"

int main(void) {
  uart_vfl_finish(uart_vfl_run_tx_empty_irq());
  return 0;
}
