#define UART_CASE_NAME "tc_uart_rx_continuous"
#include "../uart_vfl_common.h"

int main(void) {
  uart_vfl_finish(uart_vfl_run_basic());
  return 0;
}
