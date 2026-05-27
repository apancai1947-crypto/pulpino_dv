`ifndef PULPINO_SPI_FLASH_READ_TEST_SV
`define PULPINO_SPI_FLASH_READ_TEST_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
`ifdef SPI_VIP_EN
import svt_spi_uvm_pkg::*;
`endif

class pulpino_spi_flash_read_test extends base_test;
    `uvm_component_utils(pulpino_spi_flash_read_test)

    function new(string name = "pulpino_spi_flash_read_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this, "pulpino_spi_flash_read_test started");

        `uvm_info(get_type_name(), "SPI Flash Read Test: Waiting for reset...", UVM_LOW)

        // Load test data into SPI VIP flash memory (backdoor)
`ifdef SPI_VIP_EN
        if (env.spi_master_agent != null && env.spi_master_agent.mem_sequencer != null) begin
            env.spi_master_agent.mem_sequencer.backdoor.load("fw/test_data.memh", 0);
            `uvm_info(get_type_name(), "Loaded test_data.memh into VIP flash at offset 0", UVM_LOW)
        end else begin
            `uvm_error(get_type_name(), "SPI VIP agent or mem_sequencer is null!")
        end
`endif

        // Wait for EOT from firmware via stdout monitor
        `uvm_info(get_type_name(), "Waiting for EOT from firmware...", UVM_LOW)
        env.stdout_mon.eot_event.wait_trigger();
        `uvm_info(get_type_name(), "EOT received, SPI Flash Read test PASSED", UVM_LOW)

        phase.drop_objection(this, "pulpino_spi_flash_read_test finished");
    endtask

endclass

`endif
