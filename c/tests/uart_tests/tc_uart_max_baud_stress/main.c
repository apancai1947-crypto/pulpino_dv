#define UART_CASE_NAME "tc_uart_max_baud_stress"
#include "../uart_vfl_common.h"

int main(void) {
  uart_vfl_finish(uart_vfl_run_basic());
  return 0;
}
