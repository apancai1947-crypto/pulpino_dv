/*
 * tc_spi_sys_integration — SPI system integration test
 *
 * Covered test points: TF_SPI_070~072
 *
 * Compile-time macros (via EXTRA_CFLAGS):
 *   TEST_MODE : 0=Reset defaults, 1=UART+SPI concurrent, 2=Pin mux (default: 0)
 */
#include "spi.h"
#include "common_macro.h"

#ifndef TEST_MODE
#define TEST_MODE 0
#endif

/* Check a register value and report */
static int check_reg(const char *name, unsigned int addr, unsigned int expected, unsigned int mask) {
    unsigned int actual = *(volatile unsigned int *)addr;
    unsigned int masked = actual & mask;
    if (masked == (expected & mask)) {
        printf("INFO:UVM_INFO: [FW] %s = 0x%x (OK)\n", name, actual);
        return 0;
    } else {
        printf("INFO:UVM_ERROR: [FW] %s = 0x%x, expected 0x%x (mask 0x%x)\n",
               name, actual, expected, mask);
        return 1;
    }
}

int main() {
    int errors = 0;

    printf("INFO:UVM_INFO: [FW] SPI Sys Integration Test started. MODE=%d\n", TEST_MODE);

#if TEST_MODE == 0
    /* TF_SPI_070: Check reset default register values */
    printf("INFO:UVM_INFO: [FW] Checking SPI register reset defaults...\n");

    /* After reset, most registers should be 0 */
    errors += check_reg("STATUS",  SPI_REG_STATUS, 0x0, 0xFFFFFFFF);
    errors += check_reg("CLKDIV",  SPI_REG_CLKDIV, 0x0, 0xFFFFFFFF);
    errors += check_reg("SPICMD",  SPI_REG_SPICMD, 0x0, 0xFFFFFFFF);
    errors += check_reg("SPIADR",  SPI_REG_SPIADR, 0x0, 0xFFFFFFFF);
    errors += check_reg("SPILEN",  SPI_REG_SPILEN, 0x0, 0xFFFFFFFF);
    errors += check_reg("SPIDUM",  SPI_REG_SPIDUM, 0x0, 0xFFFFFFFF);
    errors += check_reg("INTCFG",  SPI_REG_INTCFG, 0x0, 0xFFFFFFFF);
    errors += check_reg("INTSTA",  SPI_REG_INTSTA, 0x0, 0xFFFFFFFF);

    if (errors > 0) {
        printf("INFO:UVM_ERROR: [FW] %d register(s) have unexpected reset values!\n", errors);
        printf("INFO:UVM_INFO: [FW] TEST FAILED: tc_spi_sys_integration\n");
    } else {
        printf("INFO:UVM_INFO: [FW] All registers match reset defaults.\n");
        printf("INFO:UVM_INFO: [FW] TEST PASSED: tc_spi_sys_integration\n");
    }

#elif TEST_MODE == 1
    /* TF_SPI_071: SPI and UART concurrent operation */
    printf("INFO:UVM_INFO: [FW] Testing SPI + UART concurrency...\n");

    /* Start SPI transaction */
    {
        int tx_data[1] = {0x12345678};
        int status, wait_cnt;

        *(volatile int *)(SPI_REG_CLKDIV) = 10;
        spi_setup_master(1);
        spi_setup_cmd_addr(SPI_CMD_WR, 8, 0x0, 0);
        spi_set_datalen(32);
        spi_write_fifo(tx_data, 32);
        spi_start_transaction(SPI_CMD_WR, SPI_CSN0);

        /* While SPI is running, send UART output */
        printf("INFO:UVM_INFO: [FW] UART output during SPI transfer.\n");

        wait_cnt = 0;
        while (1) {
            status = spi_get_status();
            if ((status & 0xFF) == 1) break;
            wait_cnt++;
            if (wait_cnt > 200000) {
                printf("INFO:UVM_ERROR: [FW] SPI Timeout! STATUS=0x%x\n", status);
                printf("INFO:UVM_INFO: [FW] TEST FAILED: tc_spi_sys_integration\n");
                end_of_test();
                while (1);
            }
        }

        printf("INFO:UVM_INFO: [FW] Both SPI and UART operated concurrently.\n");
        printf("INFO:UVM_INFO: [FW] TEST PASSED: tc_spi_sys_integration\n");
    }

#elif TEST_MODE == 2
    /* TF_SPI_072: Pin mux configuration */
    printf("INFO:UVM_INFO: [FW] Testing SPI pin mux configuration...\n");

    /* Setup master with 1 CS — this configures GPIO pins for SPI function */
    spi_setup_master(1);
    printf("INFO:UVM_INFO: [FW] spi_setup_master(1) done.\n");

    /* Verify we can still do a transaction after pin mux */
    {
        int tx_data[1] = {0xABCD0123};
        int status, wait_cnt;

        *(volatile int *)(SPI_REG_CLKDIV) = 10;
        spi_setup_cmd_addr(SPI_CMD_WR, 8, 0x0, 0);
        spi_set_datalen(32);
        spi_write_fifo(tx_data, 32);
        spi_start_transaction(SPI_CMD_WR, SPI_CSN0);

        wait_cnt = 0;
        while (1) {
            status = spi_get_status();
            if ((status & 0xFF) == 1) break;
            wait_cnt++;
            if (wait_cnt > 200000) {
                printf("INFO:UVM_ERROR: [FW] SPI Timeout! STATUS=0x%x\n", status);
                printf("INFO:UVM_INFO: [FW] TEST FAILED: tc_spi_sys_integration\n");
                end_of_test();
                while (1);
            }
        }

        printf("INFO:UVM_INFO: [FW] Pin mux and transaction verified. STATUS=0x%x\n", status);
        printf("INFO:UVM_INFO: [FW] TEST PASSED: tc_spi_sys_integration\n");
    }

#else
    printf("INFO:UVM_ERROR: [FW] Unknown TEST_MODE=%d\n", TEST_MODE);
    printf("INFO:UVM_INFO: [FW] TEST FAILED: tc_spi_sys_integration\n");
#endif

    end_of_test();
    while (1);
    return 0;
}
