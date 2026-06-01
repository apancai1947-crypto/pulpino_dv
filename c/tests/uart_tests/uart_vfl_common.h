#ifndef UART_VFL_COMMON_H
#define UART_VFL_COMMON_H

#include "common_macro.h"
#include "uart.h"

extern int printf(const char *fmt, ...);
extern void end_of_test(void);

#ifndef UART_CASE_NAME
#define UART_CASE_NAME "tc_uart_unknown"
#endif

#ifndef TX_DATA
#define TX_DATA 0x5A
#endif

#ifndef NUM_BYTES
#define NUM_BYTES 1
#endif

#ifndef DATA_MODE
#define DATA_MODE 0
#endif

#ifndef UART_TIMEOUT_POLLS
#define UART_TIMEOUT_POLLS 200000
#endif

#define UART_IER_RX_AVAIL 0x01
#define UART_IER_TX_EMPTY 0x02
#define UART_IER_LINE_STATUS 0x04
#define UART_LSR_DR 0x01
#define UART_LSR_PARITY_ERR 0x04
#define UART_LSR_THRE 0x20
#define UART_LSR_TEMT 0x40
#define UART_FCR_ENABLE 0x01
#define UART_FCR_RX_RESET 0x02
#define UART_FCR_TX_RESET 0x04
#define UART_FCR_TRIGGER_1 0x00
#define UART_FCR_TRIGGER_4 0x40
#define UART_FCR_TRIGGER_8 0x80
#define UART_FCR_TRIGGER_14 0xC0
#define UART_LCR_8N1 0x03

static unsigned char uart_vfl_byte(int index) {
  unsigned int x;

  if (DATA_MODE == 1) {
    return (unsigned char)index;
  }
  if (DATA_MODE == 2) {
    x = (unsigned int)(index + 1) * 1103515245u + 12345u;
    return (unsigned char)((x >> 16) & 0xFFu);
  }
  return (unsigned char)TX_DATA;
}

static int uart_vfl_wait_lsr(unsigned char mask) {
  int timeout = UART_TIMEOUT_POLLS;
  while ((UART_REG_LSR & mask) != mask) {
    if (--timeout == 0) {
      return 0;
    }
  }
  return 1;
}

static int uart_vfl_exchange(int num_bytes) {
  int pass_count = 0;

  for (int i = 0; i < num_bytes; i++) {
    unsigned char tx_byte = uart_vfl_byte(i);
    unsigned char rx_byte;

    uart_sendchar((char)tx_byte);
    if (!uart_vfl_wait_lsr(UART_LSR_DR)) {
      printf("INFO: [FW] FAIL: timeout waiting RX byte %d\n", i);
      continue;
    }

    rx_byte = (unsigned char)uart_getchar();
    if (rx_byte == tx_byte) {
      pass_count++;
    } else {
      printf("INFO: [FW] FAIL: byte %d TX=0x%02X RX=0x%02X\n", i, tx_byte, rx_byte);
    }
  }

  return pass_count == num_bytes;
}

static void uart_vfl_finish(int pass) {
  if (pass) {
    printf("INFO: [FW] TEST PASSED: %s\n", UART_CASE_NAME);
  } else {
    printf("INFO: [FW] TEST FAILED: %s\n", UART_CASE_NAME);
  }
  end_of_test();
}

static int uart_vfl_run_basic(void) {
  uart_init();
  printf("INFO: [FW] %s: UART basic transfer, bytes=%d mode=%d\n",
         UART_CASE_NAME, (int)NUM_BYTES, (int)DATA_MODE);
  return uart_vfl_exchange(NUM_BYTES);
}

static int uart_vfl_run_frame_8n1(void) {
  int pass = 1;
  uart_init();
  UART_REG_LCR = UART_LCR_8N1;
  pass &= (UART_REG_LCR == UART_LCR_8N1);
  pass &= uart_vfl_exchange(NUM_BYTES);
  return pass;
}

static int uart_vfl_run_rx_irq(void) {
  int pass = 1;
  uart_init();
  UART_REG_IER = UART_IER_RX_AVAIL;
  pass &= ((UART_REG_IER & UART_IER_RX_AVAIL) != 0);
  uart_sendchar((char)TX_DATA);
  pass &= uart_vfl_wait_lsr(UART_LSR_DR);
  pass &= ((unsigned char)uart_getchar() == (unsigned char)TX_DATA);
  return pass;
}

static int uart_vfl_run_fifo_threshold(void) {
  int pass = 1;
  uart_init();
  UART_REG_FCR = UART_FCR_ENABLE | UART_FCR_RX_RESET | UART_FCR_TX_RESET | UART_FCR_TRIGGER_4;
  UART_REG_IER = UART_IER_RX_AVAIL;
  pass &= uart_vfl_exchange(NUM_BYTES);
  return pass;
}

static int uart_vfl_run_tx_empty_irq(void) {
  int pass = 1;
  uart_init();
  UART_REG_IER = UART_IER_TX_EMPTY;
  pass &= ((UART_REG_IER & UART_IER_TX_EMPTY) != 0);
  uart_sendchar((char)TX_DATA);
  pass &= uart_vfl_wait_lsr(UART_LSR_TEMT);
  (void)UART_REG_IIR;
  return pass;
}

static int uart_vfl_run_error_status_clean(void) {
  int pass = 1;
  uart_init();
  UART_REG_IER = UART_IER_LINE_STATUS;
  pass &= uart_vfl_exchange(NUM_BYTES);
  pass &= ((UART_REG_LSR & UART_LSR_PARITY_ERR) == 0);
  return pass;
}

static int uart_vfl_run_break_config(void) {
  int pass = 1;
  uart_init();
  UART_REG_LCR = UART_LCR_8N1 | 0x40;
  pass &= ((UART_REG_LCR & 0x40) != 0);
  UART_REG_LCR = UART_LCR_8N1;
  pass &= uart_vfl_exchange(NUM_BYTES);
  return pass;
}

static int uart_vfl_run_multi_peri(void) {
  int pass = 1;
  uart_init();
  RAW_DATA_REG = 0xA5A55A5A;
  pass &= uart_vfl_exchange(NUM_BYTES);
  RAW_DATA_REG = 0x5A5AA5A5;
  pass &= uart_vfl_exchange(NUM_BYTES);
  return pass;
}

#endif
