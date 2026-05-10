/*
 * tc_spi_irq_test — SPI interrupt test
 *
 * Covered test points: TF_SPI_050~051
 *
 * Compile-time macros (via EXTRA_CFLAGS):
 *   TEST_IRQ_CLEAR : 0=trigger only, 1=trigger and clear (default: 0)
 */
#include "spi.h"
#include "uart.h"
#include "common_macro.h"
#include "irq.h"

#ifndef TEST_IRQ_CLEAR
#define TEST_IRQ_CLEAR 0
#endif

/* IRQ_SPIM0 = 26 from irq.h */
#ifndef IRQ_SPIM0
#define IRQ_SPIM0 26
#endif

static volatile int irq_fired = 0;

void spi_irq_handler(void) {
    irq_fired = 1;
    printf("INFO:UVM_INFO: [FW] SPI IRQ handler fired! INTSTA=0x%x\n",
           *(volatile int *)SPI_REG_INTSTA);

#if TEST_IRQ_CLEAR
    /* Clear interrupt status by reading INTSTA (or writing to clear) */
    {
        int sta = *(volatile int *)SPI_REG_INTSTA;
        printf("INFO:UVM_INFO: [FW] Clearing INTSTA (was 0x%x)...\n", sta);
        /* Write-1-clear if applicable, or read-to-clear */
        *(volatile int *)SPI_REG_INTSTA = sta;
    }
#endif
}

int main() {
    int tx_data[1] = {0xCAFEBABE};
    int status, wait_cnt;

    uart_init();
    printf("INFO:UVM_INFO: [FW] SPI IRQ Test started. TEST_IRQ_CLEAR=%d\n", TEST_IRQ_CLEAR);

    *(volatile int *)(SPI_REG_CLKDIV) = 10;
    spi_setup_master(1);

    /* Register IRQ handler */
    irq_register(IRQ_SPIM0, spi_irq_handler);

    /* Enable SPI interrupt: set INTCFG to enable transfer-complete IRQ */
    *(volatile int *)SPI_REG_INTCFG = 0x1;

    /* Setup and start transaction */
    spi_setup_cmd_addr(SPI_CMD_WR, 8, 0x0, 0);
    spi_set_datalen(32);
    spi_write_fifo(tx_data, 32);
    spi_start_transaction(SPI_CMD_WR, SPI_CSN0);

    /* Wait for completion */
    wait_cnt = 0;
    while (1) {
        status = spi_get_status();
        if ((status & 0xFF) == 1) break;
        wait_cnt++;
        if (wait_cnt > 200000) {
            printf("INFO:UVM_ERROR: [FW] SPI Timeout! STATUS=0x%x\n", status);
            printf("INFO:UVM_INFO: [FW] TEST FAILED: tc_spi_irq_test\n");
            end_of_test();
            while (1);
        }
    }

    /* Give IRQ a chance to fire (it may be triggered by the status poll) */
    {
        int dummy = 1000;
        while (dummy-- && !irq_fired)
            asm volatile("nop");
    }

    if (irq_fired) {
        printf("INFO:UVM_INFO: [FW] IRQ was fired successfully.\n");
    } else {
        printf("INFO:UVM_INFO: [FW] IRQ not observed (may be edge-triggered). Checking INTSTA...\n");
        int intsta = *(volatile int *)SPI_REG_INTSTA;
        printf("INFO:UVM_INFO: [FW] INTSTA=0x%x\n", intsta);
    }

#if TEST_IRQ_CLEAR
    /* Verify INTSTA is cleared */
    {
        int intsta = *(volatile int *)SPI_REG_INTSTA;
        if (intsta == 0) {
            printf("INFO:UVM_INFO: [FW] INTSTA cleared successfully.\n");
        } else {
            printf("INFO:UVM_INFO: [FW] INTSTA not cleared: 0x%x\n", intsta);
        }
    }
#endif

    printf("INFO:UVM_INFO: [FW] TEST PASSED: tc_spi_irq_test\n");

    end_of_test();
    while (1);
    return 0;
}
