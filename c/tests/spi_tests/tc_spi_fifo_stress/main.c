/*
 * tc_spi_fifo_stress — SPI FIFO stress test
 *
 * Covered test points: TF_SPI_040~041
 *
 * Compile-time macros (via EXTRA_CFLAGS):
 *   TEST_MODE : 0=TX FIFO fill-then-send, 1=RX FIFO drain (default: 0)
 */
#include "spi.h"
#include "uart.h"
#include "common_macro.h"

#ifndef TEST_MODE
#define TEST_MODE 0
#endif

/* SPI TX FIFO depth is 8 entries (32-bit words) */
#define FIFO_DEPTH 8

int main() {
    int i, status, wait_cnt;

    uart_init();
    printf("INFO:UVM_INFO: [FW] SPI FIFO Stress Test started. MODE=%d\n", TEST_MODE);

    *(volatile int *)(SPI_REG_CLKDIV) = 10;
    spi_setup_master(1);

#if TEST_MODE == 0
    /* TX FIFO full: fill FIFO_DEPTH words, then trigger */
    {
        int tx_data[FIFO_DEPTH];
        for (i = 0; i < FIFO_DEPTH; i++)
            tx_data[i] = 0xA0 | i;

        printf("INFO:UVM_INFO: [FW] Filling TX FIFO with %d words...\n", FIFO_DEPTH);
        spi_setup_cmd_addr(SPI_CMD_WR, 8, 0x0, 0);
        spi_set_datalen(FIFO_DEPTH * 32);
        spi_write_fifo(tx_data, FIFO_DEPTH * 32);
        spi_start_transaction(SPI_CMD_WR, SPI_CSN0);
    }
#else
    /* RX FIFO drain: request more data than FIFO depth, read in chunks */
    {
        int rx_data[FIFO_DEPTH * 2];
        int total_bits = FIFO_DEPTH * 2 * 32;

        printf("INFO:UVM_INFO: [FW] RX FIFO drain: requesting %d words...\n", FIFO_DEPTH * 2);
        spi_setup_cmd_addr(SPI_CMD_RD, 8, 0x0, 0);
        spi_set_datalen(total_bits);
        spi_start_transaction(SPI_CMD_RD, SPI_CSN0);

        /* Wait for completion then read */
        wait_cnt = 0;
        while (1) {
            status = spi_get_status();
            if ((status & 0xFF) == 1) break;
            wait_cnt++;
            if (wait_cnt > 200000) {
                printf("INFO:UVM_ERROR: [FW] SPI Timeout! STATUS=0x%x\n", status);
                printf("INFO:UVM_INFO: [FW] TEST FAILED: tc_spi_fifo_stress\n");
                end_of_test();
                while (1);
            }
        }

        spi_read_fifo(rx_data, total_bits);
        printf("INFO:UVM_INFO: [FW] RX data:");
        for (i = 0; i < FIFO_DEPTH * 2; i++)
            printf(" 0x%x", rx_data[i]);
        printf("\n");
    }
#endif

    /* Poll for completion (for TX mode) */
#if TEST_MODE == 0
    wait_cnt = 0;
    while (1) {
        status = spi_get_status();
        if ((status & 0xFF) == 1) break;
        wait_cnt++;
        if (wait_cnt > 200000) {
            printf("INFO:UVM_ERROR: [FW] SPI Timeout! STATUS=0x%x\n", status);
            printf("INFO:UVM_INFO: [FW] TEST FAILED: tc_spi_fifo_stress\n");
            end_of_test();
            while (1);
        }
    }
#endif

    printf("INFO:UVM_INFO: [FW] FIFO stress test completed. STATUS=0x%x\n", status);
    printf("INFO:UVM_INFO: [FW] TEST PASSED: tc_spi_fifo_stress\n");

    end_of_test();
    while (1);
    return 0;
}
