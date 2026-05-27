/*
 * tc_spi_flash_read — SPI Flash Quad Read verification
 *
 * Reads data from SPI VIP flash model using Quad I/O Fast Read (0xEB)
 * and prints received data. No Boot ROM involved — CPU boots from RAM.
 *
 * Flash data is loaded into VIP via UVM test backdoor.load().
 * This firmware just configures SPI master, reads, and reports.
 */
#include "spi.h"
#include "common_macro.h"

#define FLASH_CMD        0xEB    /* Quad I/O Fast Read */
#define FLASH_ADDR       0x00000000
#define FLASH_ADDR_LEN   32
#define FLASH_DUMMY_RD   8       /* 8 dummy cycles for quad read */
#define NUM_WORDS        4       /* Read 4 words = 16 bytes */
#define DATALEN_BITS     (NUM_WORDS * 32)

int main() {
    int i, status, wait_cnt;
    int rx_data[NUM_WORDS];

    printf("INFO:UVM_INFO: [FW] SPI Flash Read Test started.\n");
    printf("INFO:UVM_INFO: [FW] CMD=0xEB (Quad Read)  WORDS=%d  ADDR=0x%08x\n",
           NUM_WORDS, FLASH_ADDR);

    /* Step 1: Clock divider */
    *(volatile int *)(SPI_REG_CLKDIV) = 4;

    /* Step 2: GPIO pin mux — enable SPI master pins */
    spi_setup_master(1);

    /* Step 3: Configure flash read command + address */
    spi_setup_cmd_addr(FLASH_CMD, 8, FLASH_ADDR, FLASH_ADDR_LEN);

    /* Step 4: Set dummy cycles for quad read */
    spi_setup_dummy(FLASH_DUMMY_RD, 0);

    /* Step 5: Set data length */
    spi_set_datalen(DATALEN_BITS);

    /* Step 6: Start quad read transaction */
    spi_start_transaction(SPI_CMD_QRD, SPI_CSN0);

    /* Step 7: Poll for completion */
    wait_cnt = 0;
    while (1) {
        status = spi_get_status();
        if ((status & 0xFF) == 1) break;
        wait_cnt++;
        if (wait_cnt > 200000) {
            printf("INFO:UVM_ERROR: [FW] SPI Timeout! STATUS=0x%x\n", status);
            printf("INFO:UVM_INFO: [FW] TEST FAILED: tc_spi_flash_read\n");
            end_of_test();
            while (1);
        }
    }

    /* Step 8: Read data from RX FIFO */
    spi_read_fifo(rx_data, DATALEN_BITS);

    /* Step 9: Print received data */
    printf("INFO:UVM_INFO: [FW] SPI transaction completed. STATUS=0x%x\n", status);
    for (i = 0; i < NUM_WORDS; i++) {
        printf("INFO:UVM_INFO: [FW] rx_data[%d] = 0x%08x\n", i, rx_data[i]);
    }

    /* Step 10: Send to UVM scoreboard */
    ref_data_send(rx_data, NUM_WORDS);

    /* Step 11: Report pass */
    printf("INFO:UVM_INFO: [FW] TEST PASSED: tc_spi_flash_read\n");

    end_of_test();
    while (1);
    return 0;
}
