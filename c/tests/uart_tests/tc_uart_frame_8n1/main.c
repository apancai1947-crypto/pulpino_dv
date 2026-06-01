#define UART_CASE_NAME "tc_uart_frame_8n1"
#include "../uart_vfl_common.h"

int main(void) {
  uart_vfl_finish(uart_vfl_run_frame_8n1());
  return 0;
}
