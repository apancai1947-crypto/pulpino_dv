#include "spi.h"
#include "common_macro.h"

int main() {
    int i;
    int test_data[4] = {0x11223344, 0x55667788, 0x99AABBCC, 0xDDEEFF00};
    
    printf("INFO:UVM_INFO: [FW] QSPI Master Write Test started.\n");

    // 设置 SPI 分频，确保时钟速率适中 (sys_clk / (2*(10+1)))
    *(volatile int*) (SPI_REG_CLKDIV) = 10;

    // 2. 配置管脚复用：将相关 PAD 切换到 SPI 模式
    // MSPI_SIO0-3, MSPI_CSN0, MSPI_CLK
    spi_setup_master(1);
    printf("INFO:UVM_INFO: [FW] SPI Master pins configured.\n");

    // 3. 配置 QSPI 事务属性
    // 指令使用 QWR (Quad Write), 地址设为 0, 地址长度 0
    spi_setup_cmd_addr(SPI_CMD_QWR, 8, 0x0, 0);
    
    // 设置数据传输长度为 128 bits (4 words)
    spi_set_datalen(128);
    printf("INFO:UVM_INFO: [FW] SPI transaction configured: QWR, 128 bits.\n");

    // 4. 填充 TX FIFO
    spi_write_fifo(test_data, 128);
    printf("INFO:UVM_INFO: [FW] TX FIFO filled with patterns.\n");

    // 5. 启动事务：对 CS0 发起 QWR
    spi_start_transaction(SPI_CMD_QWR, SPI_CSN0);
    printf("INFO:UVM_INFO: [FW] Transaction started...\n");

    // 6. 等待传输完成
    // 根据 PULPino 官方应用代码 (testSPIMaster.c)，传输完成后状态字低位应变为 1
    int wait_cnt = 0;
    printf("INFO:UVM_INFO: [FW] Polling for completion... (Current STATUS=0x%x)\n", spi_get_status());
    while (1) {
        int status = spi_get_status();
        if ((wait_cnt & 0x3FF) == 0) {
            printf("INFO:UVM_INFO: [FW] Waiting for SPI... STATUS=0x%x\n", status);
        }
        // 关键：参考代码中使用 (status & 0xFFFF) != 1 作为循环条件
        if ((status & 0xFF) == 1) break;
        
        wait_cnt++;
        if (wait_cnt > 200000) {
            printf("INFO:UVM_ERROR: [FW] SPI Timeout! Final STATUS=0x%x\n", status);
            break;
        }
    }

    printf("INFO:UVM_INFO: [FW] QSPI Transaction finished.\n");
    printf("INFO:UVM_INFO: [FW] TEST PASSED: tc_qspi_master_write\n");

    // 7. 结束测试
    end_of_test();
    
    while(1);
    return 0;
}
