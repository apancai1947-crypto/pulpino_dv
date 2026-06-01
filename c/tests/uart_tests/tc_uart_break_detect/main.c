#define UART_CASE_NAME "tc_uart_break_detect"
#include "../uart_vfl_common.h"

int main(void) {
  uart_vfl_finish(uart_vfl_run_break_config());
  return 0;
}
