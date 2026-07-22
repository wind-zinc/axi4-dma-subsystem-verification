class dma_env extends uvm_env;

    `uvm_component_utils(dma_env)

    axil_agent   axil_agt;
    dma_observer_monitor obs_mon;
    dma_scoreboard scb;
    dma_coverage cov;

    function new(string name = "dma_env",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        axil_agt = axil_agent::type_id::create("axil_agt", this);
        obs_mon  = dma_observer_monitor::type_id::create("obs_mon", this);
        scb      = dma_scoreboard::type_id::create("scb", this);
        cov      = dma_coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        axil_agt.mon.ap.connect(cov.analysis_export);
        obs_mon.ap.connect(scb.analysis_export);
    endfunction

endclass
