/*
 * tc_spi_data_transfer — Parameterized SPI data transfer test
 *
 * Covered test points: TF_SPI_001~004 (Standard), TF_SPI_010~013 (Quad)
 *
 * Compile-time macros (via EXTRA_CFLAGS):
 *   SPI_CMD_TYPE  : 0=RD, 1=WR, 2=QRD, 3=QWR  (default: SPI_CMD_WR)
 *   DATA_WORDS    : number of 32-bit words       (default: 1)
 *   DATA_PATTERN  : 0=increment, 1=all-zero, 2=all-one, 3=random (default: 0)
 */
#include "spi.h"
#include "uart.h"
#include "common_macro.h"

#ifndef SPI_CMD_TYPE
#define SPI_CMD_TYPE SPI_CMD_WR
#endif

#ifndef DATA_WORDS
#define DATA_WORDS 1
#endif

#ifndef DATA_PATTERN
#define DATA_PATTERN 0
#endif

/* Simple LFSR for "random" pattern (seed=0xDEAD) */
static unsigned int lfsr_state = 0xDEAD;
static unsigned int lfsr_next(void) {
    unsigned int bit = ((lfsr_state >> 0) ^ (lfsr_state >> 2) ^
                        (lfsr_state >> 3) ^ (lfsr_state >> 5)) & 1;
    lfsr_state = (lfsr_state >> 1) | (bit << 15);
    return lfsr_state;
}

static void fill_pattern(int *buf, int words) {
    int i;
    for (i = 0; i < words; i++) {
        switch (DATA_PATTERN) {
            case 1:  buf[i] = 0x00000000; break;
            case 2:  buf[i] = 0xFFFFFFFF; break;
            case 3:  buf[i] = (int)lfsr_next(); break;
            default: buf[i] = i + 1; break;  /* increment */
        }
    }
}

static const char *cmd_name(int cmd) {
    switch (cmd) {
        case SPI_CMD_RD:  return "SRD";
        case SPI_CMD_WR:  return "SWR";
        case SPI_CMD_QRD: return "QRD";
        case SPI_CMD_QWR: return "QWR";
        default:          return "???";
    }
}

int main() {
    int i, status, wait_cnt;
    int data[DATA_WORDS];
    int rx_data[DATA_WORDS];
    int datalen_bits = DATA_WORDS * 32;
    int is_write = (SPI_CMD_TYPE == SPI_CMD_WR || SPI_CMD_TYPE == SPI_CMD_QWR);

    uart_init();
    printf("INFO:UVM_INFO: [FW] SPI Data Transfer Test started.\n");
    printf("INFO:UVM_INFO: [FW] CMD=%s  WORDS=%d  PATTERN=%d\n",
           cmd_name(SPI_CMD_TYPE), DATA_WORDS, DATA_PATTERN);

    /* Clock divider */
    *(volatile int *)(SPI_REG_CLKDIV) = 10;

    /* Pin mux */
    spi_setup_master(1);

    /* Command / address setup */
    spi_setup_cmd_addr(SPI_CMD_TYPE, 8, 0x0, 0);
    spi_set_datalen(datalen_bits);

    if (is_write) {
        fill_pattern(data, DATA_WORDS);
        printf("INFO:UVM_INFO: [FW] TX data:");
        for (i = 0; i < DATA_WORDS; i++)
            printf(" 0x%x", data[i]);
        printf("\n");

        spi_write_fifo(data, datalen_bits);
        spi_start_transaction(SPI_CMD_TYPE, SPI_CSN0);
    } else {
        spi_start_transaction(SPI_CMD_TYPE, SPI_CSN0);
    }

    /* Poll for completion */
    wait_cnt = 0;
    while (1) {
        status = spi_get_status();
        if ((status & 0xFF) == 1) break;
        wait_cnt++;
        if (wait_cnt > 200000) {
            printf("INFO:UVM_ERROR: [FW] SPI Timeout! STATUS=0x%x\n", status);
            printf("INFO:UVM_INFO: [FW] TEST FAILED: tc_spi_data_transfer\n");
            end_of_test();
            while (1);
        }
    }

    if (!is_write) {
        spi_read_fifo(rx_data, datalen_bits);
        printf("INFO:UVM_INFO: [FW] RX data:");
        for (i = 0; i < DATA_WORDS; i++)
            printf(" 0x%x", rx_data[i]);
        printf("\n");
    }

    printf("INFO:UVM_INFO: [FW] SPI transaction completed. STATUS=0x%x\n", status);
    printf("INFO:UVM_INFO: [FW] TEST PASSED: tc_spi_data_transfer\n");

    end_of_test();
    while (1);
    return 0;
}
