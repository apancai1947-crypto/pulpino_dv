`ifndef PULPINO_SPI_TEST_SV
`define PULPINO_SPI_TEST_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

class pulpino_spi_test extends base_test;
    `uvm_component_utils(pulpino_spi_test)

    function new(string name = "pulpino_spi_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        `uvm_info(get_type_name(), "SPI test build_phase complete", UVM_LOW)
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this, "pulpino_spi_test started");

        // Wait for EOT from memory-mapped stdout monitor
        `uvm_info(get_type_name(), "Waiting for EOT from stdout monitor...", UVM_LOW)
        env.stdout_mon.eot_event.wait_trigger();
        `uvm_info(get_type_name(), "EOT received, ending test", UVM_LOW)

        #100ns;
        phase.drop_objection(this, "pulpino_spi_test finished");
    endtask

endclass

`endif
