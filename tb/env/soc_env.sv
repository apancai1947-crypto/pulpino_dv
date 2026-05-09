`ifndef SOC_ENV_SV
`define SOC_ENV_SV

`include "uvm_pkg.sv"
`include "svt_uart_if.svi"
`include "svt_uart.uvm.pkg"
`include "svt_spi.uvm.pkg"
`include "svt_i2c.uvm.pkg"

import uvm_pkg::*;
import svt_uvm_pkg::*;
import svt_uart_uvm_pkg::*;
import svt_spi_uvm_pkg::*;
import svt_i2c_uvm_pkg::*;


`include "uvm_macros.svh"

class soc_env extends uvm_env;
    `uvm_component_utils(soc_env)

    soc_config cfg;

    // AXI agents — wired to probed interfaces in tb_top
    axi_agent core_master_agent;    // masters[0]: core2axi
    axi_agent periph_slave_agent;   // slaves[2]: peripherals

    // APB agent
    apb_agent apb_mon_agent;

    // UART TUBE monitor
    uart_monitor uart_mon;

    // Memory-mapped stdout monitor (APB writes to STDOUT_REG)
    stdout_monitor stdout_mon;

    // UART VIP DCE agent (Synopsys SVT)
    svt_uart_agent               dce_agent;
    svt_uart_agent_configuration dce_cfg;
    svt_uart_vif                 dce_vif;

    // SPI Master VIP Agent (Slave Role)
    svt_spi_agent                spi_master_agent;
    svt_spi_agent_configuration  spi_master_cfg;
    svt_spi_vif                  spi_master_vif;

    // I2C VIP Agent
    svt_i2c_master_agent         i2c_agent;
    svt_i2c_agent_configuration  i2c_cfg;
    svt_i2c_vif                  i2c_vif;

    // GPIO VIP Agent
    svt_gpio_agent               gpio_agent;
    svt_gpio_configuration       gpio_cfg;
    svt_gpio_vif                 gpio_vif;

    function new(string name = "soc_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        virtual interface axi_if core_vif, periph_vif;
        virtual interface apb_if  apb_vif;

        super.build_phase(phase);

        // Config
        if (!uvm_config_db#(soc_config)::get(this, "", "cfg", cfg)) begin
            `uvm_info("ENV", "No config found, creating default", UVM_LOW)
            cfg = soc_config::type_id::create("cfg");
        end

        // Get virtual interfaces from tb_top (set before run_test)
        if (!uvm_config_db#(virtual interface axi_if)::get(this, "", "core_axi_vif", core_vif))
            `uvm_fatal("ENV", "Failed to get core_axi_vif")
        if (!uvm_config_db#(virtual interface axi_if)::get(this, "", "periph_axi_vif", periph_vif))
            `uvm_fatal("ENV", "Failed to get periph_axi_vif")
        if (!uvm_config_db#(virtual interface apb_if)::get(this, "", "apb_vif", apb_vif))
            `uvm_fatal("ENV", "Failed to get apb_vif")

        // Get UART VIP DCE virtual interface from tb_top
        if (!uvm_config_db#(svt_uart_vif)::get(this, "", "dce_vif", dce_vif))
            `uvm_fatal("ENV", "Failed to get dce_vif")

        // Get SPI/I2C/GPIO VIP virtual interfaces
        // Get SPI Master VIP virtual interface
        if (cfg.enable_spi_master_vip && !uvm_config_db#(svt_spi_vif)::get(this, "", "spi_master_vif", spi_master_vif))
            `uvm_fatal("ENV", "Failed to get spi_master_vif")
        if (cfg.enable_i2c_vip && !uvm_config_db#(svt_i2c_vif)::get(this, "", "i2c_vif", i2c_vif))
            `uvm_fatal("ENV", "Failed to get i2c_vif")
        if (cfg.enable_gpio_vip && !uvm_config_db#(svt_gpio_vif)::get(this, "", "gpio_vif", gpio_vif))
            `uvm_fatal("ENV", "Failed to get gpio_vif")

        // Pass interfaces to agents via config_db (wildcard scope so child components can find them)
        uvm_config_db#(virtual interface axi_if)::set(this, "core_master_agent.*",  "axi_vif", core_vif);
        uvm_config_db#(virtual interface axi_if)::set(this, "periph_slave_agent.*", "axi_vif", periph_vif);
        uvm_config_db#(virtual interface apb_if)::set(this, "apb_mon_agent.*",      "apb_vif", apb_vif);

        // Create AXI agents (only those with wired interfaces)
        core_master_agent  = axi_agent::type_id::create("core_master_agent", this);
        periph_slave_agent = axi_agent::type_id::create("periph_slave_agent", this);

        // Create APB agent
        apb_mon_agent = apb_agent::type_id::create("apb_mon_agent", this);

        // Create UART monitor
        uart_mon = uart_monitor::type_id::create("uart_mon", this);

        // Configure and create UART VIP DCE agent
        dce_cfg = svt_uart_agent_configuration::type_id::create("dce_cfg");
        dce_cfg.is_active = 1;
        dce_cfg.set_uart_if(dce_vif);
        dce_cfg.baud_divisor = 2;  // 25MHz/(16*2) = 781250 baud, matches PULPino UART_DIVISOR=31

        // Apply UART config from plusargs (via soc_config)
        dce_cfg.data_width   = svt_uart_configuration::data_width_enum'(cfg.uart_data_width);
        dce_cfg.parity_type  = svt_uart_configuration::parity_type_enum'(cfg.uart_parity_type);
        // stop_bit is an enum — cast int to enum type
        case (cfg.uart_stop_bit)
            0: dce_cfg.stop_bit = svt_uart_configuration::ONE_BIT;
            1: dce_cfg.stop_bit = svt_uart_configuration::ONE_FIVE_BIT;
            2: dce_cfg.stop_bit = svt_uart_configuration::TWO_BIT;
            default: dce_cfg.stop_bit = svt_uart_configuration::ONE_BIT;
        endcase

        // Disable hardware flow control checking
        if (cfg.uart_disable_hw_handshake) begin
            dce_cfg.enable_rts_cts_handshake = 0;
            dce_cfg.enable_dtr_dsr_handshake = 0;
            dce_cfg.enable_tx_rx_handshake   = 0;
        end

        `uvm_info(get_type_name(), $sformatf(
            "DCE VIP config: data_width=%0d, parity_type=%0d, stop_bit=%0d, hw_hs_disabled=%0b",
            dce_cfg.data_width, dce_cfg.parity_type, dce_cfg.stop_bit,
            cfg.uart_disable_hw_handshake), UVM_LOW)

        uvm_config_db#(svt_uart_agent_configuration)::set(this, "dce_agent", "cfg", dce_cfg);
        dce_agent = svt_uart_agent::type_id::create("dce_agent", this);

        // SPI Master VIP Setup (Slave Role - simulating Flash)
        if (cfg.enable_spi_master_vip) begin
            spi_master_cfg = svt_spi_agent_configuration::type_id::create("spi_master_cfg");
            spi_master_cfg.is_active = cfg.spi_master_is_active;
            spi_master_cfg.spi_if = spi_master_vif;
            
            // Set role to Slave (since it connects to DUT Master)
            spi_master_cfg.is_master = 0;
            
            // Enable QSPI/Multilane mode if requested
            if (cfg.enable_qspi_mode) begin
                spi_master_cfg.frame_format = svt_spi_types::SPI_MULTILANE;
            end

            uvm_config_db#(svt_spi_agent_configuration)::set(this, "spi_master_agent", "cfg", spi_master_cfg);
            spi_master_agent = svt_spi_agent::type_id::create("spi_master_agent", this);
            `uvm_info("ENV", "SPI Master Agent created", UVM_LOW)
        end

        // I2C VIP Setup
        if (cfg.enable_i2c_vip) begin
            i2c_cfg = svt_i2c_agent_configuration::type_id::create("i2c_cfg");
            i2c_cfg.is_active = cfg.i2c_is_active;
            i2c_cfg.set_i2c_if(i2c_vif);
            uvm_config_db#(svt_i2c_agent_configuration)::set(this, "i2c_agent", "cfg", i2c_cfg);
            i2c_agent = svt_i2c_master_agent::type_id::create("i2c_agent", this);
            `uvm_info("ENV", "I2C Agent created", UVM_LOW)
        end



        // Create stdout monitor (gets apb_vif from config_db globally)
        stdout_mon = stdout_monitor::type_id::create("stdout_mon", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
    endfunction

    virtual function void report_phase(uvm_phase phase);
        uvm_report_server svr = uvm_report_server::get_server();
        `uvm_info(get_type_name(),
            $sformatf("=== ENV Summary ===\n  Errors: %0d | Fatals: %0d",
            svr.get_severity_count(UVM_ERROR), svr.get_severity_count(UVM_FATAL)), UVM_NONE)
    endfunction

endclass

`endif
