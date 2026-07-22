class dma_env extends uvm_env;

    `uvm_component_utils(dma_env)

    axil_agent   axil_agt;
    dma_observer_monitor obs_mon;
    dma_scoreboard scb;
    dma_coverage cov;
    dma_reg_block ral;
    dma_axil_reg_adapter ral_adapter;
    uvm_reg_predictor #(axil_item) ral_predictor;

    function new(string name = "dma_env",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        ral = dma_reg_block::type_id::create("ral");
        ral.build();
        ral.reset();

        ral_adapter = dma_axil_reg_adapter::type_id::create(
            "ral_adapter");
        ral_predictor = uvm_reg_predictor#(axil_item)::type_id::create(
            "ral_predictor", this);

        uvm_config_db#(dma_reg_block)::set(
            this, "*", "ral_model", ral);

        axil_agt = axil_agent::type_id::create("axil_agt", this);
        obs_mon  = dma_observer_monitor::type_id::create("obs_mon", this);
        scb      = dma_scoreboard::type_id::create("scb", this);
        cov      = dma_coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        axil_agt.mon.ap.connect(cov.analysis_export);
        obs_mon.ap.connect(scb.analysis_export);

        ral.default_map.set_sequencer(axil_agt.sqr, ral_adapter);
        ral.default_map.set_auto_predict(0);

        ral_predictor.map     = ral.default_map;
        ral_predictor.adapter = ral_adapter;
        axil_agt.mon.ap.connect(ral_predictor.bus_in);
    endfunction

endclass
