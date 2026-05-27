`ifndef PULPINO_SPI_BOOT_TEST_SV
`define PULPINO_SPI_BOOT_TEST_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
`ifdef SPI_VIP_EN
import svt_spi_uvm_pkg::*;
`endif

class spi_boot_vip_report_catcher extends uvm_report_catcher;
    `uvm_object_utils(spi_boot_vip_report_catcher)

    function new(string name = "spi_boot_vip_report_catcher");
        super.new(name);
    endfunction

    function bit has_substr(string msg, string needle);
        int last;
        if (needle.len() == 0 || msg.len() < needle.len())
            return 0;
        last = msg.len() - needle.len();
        for (int i = 0; i <= last; i++) begin
            if (msg.substr(i, i + needle.len() - 1) == needle)
                return 1;
        end
        return 0;
    endfunction

    virtual function action_e catch();
        string msg;
        msg = get_message();
        if (get_id() == "valid_spi_flash_command_rcvd" &&
            has_substr(msg, "does not exist in PART NUMBER S25FL512S")) begin
            set_severity(UVM_INFO);
            set_message({msg, " (suppressed for PULPino boot ROM QPI-enable compatibility)"});
            return CAUGHT;
        end
        return THROW;
    endfunction
endclass

class pulpino_spi_boot_test extends base_test;
    `uvm_component_utils(pulpino_spi_boot_test)

    spi_boot_vip_report_catcher vip_report_catcher;

`ifdef SPI_VIP_EN
    uvm_tlm_analysis_fifo #(svt_spi_transaction) spi_vip_rx_fifo;
    uvm_tlm_analysis_fifo #(svt_spi_transaction) spi_vip_tx_fifo;
`endif

    function new(string name = "pulpino_spi_boot_test", uvm_component parent = null);
        super.new(name, parent);
`ifdef SPI_VIP_EN
        spi_vip_rx_fifo = new("spi_vip_rx_fifo", this);
        spi_vip_tx_fifo = new("spi_vip_tx_fifo", this);
`endif
    endfunction

    virtual function void build_phase(uvm_phase phase);
        // Enable SPI VIP in Flash Slave mode via command line or here
        // We rely on +define+SPI_BOOT_EN to reconfigure soc_env
        vip_report_catcher = spi_boot_vip_report_catcher::type_id::create("vip_report_catcher");
        uvm_report_cb::add(null, vip_report_catcher);
        super.build_phase(phase);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
`ifdef SPI_VIP_EN
        if (env.spi_master_agent != null) begin
            env.spi_master_agent.txrx_mon.rx_xact_observed_port.connect(spi_vip_rx_fifo.analysis_export);
            env.spi_master_agent.txrx_mon.tx_xact_observed_port.connect(spi_vip_tx_fifo.analysis_export);
        end
`endif
    endfunction

`ifdef SPI_VIP_EN
    function string spi_data_summary(svt_spi_transaction tr);
        string s;
        int limit;
        s = "";
        limit = tr.data.size();
        if (limit > 16)
            limit = 16;
        for (int i = 0; i < limit; i++)
            s = {s, $sformatf("%02h ", tr.data[i])};
        if (tr.data.size() > limit)
            s = {s, "..."};
        return s;
    endfunction

    virtual task log_spi_vip_transactions();
        fork
            begin
                svt_spi_transaction tr;
                for (int i = 0; i < 16; i++) begin
                    spi_vip_rx_fifo.get(tr);
                    `uvm_info("SPI_VIP_RX", $sformatf(
                        "rx#%0d cmd=%s mode=%s addr=0x%0h dfs=%0d data=%s",
                        i, tr.flash_command.name(), tr.flash_protocol_mode.name(),
                        tr.address_frame, tr.data_frame_size, spi_data_summary(tr)), UVM_LOW)
                end
            end
            begin
                svt_spi_transaction tr;
                for (int i = 0; i < 16; i++) begin
                    spi_vip_tx_fifo.get(tr);
                    `uvm_info("SPI_VIP_TX", $sformatf(
                        "tx#%0d cmd=%s mode=%s addr=0x%0h dfs=%0d data=%s",
                        i, tr.flash_command.name(), tr.flash_protocol_mode.name(),
                        tr.address_frame, tr.data_frame_size, spi_data_summary(tr)), UVM_LOW)
                end
            end
        join_none
    endtask
`endif

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this, "pulpino_spi_boot_test started");

        `uvm_info(get_type_name(), "SPI Boot Test: Waiting for reset...", UVM_LOW)
`ifdef SPI_VIP_EN
        log_spi_vip_transactions();
`endif
        
        // Wait for reset release - but we need to load memory before or during reset
        // Usually backdoor load can happen at T=0
`ifdef SPI_VIP_EN
        if (env.spi_master_agent != null && env.spi_master_agent.mem_sequencer != null) begin
            // Load boot image into SPI VIP memory (sim CWD is debug/tc_spi_boot/)
            env.spi_master_agent.mem_sequencer.backdoor.load("fw/boot_image.memh", 0);
        end
`endif

        // Wait for success message from APB stdout monitor
        `uvm_info(get_type_name(), "Waiting for 'SPI Boot Successful!' on stdout...", UVM_LOW)
        
        // The success is monitored by stdout_mon. For waveform/debug bring-up,
        // +SPI_BOOT_FORCE_FINISH_NS=<n> can stop after a fixed runtime without
        // recompiling the build.
        begin
            int unsigned force_finish_ns;
            if ($value$plusargs("SPI_BOOT_FORCE_FINISH_NS=%0d", force_finish_ns) && force_finish_ns != 0) begin
                `uvm_info(get_type_name(), $sformatf(
                    "Debug finish requested after %0d ns via +SPI_BOOT_FORCE_FINISH_NS",
                    force_finish_ns), UVM_LOW)
                #(force_finish_ns * 1ns);
            end
            else begin
                env.stdout_mon.eot_event.wait_trigger();
                `uvm_info(get_type_name(), "EOT received, SPI Boot test PASSED", UVM_LOW)
            end
        end

        phase.drop_objection(this, "pulpino_spi_boot_test finished");
    endtask

endclass

`endif
