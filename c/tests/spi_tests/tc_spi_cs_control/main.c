/*
 * tc_spi_cs_control — SPI chip-select control test
 *
 * Covered test points: TF_SPI_030~031
 *
 * Compile-time macros (via EXTRA_CFLAGS):
 *   TARGET_CS     : chip select index 0~3  (default: 0)
 *   TEST_MULTI_CS : 0=single CS, 1=multi CS switch (default: 0)
 */
#include "spi.h"
#include "uart.h"
#include "common_macro.h"

#ifndef TARGET_CS
#define TARGET_CS 0
#endif

#ifndef TEST_MULTI_CS
#define TEST_MULTI_CS 0
#endif

static void do_transaction(int cs, int data_word) {
    int tx_data[1];
    int status, wait_cnt;

    tx_data[0] = data_word;

    spi_setup_cmd_addr(SPI_CMD_WR, 8, 0x0, 0);
    spi_set_datalen(32);
    spi_write_fifo(tx_data, 32);
    spi_start_transaction(SPI_CMD_WR, cs);

    wait_cnt = 0;
    while (1) {
        status = spi_get_status();
        if ((status & 0xFF) == 1) break;
        wait_cnt++;
        if (wait_cnt > 200000) {
            printf("INFO:UVM_ERROR: [FW] SPI Timeout on CS%d! STATUS=0x%x\n", cs, status);
            return;
        }
    }
    printf("INFO:UVM_INFO: [FW] CS%d transaction done. STATUS=0x%x\n", cs, status);
}

int main() {
    uart_init();
    printf("INFO:UVM_INFO: [FW] SPI CS Control Test started.\n");
    printf("INFO:UVM_INFO: [FW] TARGET_CS=%d  TEST_MULTI_CS=%d\n",
           TARGET_CS, TEST_MULTI_CS);

    *(volatile int *)(SPI_REG_CLKDIV) = 10;
    spi_setup_master(4);  /* enable up to 4 CS lines */

#if TEST_MULTI_CS
    /* Multi-CS switching: send a transaction on each CS */
    {
        int cs;
        int patterns[4] = {0x11111111, 0x22222222, 0x33333333, 0x44444444};
        for (cs = 0; cs < 4; cs++) {
            printf("INFO:UVM_INFO: [FW] Switching to CS%d...\n", cs);
            do_transaction(cs, patterns[cs]);
        }
    }
#else
    /* Single CS test */
    do_transaction(TARGET_CS, 0xDEADBEEF);
#endif

    printf("INFO:UVM_INFO: [FW] TEST PASSED: tc_spi_cs_control\n");

    end_of_test();
    while (1);
    return 0;
}
