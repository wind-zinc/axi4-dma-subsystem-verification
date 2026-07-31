// Base class for subsystem tests.  Concrete tests only select/configure and
// start a virtual sequence; environment construction remains identical.
class dma_subsys_base_test extends uvm_test;
    `uvm_component_utils(dma_subsys_base_test)

    dma_subsys_env_cfg env_cfg;
    dma_subsys_memory_behavior_cfg memory_cfg;
    dma_subsys_env env;

    function new(
        string        name   = "dma_subsys_base_test",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction

    virtual function void configure();
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        env_cfg = dma_subsys_env_cfg::type_id::create("env_cfg");
        memory_cfg =
            dma_subsys_memory_behavior_cfg::type_id::create("memory_cfg");
        configure();

        uvm_config_db#(dma_subsys_env_cfg)::set(
            this, "env*", "dma_subsys_env_cfg", env_cfg);
        uvm_config_db#(dma_subsys_memory_behavior_cfg)::set(
            this, "env*", "dma_subsys_memory_behavior_cfg", memory_cfg);

        env = dma_subsys_env::type_id::create("env", this);
    endfunction

endclass
