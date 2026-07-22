class axil_agent extends uvm_agent;

    `uvm_component_utils(axil_agent)

    virtual axil_if vif;

    axil_sequencer sqr;
    axil_driver    drv;
    axil_monitor   mon;

    function new(string name = "axil_agent",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(virtual axil_if)::get(
                this, "", "vif", vif))
            `uvm_fatal("NO_VIF", "axil_agent did not receive axil_if")

        uvm_config_db#(virtual axil_if)::set(this, "mon", "vif", vif);
        mon = axil_monitor::type_id::create("mon", this);

        if (get_is_active() == UVM_ACTIVE) begin
            uvm_config_db#(virtual axil_if)::set(this, "drv", "vif", vif);
            sqr = axil_sequencer::type_id::create("sqr", this);
            drv = axil_driver::type_id::create("drv", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        if (get_is_active() == UVM_ACTIVE)
            drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction

endclass

