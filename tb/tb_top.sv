// tb/tb_top.sv — PULPino UVM verification testbench top
`timescale 1ns/1ps

import svt_uvm_pkg::*;
`include "uart_reset_if.svi"

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "config.sv"

module tb_top;

    /** Import SVT UVM Packages */
    import svt_uart_uvm_pkg::*;
`ifdef SPI_VIP_EN
    import svt_spi_uvm_pkg::*;
`endif
`ifdef I2C_VIP_EN
    import svt_i2c_uvm_pkg::*;
`endif

    // ============================================
    // Core Selection Parameters (override via -gUSE_ZERO_RISCY=1 etc.)
    // ============================================
    parameter USE_ZERO_RISCY = 0;
    parameter RISCY_RV32F    = 0;
    parameter ZERO_RV32M     = 1;
    parameter ZERO_RV32E     = 0;

    // ============================================
    // Clock and Reset
    // ============================================
    logic clk = 1'b0;
    logic rst_n = 1'b0;

    localparam CLK_PERIOD = 40; // 25 MHz

    initial begin
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    initial begin
        rst_n = 1'b0;
        #(CLK_PERIOD * 12); // ~500ns reset
        rst_n = 1'b1;
    end

    // ============================================
    // DUT signals
    // ============================================
    logic        clk_sel_i       = 1'b0;
    logic        clk_standalone_i = 1'b0;
    logic        testmode_i      = 1'b0;
    logic        fetch_enable    = 1'b0;
    logic        scan_enable_i   = 1'b0;

    // SPI Slave
    logic        spi_clk_i;
    logic        spi_cs_i;
    logic [1:0]  spi_mode_o;
    logic        spi_sdo0_o, spi_sdo1_o, spi_sdo2_o, spi_sdo3_o;
    logic        spi_sdi0_i, spi_sdi1_i, spi_sdi2_i, spi_sdi3_i;

    // SPI Master
    logic        spi_master_clk_o;
    logic        spi_master_csn0_o, spi_master_csn1_o, spi_master_csn2_o, spi_master_csn3_o;
    logic [1:0]  spi_master_mode_o;
    logic        spi_master_sdo0_o, spi_master_sdo1_o, spi_master_sdo2_o, spi_master_sdo3_o;
    logic        spi_master_sdi0_i, spi_master_sdi1_i;
    logic        spi_master_sdi2_i, spi_master_sdi3_i;

    // I2C
    logic scl_pad_i, scl_pad_o, scl_padoen_o;
    logic sda_pad_i, sda_pad_o, sda_padoen_o;

    // UART
    logic uart_tx;
    logic uart_rx;
    logic uart_rts, uart_dtr;
    logic uart_cts;
    logic uart_dsr;

    // GPIO
    logic [31:0] gpio_in;
    logic [31:0] gpio_out;
    logic [31:0] gpio_dir;
    logic [31:0][5:0] gpio_padcfg;

    // JTAG
    logic tck_i = 1'b0, trstn_i = 1'b1, tms_i = 1'b0, tdi_i = 1'b0, tdo_o;

    // Pad config
    logic [31:0][5:0] pad_cfg_o;
    logic [31:0]      pad_mux_o;

    // ============================================
    // DUT Instantiation
    // ============================================
    pulpino_top
    #(
        .USE_ZERO_RISCY    ( USE_ZERO_RISCY ),
        .RISCY_RV32F       ( RISCY_RV32F    ),
        .ZERO_RV32M        ( ZERO_RV32M     ),
        .ZERO_RV32E        ( ZERO_RV32E     )
    )
    dut
    (
        .clk               ( clk             ),
        .rst_n             ( rst_n           ),
        .clk_sel_i         ( clk_sel_i       ),
        .clk_standalone_i  ( clk_standalone_i),
        .testmode_i        ( testmode_i      ),
        .fetch_enable_i    ( fetch_enable    ),
        .scan_enable_i     ( scan_enable_i   ),

        .spi_clk_i         ( spi_clk_i       ),
        .spi_cs_i          ( spi_cs_i        ),
        .spi_mode_o        ( spi_mode_o      ),
        .spi_sdo0_o        ( spi_sdo0_o      ),
        .spi_sdo1_o        ( spi_sdo1_o      ),
        .spi_sdo2_o        ( spi_sdo2_o      ),
        .spi_sdo3_o        ( spi_sdo3_o      ),
        .spi_sdi0_i        ( spi_sdi0_i      ),
        .spi_sdi1_i        ( spi_sdi1_i      ),
        .spi_sdi2_i        ( spi_sdi2_i      ),
        .spi_sdi3_i        ( spi_sdi3_i      ),

        .spi_master_clk_o  ( spi_master_clk_o  ),
        .spi_master_csn0_o ( spi_master_csn0_o ),
        .spi_master_csn1_o ( spi_master_csn1_o ),
        .spi_master_csn2_o ( spi_master_csn2_o ),
        .spi_master_csn3_o ( spi_master_csn3_o ),
        .spi_master_mode_o ( spi_master_mode_o ),
        .spi_master_sdo0_o ( spi_master_sdo0_o ),
        .spi_master_sdo1_o ( spi_master_sdo1_o ),
        .spi_master_sdo2_o ( spi_master_sdo2_o ),
        .spi_master_sdo3_o ( spi_master_sdo3_o ),
        .spi_master_sdi0_i ( spi_master_sdi0_i ),
        .spi_master_sdi1_i ( spi_master_sdi1_i ),
        .spi_master_sdi2_i ( spi_master_sdi2_i ),
        .spi_master_sdi3_i ( spi_master_sdi3_i ),

        .scl_pad_i         ( scl_pad_i    ),
        .scl_pad_o         ( scl_pad_o    ),
        .scl_padoen_o      ( scl_padoen_o ),
        .sda_pad_i         ( sda_pad_i    ),
        .sda_pad_o         ( sda_pad_o    ),
        .sda_padoen_o      ( sda_padoen_o ),

        .uart_tx           ( uart_tx      ),
        .uart_rx           ( uart_rx      ),
        .uart_rts          ( uart_rts     ),
        .uart_dtr          ( uart_dtr     ),
        .uart_cts          ( uart_cts     ),
        .uart_dsr          ( uart_dsr     ),

        .gpio_in           ( gpio_in      ),
        .gpio_out          ( gpio_out     ),
        .gpio_dir          ( gpio_dir     ),
        .gpio_padcfg       ( gpio_padcfg  ),

        .tck_i             ( tck_i        ),
        .trstn_i           ( trstn_i      ),
        .tms_i             ( tms_i        ),
        .tdi_i             ( tdi_i        ),
        .tdo_o             ( tdo_o        ),

        .pad_cfg_o         ( pad_cfg_o    ),
        .pad_mux_o         ( pad_mux_o    )
    );

    // ============================================
    // AXI Probe Interfaces (for UVM monitors)
    // Connect to DUT's AXI master/slave ports via hierarchical references
    // ============================================

    // Core master AXI (masters[0])
    axi_if core_axi (.clk(clk), .rst_n(rst_n));
    assign core_axi.aw_addr  = dut.masters[0].aw_addr;
    assign core_axi.aw_valid = dut.masters[0].aw_valid;
    assign core_axi.aw_ready = dut.masters[0].aw_ready;
    assign core_axi.aw_size  = dut.masters[0].aw_size;
    assign core_axi.aw_burst = dut.masters[0].aw_burst;
    assign core_axi.aw_id    = dut.masters[0].aw_id;
    assign core_axi.aw_len   = dut.masters[0].aw_len;
    assign core_axi.w_data   = dut.masters[0].w_data;
    assign core_axi.w_valid  = dut.masters[0].w_valid;
    assign core_axi.w_ready  = dut.masters[0].w_ready;
    assign core_axi.w_strb   = dut.masters[0].w_strb;
    assign core_axi.b_resp   = dut.masters[0].b_resp;
    assign core_axi.b_valid  = dut.masters[0].b_valid;
    assign core_axi.b_ready  = dut.masters[0].b_ready;
    assign core_axi.ar_addr  = dut.masters[0].ar_addr;
    assign core_axi.ar_valid = dut.masters[0].ar_valid;
    assign core_axi.ar_ready = dut.masters[0].ar_ready;
    assign core_axi.ar_size  = dut.masters[0].ar_size;
    assign core_axi.ar_burst = dut.masters[0].ar_burst;
    assign core_axi.ar_id    = dut.masters[0].ar_id;
    assign core_axi.ar_len   = dut.masters[0].ar_len;
    assign core_axi.r_data   = dut.masters[0].r_data;
    assign core_axi.r_resp   = dut.masters[0].r_resp;
    assign core_axi.r_valid  = dut.masters[0].r_valid;
    assign core_axi.r_ready  = dut.masters[0].r_ready;

    // Slave: Peripherals AXI (slaves[2])
    axi_if periph_axi (.clk(clk), .rst_n(rst_n));
    assign periph_axi.aw_addr  = dut.slaves[2].aw_addr;
    assign periph_axi.aw_valid = dut.slaves[2].aw_valid;
    assign periph_axi.aw_ready = dut.slaves[2].aw_ready;
    assign periph_axi.aw_size  = dut.slaves[2].aw_size;
    assign periph_axi.aw_burst = dut.slaves[2].aw_burst;
    assign periph_axi.aw_id    = dut.slaves[2].aw_id;
    assign periph_axi.aw_len   = dut.slaves[2].aw_len;
    assign periph_axi.w_data   = dut.slaves[2].w_data;
    assign periph_axi.w_valid  = dut.slaves[2].w_valid;
    assign periph_axi.w_ready  = dut.slaves[2].w_ready;
    assign periph_axi.w_strb   = dut.slaves[2].w_strb;
    assign periph_axi.b_resp   = dut.slaves[2].b_resp;
    assign periph_axi.b_valid  = dut.slaves[2].b_valid;
    assign periph_axi.b_ready  = dut.slaves[2].b_ready;
    assign periph_axi.ar_addr  = dut.slaves[2].ar_addr;
    assign periph_axi.ar_valid = dut.slaves[2].ar_valid;
    assign periph_axi.ar_ready = dut.slaves[2].ar_ready;
    assign periph_axi.ar_size  = dut.slaves[2].ar_size;
    assign periph_axi.ar_burst = dut.slaves[2].ar_burst;
    assign periph_axi.ar_id    = dut.slaves[2].ar_id;
    assign periph_axi.ar_len   = dut.slaves[2].ar_len;
    assign periph_axi.r_data   = dut.slaves[2].r_data;
    assign periph_axi.r_resp   = dut.slaves[2].r_resp;
    assign periph_axi.r_valid  = dut.slaves[2].r_valid;
    assign periph_axi.r_ready  = dut.slaves[2].r_ready;

    // ============================================
    // APB Probe Interface (inside peripherals module)
    // ============================================
    apb_if apb_bus (.clk(clk), .rst_n(rst_n));
    // Probe the axi2apb bridge output APB bus (s_apb_bus inside peripherals)
    assign apb_bus.paddr   = dut.peripherals_i.s_apb_bus.paddr;
    assign apb_bus.pwdata  = dut.peripherals_i.s_apb_bus.pwdata;
    assign apb_bus.prdata  = dut.peripherals_i.s_apb_bus.prdata;
    assign apb_bus.pwrite  = dut.peripherals_i.s_apb_bus.pwrite;
    assign apb_bus.psel    = dut.peripherals_i.s_apb_bus.psel;
    assign apb_bus.penable = dut.peripherals_i.s_apb_bus.penable;
    assign apb_bus.pready  = dut.peripherals_i.s_apb_bus.pready;
    assign apb_bus.pslverr = dut.peripherals_i.s_apb_bus.pslverr;

    //tb_connection include
    `include "tb_conn/uart_intf_conn.sv"

    // ============================================
    // Memory Preload (backdoor load into PULPino RAM)
    // Loads SLM files via $readmemh into DUT internal RAM
    // ============================================
    task mem_preload;
        string fw_imem_file, fw_dmem_file;
        int instr_size, data_size;

        $display("[TB] Preloading memory...");

        instr_size = dut.core_region_i.instr_mem.sp_ram_wrap_i.RAM_SIZE;
        data_size  = dut.core_region_i.data_mem.RAM_SIZE;
        $display("[TB] Instr RAM: %0d bytes, Data RAM: %0d bytes", instr_size, data_size);

        if (!$value$plusargs("FW_SLMS=%s", fw_imem_file))
            fw_imem_file = "fw/l2_stim.slm";
        if (!$value$plusargs("FW_SLMD=%s", fw_dmem_file))
            fw_dmem_file = "fw/tcdm_bank0.slm";

        // Direct $readmemh into DUT memory (same format as original PULPino TB)
        $display("[TB] Loading instruction memory from %0s", fw_imem_file);
        $readmemh(fw_imem_file, dut.core_region_i.instr_mem.sp_ram_wrap_i.sp_ram_i.mem);

        $display("[TB] Loading data memory from %0s", fw_dmem_file);
        $readmemh(fw_dmem_file, dut.core_region_i.data_mem.sp_ram_i.mem);

        // Verify first few words
        $display("[TB] Instr[0] = 0x%08h", dut.core_region_i.instr_mem.sp_ram_wrap_i.sp_ram_i.mem[0]);
        $display("[TB] Instr[1] = 0x%08h", dut.core_region_i.instr_mem.sp_ram_wrap_i.sp_ram_i.mem[1]);
        $display("[TB] Instr[2] = 0x%08h", dut.core_region_i.instr_mem.sp_ram_wrap_i.sp_ram_i.mem[2]);

        $display("[TB] Memory preload complete.");
    endtask

    // ============================================
    // Boot Sequence
    // ============================================
    initial begin
        `uvm_info("BOOT", $sformatf("Using %0s core", USE_ZERO_RISCY ? "zero-riscy" : "riscy"), UVM_LOW)

        // Set boot address to 0x0 BEFORE reset release
`ifndef SPI_BOOT_EN
        force dut.peripherals_i.apb_pulpino_i.boot_adr_q = 32'h0000_0000;
        `uvm_info("BOOT", "Boot address forced to 0x00000000", UVM_LOW)
`else
        `uvm_info("BOOT", "SPI Boot Mode: Using default boot address 0x00008000 (Boot ROM)", UVM_LOW)
`endif

        // Wait for reset release
        wait (rst_n === 1'b1);
        repeat(10) @(posedge clk);

`ifndef SPI_BOOT_EN
        // Backdoor preload memory
        mem_preload();
`else
        `uvm_info("BOOT", "SPI Boot Mode: Skipping backdoor memory preload", UVM_LOW)
`endif

        repeat(10) @(posedge clk);

        // Enable fetch to start CPU execution
        fetch_enable = 1'b1;
        `uvm_info("BOOT", "fetch_enable asserted. CPU starting...", UVM_LOW)

    end

    // ============================================
    // SPI APB Monitor (Boot Debug)
    // Monitors APB writes to SPI Master address range (0x1A100000)
    // SPI Master APB base = 0x1A100000, PADDR[11:0] used internally
    // ============================================
`ifdef SPI_BOOT_EN
    initial begin
        forever begin
            @(posedge clk);
            if (apb_bus.psel && apb_bus.penable && apb_bus.pwrite &&
                apb_bus.paddr[31:12] == 20'h1A100) begin
                `uvm_info("SPI_APB", $sformatf("WR addr=0x%08h data=0x%08h",
                    apb_bus.paddr, apb_bus.pwdata), UVM_LOW)
            end
        end
    end
`endif

    // ============================================
    // PC Tracing for Debug
    // ============================================
    initial begin
`ifdef TRACE_PC
            forever @(posedge clk) begin
                if (dut.core_region_i.CORE.RISCV_CORE.instr_req_o && dut.core_region_i.CORE.RISCV_CORE.instr_gnt_i) begin
                    logic [31:0] cur_pc;
                    cur_pc = dut.core_region_i.CORE.RISCV_CORE.pc_if;
                    @(posedge clk);
                    while (!dut.core_region_i.CORE.RISCV_CORE.instr_rvalid_i) @(posedge clk);
                    $display("[TRACE_PC] @ %t | PC: 0x%08h | Instr: 0x%08h | ra: 0x%08h", 
                         $time, cur_pc, 
                         dut.core_region_i.CORE.RISCV_CORE.instr_rdata_i,
                         dut.core_region_i.CORE.RISCV_CORE.id_stage_i.registers_i.mem[1]);
                end
            end
`endif
    end

    // ============================================
    // VIP Interfaces
    // ============================================
    uart_if     uart_probe ();
`ifdef SPI_VIP_EN
    svt_spi_if  spi_master_vif();
    svt_spi_if  spi_slave_vif();
`endif
`ifdef I2C_VIP_EN
    svt_i2c_if  i2c_master_vif();
    svt_i2c_master_wrapper i2c_master_wrapper_inst(i2c_master_vif);
`endif
    svt_gpio_if gpio_vif(.iClk(clk), .iSysRstz(rst_n), .iGPi({32'b0, gpio_out}), .oGPo());

    // UART Connections
    assign uart_probe.tx = uart_tx;

    // SPI Master Connections (QSPI 4-bit)
`ifdef SPI_VIP_EN
    assign spi_master_vif.sclk    = spi_master_clk_o;
    assign spi_master_vif.ss_n[0] = spi_master_csn0_o;
    
    assign spi_master_vif.mosi[0] = spi_master_sdo0_o;
    assign spi_master_vif.mosi[1] = spi_master_sdo1_o;
    assign spi_master_vif.mosi[2] = spi_master_sdo2_o;
    assign spi_master_vif.mosi[3] = spi_master_sdo3_o;
    
    assign spi_master_sdi0_i      = spi_master_vif.miso[0];
    assign spi_master_sdi1_i      = spi_master_vif.miso[1];
    assign spi_master_sdi2_i      = spi_master_vif.miso[2];
    assign spi_master_sdi3_i      = spi_master_vif.miso[3];

    // SPI Slave Connections (QSPI 4-bit)
    assign spi_clk_i              = spi_slave_vif.sclk;
    assign spi_cs_i               = spi_slave_vif.ss_n[0];
    
    assign spi_sdi0_i             = spi_slave_vif.mosi[0];
    assign spi_sdi1_i             = spi_slave_vif.mosi[1];
    assign spi_sdi2_i             = spi_slave_vif.mosi[2];
    assign spi_sdi3_i             = spi_slave_vif.mosi[3];
    
    assign spi_slave_vif.miso[0]  = spi_sdo0_o;
    assign spi_slave_vif.miso[1]  = spi_sdo1_o;
    assign spi_slave_vif.miso[2]  = spi_sdo2_o;
    assign spi_slave_vif.miso[3]  = spi_sdo3_o;
`endif

    // I2C Connections (Bi-directional)
`ifdef I2C_VIP_EN
    assign i2c_master_vif.SCL = !scl_padoen_o ? scl_pad_o : 1'bz;
    assign scl_pad_i          = i2c_master_vif.SCL;
    assign i2c_master_vif.SDA = !sda_padoen_o ? sda_pad_o : 1'bz;
    assign sda_pad_i          = i2c_master_vif.SDA;
`endif

    // GPIO Connections
    assign gpio_in       = gpio_vif.oGPo[31:0];

    // ============================================
    // UVM Configuration & Launch
    // ============================================
    initial begin
        // Pass virtual interfaces to UVM components via config_db
        uvm_config_db#(virtual interface uart_if)::set(null, "*", "uart_vif", uart_probe);
`ifdef SPI_VIP_EN
        uvm_config_db#(virtual svt_spi_if)::set(null, "uvm_test_top.env", "spi_master_vif", spi_master_vif);
        uvm_config_db#(virtual svt_spi_if)::set(null, "uvm_test_top.env", "spi_slave_vif",  spi_slave_vif);
`endif
`ifdef I2C_VIP_EN
        uvm_config_db#(virtual svt_i2c_if)::set(null, "uvm_test_top.env", "i2c_vif", i2c_master_vif);
`endif
        uvm_config_db#(virtual svt_gpio_if)::set(null, "uvm_test_top.env", "gpio_vif", gpio_vif);
        uvm_config_db#(virtual interface axi_if)::set(null, "*", "core_axi_vif",  core_axi);
        uvm_config_db#(virtual interface axi_if)::set(null, "*", "periph_axi_vif", periph_axi);
        uvm_config_db#(virtual interface apb_if)::set(null, "*", "apb_vif", apb_bus);

        // Launch UVM test
        run_test();
    end

    // ============================================
    // Watchdog Timer
    // ============================================
    int unsigned timeout_ns;
    initial begin
        if (!$value$plusargs("TIMEOUT_NS=%0d", timeout_ns))
            timeout_ns = 10_000_000; // 10ms default
        #(timeout_ns * 1ns);
        `uvm_fatal("WATCHDOG", $sformatf("Simulation TIMEOUT after %0d ns!", timeout_ns))
    end

    // ============================================
    // Conditional FSDB Waveform Dump
    // ============================================
    initial begin
        if ($test$plusargs("DUMP_WAVE")) begin
            `ifdef FSDB_DUMP
            string fsdb_file;
            if (!$value$plusargs("FSDB_FILE=%s", fsdb_file))
                fsdb_file = "novas.fsdb";
            $fsdbDumpfile(fsdb_file);
            $fsdbDumpvars(0, tb_top);
            $display("[TB] FSDB dump enabled: %s", fsdb_file);
            `else
            $display("[TB] WARNING: DUMP_WAVE requested but FSDB_DUMP not defined.");
            `endif
        end
    end

endmodule
