// sim/filelist.f — PULPino UVM DV source file list
// IPs cloned from github.com/pulp-platform (Pulpino_v2.1 tag)
//
// All paths relative to project root (pulpino_dv/)

+define+VERILATOR

// ============================================
// RTL Includes (must compile first)
// ============================================
repo/pulpino/rtl/includes/config.sv
repo/pulpino/rtl/includes/axi_bus.sv
repo/pulpino/rtl/includes/apb_bus.sv
repo/pulpino/rtl/includes/debug_bus.sv
repo/pulpino/rtl/includes/apu_defines.sv

// ============================================
// RTL Components (low-level building blocks)
// ============================================
repo/pulpino/rtl/components/sp_ram.sv
repo/pulpino/rtl/components/dp_ram.sv
repo/pulpino/rtl/components/generic_fifo.sv
repo/pulpino/rtl/components/cluster_clock_gating.sv
repo/pulpino/rtl/components/cluster_clock_inverter.sv
repo/pulpino/rtl/components/cluster_clock_mux2.sv
repo/pulpino/rtl/components/pulp_clock_gating.sv
repo/pulpino/rtl/components/pulp_clock_inverter.sv
repo/pulpino/rtl/components/pulp_clock_mux2.sv
repo/pulpino/rtl/components/rstgen.sv

// ============================================
// IP Submodules — APB IPs
// ============================================
repo/pulpino/ips/apb/apb_uart_sv/apb_uart_sv.sv
repo/pulpino/ips/apb/apb_uart_sv/io_generic_fifo.sv
repo/pulpino/ips/apb/apb_uart_sv/uart_interrupt.sv
repo/pulpino/ips/apb/apb_uart_sv/uart_rx.sv
repo/pulpino/ips/apb/apb_uart_sv/uart_tx.sv
repo/pulpino/ips/apb/apb_gpio/apb_gpio.sv
repo/pulpino/ips/apb/apb_spi_master/apb_spi_master.sv
repo/pulpino/ips/apb/apb_spi_master/spi_master_apb_if.sv
repo/pulpino/ips/axi/axi_spi_master/spi_master_clkgen.sv
repo/pulpino/ips/axi/axi_spi_master/spi_master_controller.sv
repo/pulpino/ips/axi/axi_spi_master/spi_master_fifo.sv
repo/pulpino/ips/axi/axi_spi_master/spi_master_rx.sv
repo/pulpino/ips/axi/axi_spi_master/spi_master_tx.sv
repo/pulpino/ips/apb/apb_timer/apb_timer.sv
repo/pulpino/ips/apb/apb_timer/timer.sv
repo/pulpino/ips/apb/apb_event_unit/apb_event_unit.sv
repo/pulpino/ips/apb/apb_event_unit/generic_service_unit.sv
repo/pulpino/ips/apb/apb_event_unit/include/defines_event_unit.sv
repo/pulpino/ips/apb/apb_event_unit/sleep_unit.sv
repo/pulpino/ips/apb/apb_i2c/i2c_master_defines.sv
repo/pulpino/ips/apb/apb_i2c/apb_i2c.sv
repo/pulpino/ips/apb/apb_i2c/i2c_master_bit_ctrl.sv
repo/pulpino/ips/apb/apb_i2c/i2c_master_byte_ctrl.sv
repo/pulpino/ips/apb/apb_fll_if/apb_fll_if.sv
repo/pulpino/ips/apb/apb_pulpino/apb_pulpino.sv
repo/pulpino/ips/apb/apb2per/apb2per.sv
repo/pulpino/ips/apb/apb_node/apb_node.sv
repo/pulpino/ips/apb/apb_node/apb_node_wrap.sv

// ============================================
// IP Submodules — AXI IPs
// ============================================
repo/pulpino/ips/axi/axi2apb/AXI_2_APB.sv
repo/pulpino/ips/axi/axi2apb/AXI_2_APB_32.sv
repo/pulpino/ips/axi/axi2apb/axi2apb.sv
repo/pulpino/ips/axi/axi2apb/axi2apb32.sv
repo/pulpino/ips/axi/axi_node/apb_regs_top.sv
repo/pulpino/ips/axi/axi_node/axi_AR_allocator.sv
repo/pulpino/ips/axi/axi_node/axi_AW_allocator.sv
repo/pulpino/ips/axi/axi_node/axi_ArbitrationTree.sv
repo/pulpino/ips/axi/axi_node/axi_BR_allocator.sv
repo/pulpino/ips/axi/axi_node/axi_BW_allocator.sv
repo/pulpino/ips/axi/axi_node/axi_DW_allocator.sv
repo/pulpino/ips/axi/axi_node/axi_FanInPrimitive_Req.sv
repo/pulpino/ips/axi/axi_node/axi_RR_Flag_Req.sv
repo/pulpino/ips/axi/axi_node/axi_address_decoder_AR.sv
repo/pulpino/ips/axi/axi_node/axi_address_decoder_AW.sv
repo/pulpino/ips/axi/axi_node/axi_address_decoder_BR.sv
repo/pulpino/ips/axi/axi_node/axi_address_decoder_BW.sv
repo/pulpino/ips/axi/axi_node/axi_address_decoder_DW.sv
repo/pulpino/ips/axi/axi_node/axi_multiplexer.sv
repo/pulpino/ips/axi/axi_node/axi_node.sv
repo/pulpino/ips/axi/axi_node/axi_regs_top.sv
repo/pulpino/ips/axi/axi_node/axi_request_block.sv
repo/pulpino/ips/axi/axi_node/axi_response_block.sv
repo/pulpino/ips/axi/axi_slice/axi_ar_buffer.sv
repo/pulpino/ips/axi/axi_slice/axi_aw_buffer.sv
repo/pulpino/ips/axi/axi_slice/axi_b_buffer.sv
repo/pulpino/ips/axi/axi_slice/axi_buffer.sv
repo/pulpino/ips/axi/axi_slice/axi_r_buffer.sv
repo/pulpino/ips/axi/axi_slice/axi_slice.sv
repo/pulpino/ips/axi/axi_slice/axi_w_buffer.sv
repo/pulpino/ips/axi/axi_mem_if_DP/axi_mem_if_DP.sv
repo/pulpino/ips/axi/axi_mem_if_DP/axi_mem_if_DP_hybr.sv
repo/pulpino/ips/axi/axi_mem_if_DP/axi_mem_if_SP.sv
repo/pulpino/ips/axi/axi_mem_if_DP/axi_mem_if_multi_bank.sv
repo/pulpino/ips/axi/axi_mem_if_DP/axi_read_only_ctrl.sv
repo/pulpino/ips/axi/axi_mem_if_DP/axi_write_only_ctrl.sv
repo/pulpino/ips/axi/axi_spi_master/axi_spi_master.sv
repo/pulpino/ips/axi/axi_spi_master/spi_master_axi_if.sv
repo/pulpino/ips/axi/axi_spi_master/spi_master_clkgen.sv
repo/pulpino/ips/axi/axi_spi_master/spi_master_controller.sv
repo/pulpino/ips/axi/axi_spi_master/spi_master_fifo.sv
repo/pulpino/ips/axi/axi_spi_master/spi_master_rx.sv
repo/pulpino/ips/axi/axi_spi_master/spi_master_tx.sv
repo/pulpino/ips/axi/axi_spi_slave/axi_spi_slave.sv
repo/pulpino/ips/axi/axi_spi_slave/spi_slave_axi_plug.sv
repo/pulpino/ips/axi/axi_spi_slave/spi_slave_cmd_parser.sv
repo/pulpino/ips/axi/axi_spi_slave/spi_slave_controller.sv
repo/pulpino/ips/axi/axi_spi_slave/spi_slave_dc_fifo.sv
repo/pulpino/ips/axi/axi_spi_slave/spi_slave_regs.sv
repo/pulpino/ips/axi/axi_spi_slave/spi_slave_rx.sv
repo/pulpino/ips/axi/axi_spi_slave/spi_slave_syncro.sv
repo/pulpino/ips/axi/axi_spi_slave/spi_slave_tx.sv
repo/pulpino/ips/axi/core2axi/core2axi.sv
repo/pulpino/ips/axi/axi_slice_dc/dc_token_ring.v
repo/pulpino/ips/axi/axi_slice_dc/dc_token_ring_fifo_din.v
repo/pulpino/ips/axi/axi_slice_dc/dc_token_ring_fifo_dout.v
repo/pulpino/ips/axi/axi_slice_dc/dc_data_buffer.v
repo/pulpino/ips/axi/axi_slice_dc/dc_full_detector.v
repo/pulpino/ips/axi/axi_slice_dc/dc_synchronizer.v
repo/pulpino/ips/axi/axi_slice_dc/axi_slice_dc_master.sv
repo/pulpino/ips/axi/axi_slice_dc/axi_slice_dc_slave.sv

// ============================================
// IP Submodules — Debug
// ============================================
repo/pulpino/ips/adv_dbg_if/rtl/adbg_axi_defines.v
repo/pulpino/ips/adv_dbg_if/rtl/adbg_defines.v
repo/pulpino/ips/adv_dbg_if/rtl/adbg_or1k_defines.v
repo/pulpino/ips/adv_dbg_if/rtl/adbg_tap_defines.v
repo/pulpino/ips/adv_dbg_if/rtl/adbg_crc32.v
repo/pulpino/ips/adv_dbg_if/rtl/adbg_tap_top.v
repo/pulpino/ips/adv_dbg_if/rtl/bytefifo.v
repo/pulpino/ips/adv_dbg_if/rtl/syncflop.v
repo/pulpino/ips/adv_dbg_if/rtl/syncreg.v
repo/pulpino/ips/adv_dbg_if/rtl/adbg_axi_biu.sv
repo/pulpino/ips/adv_dbg_if/rtl/adbg_axi_module.sv
repo/pulpino/ips/adv_dbg_if/rtl/adbg_axionly_top.sv
repo/pulpino/ips/adv_dbg_if/rtl/adbg_or1k_biu.sv
repo/pulpino/ips/adv_dbg_if/rtl/adbg_or1k_module.sv
repo/pulpino/ips/adv_dbg_if/rtl/adbg_or1k_status_reg.sv
repo/pulpino/ips/adv_dbg_if/rtl/adbg_top.sv
repo/pulpino/ips/adv_dbg_if/rtl/adv_dbg_if.sv

// ============================================
// IP Submodules — RISC-V Cores
// ============================================

// RISCY core
repo/pulpino/ips/riscv/include/apu_core_package.sv
repo/pulpino/ips/riscv/include/riscv_defines.sv
repo/pulpino/ips/riscv/include/riscv_tracer_defines.sv
repo/pulpino/ips/riscv/riscv_alu.sv
repo/pulpino/ips/riscv/riscv_alu_basic.sv
repo/pulpino/ips/riscv/riscv_alu_div.sv
repo/pulpino/ips/riscv/riscv_compressed_decoder.sv
repo/pulpino/ips/riscv/riscv_controller.sv
repo/pulpino/ips/riscv/riscv_cs_registers.sv
repo/pulpino/ips/riscv/riscv_debug_unit.sv
repo/pulpino/ips/riscv/riscv_decoder.sv
repo/pulpino/ips/riscv/riscv_int_controller.sv
repo/pulpino/ips/riscv/riscv_ex_stage.sv
repo/pulpino/ips/riscv/riscv_hwloop_controller.sv
repo/pulpino/ips/riscv/riscv_hwloop_regs.sv
repo/pulpino/ips/riscv/riscv_id_stage.sv
repo/pulpino/ips/riscv/riscv_if_stage.sv
repo/pulpino/ips/riscv/riscv_load_store_unit.sv
repo/pulpino/ips/riscv/riscv_mult.sv
repo/pulpino/ips/riscv/riscv_prefetch_buffer.sv
repo/pulpino/ips/riscv/riscv_prefetch_L0_buffer.sv
repo/pulpino/ips/riscv/riscv_core.sv
repo/pulpino/ips/riscv/riscv_apu_disp.sv
repo/pulpino/ips/riscv/riscv_fetch_fifo.sv
repo/pulpino/ips/riscv/riscv_L0_buffer.sv
repo/pulpino/ips/riscv/riscv_register_file.sv

// zero-riscy core
repo/pulpino/ips/zero-riscy/include/zeroriscy_defines.sv
repo/pulpino/ips/zero-riscy/include/zeroriscy_tracer_defines.sv
repo/pulpino/ips/zero-riscy/zeroriscy_alu.sv
repo/pulpino/ips/zero-riscy/zeroriscy_compressed_decoder.sv
repo/pulpino/ips/zero-riscy/zeroriscy_controller.sv
repo/pulpino/ips/zero-riscy/zeroriscy_cs_registers.sv
repo/pulpino/ips/zero-riscy/zeroriscy_debug_unit.sv
repo/pulpino/ips/zero-riscy/zeroriscy_decoder.sv
repo/pulpino/ips/zero-riscy/zeroriscy_int_controller.sv
repo/pulpino/ips/zero-riscy/zeroriscy_ex_block.sv
repo/pulpino/ips/zero-riscy/zeroriscy_id_stage.sv
repo/pulpino/ips/zero-riscy/zeroriscy_if_stage.sv
repo/pulpino/ips/zero-riscy/zeroriscy_load_store_unit.sv
repo/pulpino/ips/zero-riscy/zeroriscy_multdiv_slow.sv
repo/pulpino/ips/zero-riscy/zeroriscy_multdiv_fast.sv
repo/pulpino/ips/zero-riscy/zeroriscy_prefetch_buffer.sv
repo/pulpino/ips/zero-riscy/zeroriscy_fetch_fifo.sv
repo/pulpino/ips/zero-riscy/zeroriscy_core.sv
repo/pulpino/ips/zero-riscy/zeroriscy_register_file.sv

// IP Submodules — FPU (compile separately with +define+RISCY_RV32F, conflicts with riscv_defines package)
// NOTE: FPU files excluded from default build. Add via FPU_FILELIST when RISCY_RV32F=1.

// ============================================
// PULPino Top-level RTL
// ============================================
repo/pulpino/rtl/sp_ram_wrap.sv
repo/pulpino/rtl/instr_ram_wrap.sv
repo/pulpino/rtl/dp_ram_wrap.sv
repo/pulpino/rtl/ram_mux.sv
repo/pulpino/rtl/random_stalls.sv
repo/pulpino/rtl/boot_rom_wrap.sv
repo/pulpino/rtl/boot_code.sv
repo/pulpino/rtl/core2axi_wrap.sv
repo/pulpino/rtl/axi_mem_if_SP_wrap.sv
repo/pulpino/rtl/axi_node_intf_wrap.sv
repo/pulpino/rtl/axi_slice_wrap.sv
repo/pulpino/rtl/axi2apb_wrap.sv
repo/pulpino/rtl/axi_spi_slave_wrap.sv
repo/pulpino/rtl/periph_bus_wrap.sv
repo/pulpino/rtl/core_region.sv
repo/pulpino/rtl/peripherals.sv
repo/pulpino/rtl/clk_rst_gen.sv
repo/pulpino/rtl/apb_mock_uart.sv
repo/pulpino/rtl/pulpino_top.sv

// ============================================
// PULPino TB helpers (for existing DPI modules)
// ============================================
repo/pulpino/tb/jtag_dpi.sv
repo/pulpino/tb/i2c_eeprom_model.sv
repo/pulpino/tb/if_spi_master.sv
repo/pulpino/tb/if_spi_slave.sv
repo/pulpino/tb/pkg_spi.sv
repo/pulpino/tb/uart.sv

// ============================================
// UVM Verification Environment
// ============================================

// Interfaces
tb/axi_if.sv
tb/apb_if.sv
tb/uart_if.sv

// Transaction types
tb/env/axi_transaction.sv
tb/env/apb_transaction.sv

// AXI agent
tb/env/axi_monitor.sv
tb/env/axi_agent.sv

// APB agent
tb/env/apb_monitor.sv
tb/env/apb_agent.sv

// UART TUBE monitor
tb/uart_monitor.sv

// Stdout memory-mapped monitor
tb/stdout_monitor.sv

// Scoreboard and config
tb/env/soc_scoreboard.sv
tb/env/soc_config.sv
tb/env/soc_env.sv

// Coverage
tb/coverage/axi_coverage.sv
tb/coverage/apb_coverage.sv

// Sequences
seq_lib/base_seq.sv
seq_lib/uart_dce_rx_sequence.sv

// Tests
tests/base_test.sv
tests/pulpino_uart_test.sv
tests/pulpino_spi_test.sv
tests/pulpino_spi_boot_test.sv
tests/pulpino_spi_flash_read_test.sv

// Testbench top
tb/tb_top.sv
