`ifndef SOC_CONFIG_SV
`define SOC_CONFIG_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

class soc_config extends uvm_object;
    `uvm_object_utils(soc_config)

    // UART monitor config
    int uart_baud_rate = 781250;
    int clk_period_ns  = 40;

    // UART VIP DCE agent config (passed via plusargs)
    int uart_data_width  = 8;  // 5-9
    int uart_parity_type = 0;  // 0=NO_PARITY, 1=EVEN_PARITY, 2=ODD_PARITY, 3=STICK_HIGH_PARITY, 4=STICK_LOW_PARITY
    int uart_stop_bit    = 0;  // 0=ONE_BIT, 1=ONE_FIVE_BIT, 2=TWO_BIT
    bit uart_disable_hw_handshake = 1;  // disable CTS/RTS, DTR/DSR handshake checking

    // SPI Master VIP Config (Slave Role)
    bit spi_master_is_active = 1;
    bit enable_spi_master_vip = 1;

    // SPI Slave VIP Config (Master Role)
    bit spi_slave_is_active = 1;
    bit enable_spi_slave_vip = 0;

    // QSPI Config
    bit enable_qspi_mode = 1;

    // I2C VIP Config
    int i2c_bus_speed = 400; // kbps
    bit i2c_is_active = 1;
    bit gpio_is_active = 1;

    // Enable flags
    bit enable_scoreboard = 1;
    bit enable_coverage   = 1;
    bit enable_i2c_vip    = 1;
    bit enable_gpio_vip   = 1;

    function new(string name = "soc_config");
        super.new(name);
    endfunction

endclass

`endif
