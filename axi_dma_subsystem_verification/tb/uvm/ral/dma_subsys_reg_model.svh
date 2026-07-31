// Register abstraction model for the subsystem AXI-Lite map.

class dma_subsys_scalar_reg extends uvm_reg;
    rand uvm_reg_field value;

    `uvm_object_utils(dma_subsys_scalar_reg)

    function new(string name = "dma_subsys_scalar_reg");
        super.new(name, AXIL_DATA_WIDTH, UVM_NO_COVERAGE);
    endfunction

    virtual function void build_field(
        input int unsigned n_bits,
        input int unsigned lsb,
        input string       access,
        input bit          is_volatile,
        input uvm_reg_data_t reset_value = '0,
        input bit          has_reset = 1'b1
    );
        value = uvm_reg_field::type_id::create("value");
        value.configure(
            this, n_bits, lsb, access, is_volatile,
            reset_value, has_reset, (access == "RW"), 1);
    endfunction

endclass

class dma_subsys_ctrl_reg extends uvm_reg;
    uvm_reg_field      start;
    uvm_reg_field      abort_cmd;
    rand uvm_reg_field enable;
    uvm_reg_field      clear_status;

    `uvm_object_utils(dma_subsys_ctrl_reg)

    function new(string name = "dma_subsys_ctrl_reg");
        super.new(name, AXIL_DATA_WIDTH, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        start = uvm_reg_field::type_id::create("start");
        start.configure(this, 1, 0, "WO", 1, 0, 1, 0, 0);
        abort_cmd = uvm_reg_field::type_id::create("abort_cmd");
        abort_cmd.configure(this, 1, 1, "WO", 1, 0, 1, 0, 0);
        enable = uvm_reg_field::type_id::create("enable");
        enable.configure(this, 1, 2, "RW", 0, 0, 1, 1, 1);
        clear_status = uvm_reg_field::type_id::create("clear_status");
        clear_status.configure(this, 1, 4, "WO", 1, 0, 1, 0, 0);
    endfunction

endclass

class dma_subsys_status_reg extends uvm_reg;
    uvm_reg_field busy;
    uvm_reg_field done_pending;
    uvm_reg_field error_pending;
    uvm_reg_field cmd_valid;
    uvm_reg_field abort_seen;
    uvm_reg_field last_error;

    `uvm_object_utils(dma_subsys_status_reg)

    function new(string name = "dma_subsys_status_reg");
        super.new(name, AXIL_DATA_WIDTH, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        busy = uvm_reg_field::type_id::create("busy");
        busy.configure(this, 1, 0, "RO", 1, 0, 1, 0, 0);
        done_pending = uvm_reg_field::type_id::create("done_pending");
        done_pending.configure(this, 1, 1, "RO", 1, 0, 1, 0, 0);
        error_pending = uvm_reg_field::type_id::create("error_pending");
        error_pending.configure(this, 1, 2, "RO", 1, 0, 1, 0, 0);
        cmd_valid = uvm_reg_field::type_id::create("cmd_valid");
        cmd_valid.configure(this, 1, 3, "RO", 1, 0, 1, 0, 0);
        abort_seen = uvm_reg_field::type_id::create("abort_seen");
        abort_seen.configure(this, 1, 4, "RO", 1, 0, 1, 0, 0);
        last_error = uvm_reg_field::type_id::create("last_error");
        last_error.configure(this, 8, 8, "RO", 1, 0, 1, 0, 0);
    endfunction

endclass

class dma_subsys_irq_status_reg extends uvm_reg;
    uvm_reg_field done_pending;
    uvm_reg_field error_pending;
    uvm_reg_field busy;
    uvm_reg_field fault_pending;
    uvm_reg_field any_status;

    `uvm_object_utils(dma_subsys_irq_status_reg)

    function new(string name = "dma_subsys_irq_status_reg");
        super.new(name, AXIL_DATA_WIDTH, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        done_pending = uvm_reg_field::type_id::create("done_pending");
        done_pending.configure(this, 2, 0, "RO", 1, 0, 1, 0, 0);
        error_pending = uvm_reg_field::type_id::create("error_pending");
        error_pending.configure(this, 2, 8, "RO", 1, 0, 1, 0, 0);
        busy = uvm_reg_field::type_id::create("busy");
        busy.configure(this, 2, 16, "RO", 1, 0, 1, 0, 0);
        fault_pending = uvm_reg_field::type_id::create("fault_pending");
        fault_pending.configure(this, 1, 30, "RO", 1, 0, 1, 0, 0);
        any_status = uvm_reg_field::type_id::create("any_status");
        any_status.configure(this, 1, 31, "RO", 1, 0, 1, 0, 0);
    endfunction

endclass

class dma_subsys_irq_enable_reg extends uvm_reg;
    rand uvm_reg_field done_enable;
    rand uvm_reg_field error_enable;
    rand uvm_reg_field fault_enable;

    `uvm_object_utils(dma_subsys_irq_enable_reg)

    function new(string name = "dma_subsys_irq_enable_reg");
        super.new(name, AXIL_DATA_WIDTH, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        done_enable = uvm_reg_field::type_id::create("done_enable");
        done_enable.configure(this, 2, 0, "RW", 0, 0, 1, 1, 1);
        error_enable = uvm_reg_field::type_id::create("error_enable");
        error_enable.configure(this, 2, 8, "RW", 0, 0, 1, 1, 1);
        fault_enable = uvm_reg_field::type_id::create("fault_enable");
        fault_enable.configure(this, 1, 30, "RW", 0, 0, 1, 1, 1);
    endfunction

endclass

class dma_subsys_irq_clear_reg extends uvm_reg;
    uvm_reg_field done_clear;
    uvm_reg_field error_clear;
    uvm_reg_field fault_clear;

    `uvm_object_utils(dma_subsys_irq_clear_reg)

    function new(string name = "dma_subsys_irq_clear_reg");
        super.new(name, AXIL_DATA_WIDTH, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        done_clear = uvm_reg_field::type_id::create("done_clear");
        done_clear.configure(this, 2, 0, "WO", 1, 0, 1, 0, 0);
        error_clear = uvm_reg_field::type_id::create("error_clear");
        error_clear.configure(this, 2, 8, "WO", 1, 0, 1, 0, 0);
        fault_clear = uvm_reg_field::type_id::create("fault_clear");
        fault_clear.configure(this, 1, 30, "WO", 1, 0, 1, 0, 0);
    endfunction

endclass

class dma_subsys_irq_last_error_reg extends uvm_reg;
    uvm_reg_field ch0_error;
    uvm_reg_field ch1_error;

    `uvm_object_utils(dma_subsys_irq_last_error_reg)

    function new(string name = "dma_subsys_irq_last_error_reg");
        super.new(name, AXIL_DATA_WIDTH, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        ch0_error = uvm_reg_field::type_id::create("ch0_error");
        ch0_error.configure(this, 8, 0, "RO", 1, 0, 1, 0, 0);
        ch1_error = uvm_reg_field::type_id::create("ch1_error");
        ch1_error.configure(this, 8, 8, "RO", 1, 0, 1, 0, 0);
    endfunction

endclass

class dma_subsys_route_status_reg extends uvm_reg;
    uvm_reg_field route_matrix;
    uvm_reg_field route_active;

    `uvm_object_utils(dma_subsys_route_status_reg)

    function new(string name = "dma_subsys_route_status_reg");
        super.new(name, AXIL_DATA_WIDTH, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        route_matrix = uvm_reg_field::type_id::create("route_matrix");
        route_matrix.configure(this, 4, 0, "RO", 1, 0, 1, 0, 0);
        route_active = uvm_reg_field::type_id::create("route_active");
        route_active.configure(this, 2, 4, "RO", 1, 0, 1, 0, 0);
    endfunction

endclass

class dma_subsys_fault_status_reg extends uvm_reg;
    uvm_reg_field code;
    uvm_reg_field source;

    `uvm_object_utils(dma_subsys_fault_status_reg)

    function new(string name = "dma_subsys_fault_status_reg");
        super.new(name, AXIL_DATA_WIDTH, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        code = uvm_reg_field::type_id::create("code");
        code.configure(this, 8, 0, "RO", 1, 0, 1, 0, 0);
        source = uvm_reg_field::type_id::create("source");
        source.configure(this, 3, 8, "RO", 1, 0, 1, 0, 0);
    endfunction

endclass

class dma_subsys_channel_reg_block extends uvm_reg_block;
    rand dma_subsys_ctrl_reg   ctrl;
    dma_subsys_status_reg      status;
    rand dma_subsys_scalar_reg src_addr;
    rand dma_subsys_scalar_reg dst_addr;
    rand dma_subsys_scalar_reg length;
    rand dma_subsys_scalar_reg route;
    rand dma_subsys_scalar_reg sw_tag;
    dma_subsys_scalar_reg      last_hw_tag;
    dma_subsys_scalar_reg      completed_len;
    dma_subsys_scalar_reg      last_error;
    dma_subsys_scalar_reg      cmd_count;
    dma_subsys_scalar_reg      done_count;
    dma_subsys_scalar_reg      version;

    `uvm_object_utils(dma_subsys_channel_reg_block)

    function new(string name = "dma_subsys_channel_reg_block");
        super.new(name, UVM_NO_COVERAGE);
    endfunction

    protected function dma_subsys_scalar_reg add_scalar(
        input string name,
        input uvm_reg_addr_t offset,
        input int unsigned n_bits,
        input string access,
        input bit is_volatile,
        input uvm_reg_data_t reset_value = '0
    );
        dma_subsys_scalar_reg reg_handle;

        reg_handle = dma_subsys_scalar_reg::type_id::create(name);
        reg_handle.configure(this, null, "");
        reg_handle.build_field(
            n_bits, 0, access, is_volatile, reset_value, 1'b1);
        default_map.add_reg(reg_handle, offset, access);
        return reg_handle;
    endfunction

    virtual function void build();
        default_map = create_map(
            "default_map", 0, AXIL_STRB_WIDTH, UVM_LITTLE_ENDIAN, 1);

        ctrl = dma_subsys_ctrl_reg::type_id::create("ctrl");
        ctrl.configure(this, null, "");
        ctrl.build();
        default_map.add_reg(ctrl, REG_CTRL, "RW");

        status = dma_subsys_status_reg::type_id::create("status");
        status.configure(this, null, "");
        status.build();
        default_map.add_reg(status, REG_STATUS, "RO");

        src_addr = add_scalar(
            "src_addr", REG_SRC_ADDR, AXI_ADDR_WIDTH, "RW", 0);
        dst_addr = add_scalar(
            "dst_addr", REG_DST_ADDR, AXI_ADDR_WIDTH, "RW", 0);
        length = add_scalar(
            "length", REG_LENGTH, LEN_WIDTH, "RW", 0);
        route = add_scalar("route", REG_ROUTE, 1, "RW", 0);
        sw_tag = add_scalar("sw_tag", REG_SW_TAG, 8, "RW", 0);
        last_hw_tag = add_scalar(
            "last_hw_tag", REG_LAST_HW_TAG, 8, "RO", 1);
        completed_len = add_scalar(
            "completed_len", REG_COMPLETED_LEN, LEN_WIDTH, "RO", 1);
        last_error = add_scalar(
            "last_error", REG_LAST_ERROR, 8, "RO", 1);
        cmd_count = add_scalar(
            "cmd_count", REG_CMD_COUNT, 32, "RO", 1);
        done_count = add_scalar(
            "done_count", REG_DONE_COUNT, 32, "RO", 1);
        version = add_scalar(
            "version", REG_VERSION, 32, "RO", 0, VERSION_VALUE);
    endfunction

endclass

class dma_subsys_global_reg_block extends uvm_reg_block;
    dma_subsys_irq_status_reg     irq_status;
    rand dma_subsys_irq_enable_reg irq_enable;
    dma_subsys_irq_clear_reg      irq_clear;
    dma_subsys_irq_last_error_reg irq_last_error;
    dma_subsys_scalar_reg         ch0_done_count;
    dma_subsys_scalar_reg         ch1_done_count;
    dma_subsys_scalar_reg         ch0_error_count;
    dma_subsys_scalar_reg         ch1_error_count;
    dma_subsys_route_status_reg   route_status;
    dma_subsys_scalar_reg         version;
    dma_subsys_fault_status_reg   fault_status;

    `uvm_object_utils(dma_subsys_global_reg_block)

    function new(string name = "dma_subsys_global_reg_block");
        super.new(name, UVM_NO_COVERAGE);
    endfunction

    protected function dma_subsys_scalar_reg add_ro32(
        input string name,
        input uvm_reg_addr_t offset,
        input bit is_volatile,
        input uvm_reg_data_t reset_value = '0
    );
        dma_subsys_scalar_reg reg_handle;

        reg_handle = dma_subsys_scalar_reg::type_id::create(name);
        reg_handle.configure(this, null, "");
        reg_handle.build_field(
            32, 0, "RO", is_volatile, reset_value, 1'b1);
        default_map.add_reg(reg_handle, offset, "RO");
        return reg_handle;
    endfunction

    virtual function void build();
        default_map = create_map(
            "default_map", 0, AXIL_STRB_WIDTH, UVM_LITTLE_ENDIAN, 1);

        irq_status = dma_subsys_irq_status_reg::type_id::create(
            "irq_status");
        irq_status.configure(this, null, "");
        irq_status.build();
        default_map.add_reg(irq_status, REG_IRQ_STATUS, "RO");

        irq_enable = dma_subsys_irq_enable_reg::type_id::create(
            "irq_enable");
        irq_enable.configure(this, null, "");
        irq_enable.build();
        default_map.add_reg(irq_enable, REG_IRQ_ENABLE, "RW");

        irq_clear = dma_subsys_irq_clear_reg::type_id::create(
            "irq_clear");
        irq_clear.configure(this, null, "");
        irq_clear.build();
        default_map.add_reg(irq_clear, REG_IRQ_CLEAR, "WO");

        irq_last_error = dma_subsys_irq_last_error_reg::type_id::create(
            "irq_last_error");
        irq_last_error.configure(this, null, "");
        irq_last_error.build();
        default_map.add_reg(irq_last_error, REG_IRQ_LAST_ERROR, "RO");

        ch0_done_count = add_ro32(
            "ch0_done_count", REG_CH0_DONE_COUNT, 1);
        ch1_done_count = add_ro32(
            "ch1_done_count", REG_CH1_DONE_COUNT, 1);
        ch0_error_count = add_ro32(
            "ch0_error_count", REG_CH0_ERROR_COUNT, 1);
        ch1_error_count = add_ro32(
            "ch1_error_count", REG_CH1_ERROR_COUNT, 1);

        route_status = dma_subsys_route_status_reg::type_id::create(
            "route_status");
        route_status.configure(this, null, "");
        route_status.build();
        default_map.add_reg(route_status, REG_ROUTE_STATUS, "RO");

        version = add_ro32(
            "version", REG_GLOBAL_VERSION, 0, VERSION_VALUE);

        fault_status = dma_subsys_fault_status_reg::type_id::create(
            "fault_status");
        fault_status.configure(this, null, "");
        fault_status.build();
        default_map.add_reg(fault_status, REG_FAULT_STATUS, "RO");
    endfunction

endclass

class dma_subsys_reg_block extends uvm_reg_block;
    rand dma_subsys_channel_reg_block channel[DMA_CH_COUNT];
    rand dma_subsys_global_reg_block  global_regs;

    `uvm_object_utils(dma_subsys_reg_block)

    function new(string name = "dma_subsys_reg_block");
        super.new(name, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        uvm_reg_addr_t channel_base[DMA_CH_COUNT];

        channel_base[0] = CH0_CTRL_BASE_ADDR;
        channel_base[1] = CH1_CTRL_BASE_ADDR;
        default_map = create_map(
            "default_map", 0, AXIL_STRB_WIDTH, UVM_LITTLE_ENDIAN, 1);

        foreach (channel[index]) begin
            channel[index] =
                dma_subsys_channel_reg_block::type_id::create(
                    $sformatf("channel%0d", index));
            channel[index].configure(this, "");
            channel[index].build();
            default_map.add_submap(
                channel[index].default_map, channel_base[index]);
        end

        global_regs = dma_subsys_global_reg_block::type_id::create(
            "global_regs");
        global_regs.configure(this, "");
        global_regs.build();
        default_map.add_submap(
            global_regs.default_map, GLOBAL_IRQ_BASE_ADDR);

        lock_model();
    endfunction

endclass
