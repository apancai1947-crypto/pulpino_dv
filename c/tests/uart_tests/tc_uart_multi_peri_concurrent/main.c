#define UART_CASE_NAME "tc_uart_multi_peri_concurrent"
#include "../uart_vfl_common.h"

int main(void) {
  uart_vfl_finish(uart_vfl_run_multi_peri());
  return 0;
}
