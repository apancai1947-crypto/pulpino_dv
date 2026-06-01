#define UART_CASE_NAME "tc_uart_fifo_threshold"
#include "../uart_vfl_common.h"

int main(void) {
  uart_vfl_finish(uart_vfl_run_fifo_threshold());
  return 0;
}
