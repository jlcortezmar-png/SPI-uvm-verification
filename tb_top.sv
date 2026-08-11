`include "uvm_macros.svh"
import uvm_pkg::*;

// =========================================================
// Declare two distinct "analysis_imp" implementations for the
// scoreboard: one to receive data from the driver, another
// from the monitor.
// =========================================================
`uvm_analysis_imp_decl(_drv)
`uvm_analysis_imp_decl(_mon)


// =========================================================
// 1. spi_seq_item
// =========================================================
class spi_seq_item extends uvm_sequence_item;
    `uvm_object_utils(spi_seq_item)

    rand bit [7:0] din;
    bit newd;
    bit [7:0] dout;

    function new(string name = "spi_seq_item");
        super.new(name);
    endfunction
endclass


// =========================================================
// 2. spi_sequence
// =========================================================
class spi_sequence extends uvm_sequence #(spi_seq_item);
    `uvm_object_utils(spi_sequence)

    spi_seq_item seq;
    int num_tr = 5;

    function new(string name = "spi_sequence");
        super.new(name);
    endfunction

    task body();
        repeat(num_tr) begin
            seq = spi_seq_item::type_id::create("seq");
            start_item(seq);
            assert(seq.randomize());
            finish_item(seq);
        end
    endtask
endclass


// =========================================================
// 3. spi_driver
// =========================================================
class spi_driver extends uvm_driver #(spi_seq_item);
    `uvm_component_utils(spi_driver)

    virtual spi_master_if vif_master;
    virtual spi_slave_if vif_slave;

    uvm_analysis_port #(spi_seq_item) ap_drv;

    function new(string name = "spi_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if(!uvm_config_db#(virtual spi_master_if)::get(this, "", "vif_master", vif_master))
            `uvm_fatal("NO_VIF", "Virtual interface has not been found for master")

        if(!uvm_config_db#(virtual spi_slave_if)::get(this, "", "vif_slave", vif_slave))
            `uvm_fatal("NO_VIF", "Virtual interface has not been found for slave")

        ap_drv = new("ap_drv", this);
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(req);

            vif_master.newd <= 1'b1;
            vif_master.din <= req.din;
            @(posedge vif_master.sclk);
            vif_master.newd <= 1'b0;
            @(posedge vif_slave.done);
            `uvm_info("DRV", $sformatf("DATA has been sent to DUT: %0d", req.din), UVM_LOW)
            ap_drv.write(req);
            @(posedge vif_master.sclk);

            seq_item_port.item_done();
        end
    endtask
endclass


// =========================================================
// 4. spi_monitor
// =========================================================
class spi_monitor extends uvm_monitor;
    `uvm_component_utils(spi_monitor)

    virtual spi_master_if vif_master;
    virtual spi_slave_if vif_slave;

    uvm_analysis_port #(spi_seq_item) ap;

    spi_seq_item seq;

    function new(string name = "spi_monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if(!uvm_config_db#(virtual spi_master_if)::get(this, "", "vif_master", vif_master))
            `uvm_fatal("NO_VIF", "Virtual interface has not been found for master")
        if(!uvm_config_db#(virtual spi_slave_if)::get(this, "", "vif_slave", vif_slave))
            `uvm_fatal("NO_VIF", "Virtual interface has not been found for slave")

        ap = new("ap", this);
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            seq = spi_seq_item::type_id::create("seq");
            @(posedge vif_master.sclk);
            wait(vif_slave.done);
            seq.dout = vif_slave.dout;
            @(posedge vif_master.sclk);
            `uvm_info("MON", $sformatf("DATA SENT: %0d", seq.dout), UVM_LOW)
            ap.write(seq);
        end
    endtask
endclass


// =========================================================
// 5. spi_scoreboard
// =========================================================
class spi_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(spi_scoreboard)

    uvm_analysis_imp_drv #(spi_seq_item, spi_scoreboard) imp_drv;
    uvm_analysis_imp_mon #(spi_seq_item, spi_scoreboard) imp_mon;

    bit [7:0] din_q[$];

    function new(string name = "spi_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        imp_drv = new("imp_drv", this);
        imp_mon = new("imp_mon", this);
    endfunction

    function void write_drv(spi_seq_item t);
        din_q.push_back(t.din);
    endfunction

    function void write_mon(spi_seq_item t);
        bit [7:0] expected;

        if (din_q.size() == 0) begin
            `uvm_warning("SCO", "Received data from monitor with no pending driver data")
            return;
        end

        expected = din_q.pop_front();

        `uvm_info("SCO", $sformatf("DRV (din) : %0d   MON (dout) : %0d", expected, t.dout), UVM_LOW)

        if (expected == t.dout)
            `uvm_info("SCO", "DATA MATCHED", UVM_LOW)
        else
            `uvm_error("SCO", "DATA MISMATCHED")

        $display("*******************************************************************************************************************************************************************************");
    endfunction
endclass


// =========================================================
// 6. spi_agent
// =========================================================
class spi_agent extends uvm_agent;
    `uvm_component_utils(spi_agent)

    spi_driver drv;
    spi_monitor mon;
    uvm_sequencer #(spi_seq_item) seqr;

    function new(string name = "spi_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv = spi_driver::type_id::create("drv", this);
        mon = spi_monitor::type_id::create("mon", this);
        seqr = uvm_sequencer#(spi_seq_item)::type_id::create("seqr", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction
endclass


// =========================================================
// 7. spi_env
// =========================================================
class spi_env extends uvm_env;
    `uvm_component_utils(spi_env)

    spi_agent age;
    spi_scoreboard sco;

    function new(string name = "spi_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        age = spi_agent::type_id::create("age", this);
        sco = spi_scoreboard::type_id::create("sco", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        age.mon.ap.connect(sco.imp_mon);
        age.drv.ap_drv.connect(sco.imp_drv);
    endfunction
endclass


// =========================================================
// 8. spi_test
// =========================================================
class spi_test extends uvm_test;
    `uvm_component_utils(spi_test)

    spi_env env;
    spi_sequence sequ;

    function new(string name = "spi_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        env = spi_env::type_id::create("env", this);
        sequ = spi_sequence::type_id::create("sequ");
        sequ.num_tr = 20;
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        sequ.start(env.age.seqr);

        phase.drop_objection(this);
    endtask
endclass


// =========================================================
// 9. tb_top
// =========================================================
module tb_top;

    spi_master_if vif_master();
    spi_slave_if vif_slave();

    spi_master dut_master(vif_master);
    spi_slave dut_slave(vif_slave);

    assign vif_slave.sclk = vif_master.sclk;
    assign vif_slave.cs   = vif_master.cs;
    assign vif_slave.mosi = vif_master.mosi;

    initial begin
        vif_master.clk = 0;
        vif_master.rst = 0;
        forever #10 vif_master.clk = ~vif_master.clk;
    end

    initial begin
        uvm_config_db#(virtual spi_master_if)::set(null, "*", "vif_master", vif_master);
        uvm_config_db#(virtual spi_slave_if)::set(null, "*", "vif_slave", vif_slave);

        run_test("spi_test");
    end

endmodule