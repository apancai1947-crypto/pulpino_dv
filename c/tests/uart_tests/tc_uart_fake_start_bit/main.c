#define UART_CASE_NAME "tc_uart_fake_start_bit"
#include "../uart_vfl_common.h"

int main(void) {
  uart_vfl_finish(uart_vfl_run_error_status_clean());
  return 0;
}
