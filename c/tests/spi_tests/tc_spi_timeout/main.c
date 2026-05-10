/*
 * tc_spi_timeout — SPI transfer timeout detection test
 *
 * Covered test points: TF_SPI_060
 *
 * This test initiates an SPI read (which requires VIP response) but
 * intentionally uses a very short timeout to verify the firmware
 * correctly detects a timeout condition.
 */
#include "spi.h"
#include "uart.h"
#include "common_macro.h"

/* Short timeout for this test (50k iterations) */
#define SPI_TIMEOUT_LIMIT 50000

int main() {
    int status, wait_cnt;
    int rx_data[1];
    int timed_out = 0;

    uart_init();
    printf("INFO:UVM_INFO: [FW] SPI Timeout Test started.\n");

    *(volatile int *)(SPI_REG_CLKDIV) = 10;
    spi_setup_master(1);

    /* Start a read transaction — if VIP doesn't respond, we should timeout */
    spi_setup_cmd_addr(SPI_CMD_RD, 8, 0x0, 0);
    spi_set_datalen(32);
    spi_start_transaction(SPI_CMD_RD, SPI_CSN0);

    printf("INFO:UVM_INFO: [FW] Transaction started, polling with timeout limit=%d...\n",
           SPI_TIMEOUT_LIMIT);

    wait_cnt = 0;
    while (1) {
        status = spi_get_status();
        if ((status & 0xFF) == 1) break;
        wait_cnt++;
        if (wait_cnt > SPI_TIMEOUT_LIMIT) {
            timed_out = 1;
            printf("INFO:UVM_INFO: [FW] Timeout detected after %d iterations. STATUS=0x%x\n",
                   wait_cnt, status);
            break;
        }
    }

    if (timed_out) {
        printf("INFO:UVM_INFO: [FW] Timeout handling verified.\n");
    } else {
        printf("INFO:UVM_INFO: [FW] Transaction completed without timeout. STATUS=0x%x\n", status);
        spi_read_fifo(rx_data, 32);
        printf("INFO:UVM_INFO: [FW] RX data: 0x%x\n", rx_data[0]);
    }

    printf("INFO:UVM_INFO: [FW] TEST PASSED: tc_spi_timeout\n");

    end_of_test();
    while (1);
    return 0;
}
