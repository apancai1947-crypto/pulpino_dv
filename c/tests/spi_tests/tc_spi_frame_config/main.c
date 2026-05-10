/*
 * tc_spi_frame_config — SPI frame format configuration test
 *
 * Covered test points: TF_SPI_020~023
 *
 * Compile-time macros (via EXTRA_CFLAGS):
 *   CFG_CLKDIV  : clock divider value    (default: 10)
 *   CFG_CMDLEN   : command field length   (default: 8)
 *   CFG_ADDRLEN  : address field length   (default: 0)
 *   CFG_DUMMY    : dummy cycles           (default: 0)
 */
#include "spi.h"
#include "uart.h"
#include "common_macro.h"

#ifndef CFG_CLKDIV
#define CFG_CLKDIV 10
#endif

#ifndef CFG_CMDLEN
#define CFG_CMDLEN 8
#endif

#ifndef CFG_ADDRLEN
#define CFG_ADDRLEN 0
#endif

#ifndef CFG_DUMMY
#define CFG_DUMMY 0
#endif

int main() {
    int status, wait_cnt;
    int tx_data[1] = {0xA5B6C7D8};
    int rx_data[1];

    uart_init();
    printf("INFO:UVM_INFO: [FW] SPI Frame Config Test started.\n");
    printf("INFO:UVM_INFO: [FW] CLKDIV=%d  CMDLEN=%d  ADDRLEN=%d  DUMMY=%d\n",
           CFG_CLKDIV, CFG_CMDLEN, CFG_ADDRLEN, CFG_DUMMY);

    /* Configure clock divider */
    *(volatile int *)(SPI_REG_CLKDIV) = CFG_CLKDIV;

    /* Pin mux */
    spi_setup_master(1);

    /* Command / address / dummy setup */
    spi_setup_cmd_addr(SPI_CMD_WR, CFG_CMDLEN, 0x0, CFG_ADDRLEN);
    spi_setup_dummy(CFG_DUMMY, CFG_DUMMY);
    spi_set_datalen(32);

    /* Write a single word to trigger a transaction for VIP observation */
    spi_write_fifo(tx_data, 32);
    spi_start_transaction(SPI_CMD_WR, SPI_CSN0);

    /* Poll for completion */
    wait_cnt = 0;
    while (1) {
        status = spi_get_status();
        if ((status & 0xFF) == 1) break;
        wait_cnt++;
        if (wait_cnt > 200000) {
            printf("INFO:UVM_ERROR: [FW] SPI Timeout! STATUS=0x%x\n", status);
            printf("INFO:UVM_INFO: [FW] TEST FAILED: tc_spi_frame_config\n");
            end_of_test();
            while (1);
        }
    }

    printf("INFO:UVM_INFO: [FW] Transaction completed. STATUS=0x%x\n", status);
    printf("INFO:UVM_INFO: [FW] TEST PASSED: tc_spi_frame_config\n");

    end_of_test();
    while (1);
    return 0;
}
