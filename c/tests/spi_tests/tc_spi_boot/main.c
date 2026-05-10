#include "common_macro.h"

int main() {
    // Note: No uart_init() required as per user comment.
    // Printing is handled via memory-mapped stdout (APB bridge to STDOUT_REG).
    
    printf("INFO:UVM_INFO: [FW] PULPino Booted Successfully from SPI Flash VIP!\n");
    
    // Trigger EOT (End of Test) to notify the monitor
    end_of_test();
    
    while(1);
    return 0;
}
