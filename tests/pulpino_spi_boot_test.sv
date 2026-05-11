`ifndef PULPINO_SPI_BOOT_TEST_SV
`define PULPINO_SPI_BOOT_TEST_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
`ifdef SPI_VIP_EN
import svt_spi_uvm_pkg::*;
`endif

class pulpino_spi_boot_test extends base_test;
    `uvm_component_utils(pulpino_spi_boot_test)

    function new(string name = "pulpino_spi_boot_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        // Enable SPI VIP in Flash Slave mode via command line or here
        // We rely on +define+SPI_BOOT_EN to reconfigure soc_env
        super.build_phase(phase);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this, "pulpino_spi_boot_test started");

        `uvm_info(get_type_name(), "SPI Boot Test: Waiting for reset...", UVM_LOW)
        
        // Wait for reset release - but we need to load memory before or during reset
        // Usually backdoor load can happen at T=0
`ifdef SPI_VIP_EN
        if (env.spi_master_agent != null && env.spi_master_agent.mem_sequencer != null) begin
            // Load boot image into SPI VIP memory (sim CWD is debug/tc_spi_boot/)
            void'(env.spi_master_agent.mem_sequencer.backdoor.load("fw/boot_image.memh", 0));
        end
`endif

        // Wait for success message from APB stdout monitor
        `uvm_info(get_type_name(), "Waiting for 'SPI Boot Successful!' on stdout...", UVM_LOW)
        
        // The success is monitored by stdout_mon
        // We'll wait for the EOT event
        env.stdout_mon.eot_event.wait_trigger();
        
        `uvm_info(get_type_name(), "EOT received, SPI Boot test PASSED", UVM_LOW)

        #100ns;
        phase.drop_objection(this, "pulpino_spi_boot_test finished");
    endtask

endclass

`endif
