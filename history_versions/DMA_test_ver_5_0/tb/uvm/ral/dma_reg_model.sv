/* Register classes and the top-level DMA register block. */

class dma_rw32_reg extends uvm_reg;
    rand uvm_reg_field value;

    `uvm_object_utils(dma_rw32_reg)

    function new(string name = "dma_rw32_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        value = uvm_reg_field::type_id::create("value");
        value.configure(this, 32, 0, "RW", 0, 32'h0, 1, 1, 1);
    endfunction
endclass

class dma_ro32_reg extends uvm_reg;
    uvm_reg_field value;

    `uvm_object_utils(dma_ro32_reg)

    function new(string name = "dma_ro32_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        value = uvm_reg_field::type_id::create("value");
        value.configure(this, 32, 0, "RO", 1, 32'h0, 0, 0, 0);
    endfunction
endclass

class dma_command_reg extends uvm_reg;
    uvm_reg_field command;

    `uvm_object_utils(dma_command_reg)

    function new(string name = "dma_command_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        command = uvm_reg_field::type_id::create("command");
        /* A write of one creates a pulse; reads return zero. */
        command.configure(this, 1, 0, "WO", 1, 1'b0, 1, 0, 0);
    endfunction
endclass

class dma_control_reg extends uvm_reg;
    rand uvm_reg_field irq_enable;
    uvm_reg_field      clear_sticky;

    `uvm_object_utils(dma_control_reg)

    function new(string name = "dma_control_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        irq_enable = uvm_reg_field::type_id::create("irq_enable");
        irq_enable.configure(this, 1, 0, "RW", 0, 1'b0, 1, 1, 1);

        clear_sticky = uvm_reg_field::type_id::create("clear_sticky");
        clear_sticky.configure(this, 1, 1, "WO", 1, 1'b0, 1, 0, 0);
    endfunction
endclass

class dma_status_reg extends uvm_reg;
    uvm_reg_field active;
    uvm_reg_field req_empty;
    uvm_reg_field req_full;
    uvm_reg_field submit_ready;
    uvm_reg_field comp_valid;
    uvm_reg_field comp_full;
    uvm_reg_field irq;
    uvm_reg_field reject_full_sticky;
    uvm_reg_field reject_invalid_sticky;
    uvm_reg_field status_mismatch_sticky;
    uvm_reg_field pop_empty_sticky;

    `uvm_object_utils(dma_status_reg)

    function new(string name = "dma_status_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        active = uvm_reg_field::type_id::create("active");
        active.configure(this, 1, 0, "RO", 1, 0, 0, 0, 0);
        req_empty = uvm_reg_field::type_id::create("req_empty");
        req_empty.configure(this, 1, 1, "RO", 1, 0, 0, 0, 0);
        req_full = uvm_reg_field::type_id::create("req_full");
        req_full.configure(this, 1, 2, "RO", 1, 0, 0, 0, 0);
        submit_ready = uvm_reg_field::type_id::create("submit_ready");
        submit_ready.configure(this, 1, 3, "RO", 1, 0, 0, 0, 0);
        comp_valid = uvm_reg_field::type_id::create("comp_valid");
        comp_valid.configure(this, 1, 4, "RO", 1, 0, 0, 0, 0);
        comp_full = uvm_reg_field::type_id::create("comp_full");
        comp_full.configure(this, 1, 5, "RO", 1, 0, 0, 0, 0);
        irq = uvm_reg_field::type_id::create("irq");
        irq.configure(this, 1, 6, "RO", 1, 0, 0, 0, 0);
        reject_full_sticky = uvm_reg_field::type_id::create(
            "reject_full_sticky");
        reject_full_sticky.configure(this, 1, 7, "RO", 1, 0, 0, 0, 0);
        reject_invalid_sticky = uvm_reg_field::type_id::create(
            "reject_invalid_sticky");
        reject_invalid_sticky.configure(this, 1, 8, "RO", 1, 0, 0, 0, 0);
        status_mismatch_sticky = uvm_reg_field::type_id::create(
            "status_mismatch_sticky");
        status_mismatch_sticky.configure(this, 1, 9, "RO", 1, 0, 0, 0, 0);
        pop_empty_sticky = uvm_reg_field::type_id::create(
            "pop_empty_sticky");
        pop_empty_sticky.configure(this, 1, 10, "RO", 1, 0, 0, 0, 0);
    endfunction
endclass

class dma_queue_levels_reg extends uvm_reg;
    uvm_reg_field request_level;
    uvm_reg_field completion_level;

    `uvm_object_utils(dma_queue_levels_reg)

    function new(string name = "dma_queue_levels_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        request_level = uvm_reg_field::type_id::create("request_level");
        request_level.configure(this, 16, 0, "RO", 1, 0, 0, 0, 0);
        completion_level = uvm_reg_field::type_id::create(
            "completion_level");
        completion_level.configure(this, 16, 16, "RO", 1, 0, 0, 0, 0);
    endfunction
endclass

class dma_completion_status_reg extends uvm_reg;
    uvm_reg_field read_error;
    uvm_reg_field write_error;
    uvm_reg_field read_tag_mismatch;
    uvm_reg_field write_tag_mismatch;
    uvm_reg_field length_mismatch;

    `uvm_object_utils(dma_completion_status_reg)

    function new(string name = "dma_completion_status_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        read_error = uvm_reg_field::type_id::create("read_error");
        read_error.configure(this, 4, 0, "RO", 1, 0, 0, 0, 0);
        write_error = uvm_reg_field::type_id::create("write_error");
        write_error.configure(this, 4, 4, "RO", 1, 0, 0, 0, 0);
        read_tag_mismatch = uvm_reg_field::type_id::create(
            "read_tag_mismatch");
        read_tag_mismatch.configure(this, 1, 8, "RO", 1, 0, 0, 0, 0);
        write_tag_mismatch = uvm_reg_field::type_id::create(
            "write_tag_mismatch");
        write_tag_mismatch.configure(this, 1, 9, "RO", 1, 0, 0, 0, 0);
        length_mismatch = uvm_reg_field::type_id::create("length_mismatch");
        length_mismatch.configure(this, 1, 10, "RO", 1, 0, 0, 0, 0);
    endfunction
endclass

class dma_reg_block extends uvm_reg_block;
    rand dma_control_reg           control;
    dma_status_reg                 status;
    rand dma_rw32_reg              src_addr;
    rand dma_rw32_reg              dst_addr;
    rand dma_rw32_reg              length;
    rand dma_rw32_reg              tag;
    dma_command_reg                submit;
    dma_ro32_reg                   comp_tag;
    dma_ro32_reg                   comp_length;
    dma_completion_status_reg      comp_status;
    dma_command_reg                comp_pop;
    dma_queue_levels_reg           queue_levels;
    dma_ro32_reg                   submitted_count;
    dma_ro32_reg                   completed_count;

    `uvm_object_utils(dma_reg_block)

    function new(string name = "dma_reg_block");
        super.new(name, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        default_map = create_map(
            "default_map", 0, 4, UVM_LITTLE_ENDIAN, 1);

        control = dma_control_reg::type_id::create("control");
        control.configure(this, null, "");
        control.build();
        default_map.add_reg(control, REG_CONTROL, "RW");

        status = dma_status_reg::type_id::create("status");
        status.configure(this, null, "");
        status.build();
        default_map.add_reg(status, REG_STATUS, "RO");

        src_addr = dma_rw32_reg::type_id::create("src_addr");
        src_addr.configure(this, null, "");
        src_addr.build();
        default_map.add_reg(src_addr, REG_SRC_ADDR, "RW");

        dst_addr = dma_rw32_reg::type_id::create("dst_addr");
        dst_addr.configure(this, null, "");
        dst_addr.build();
        default_map.add_reg(dst_addr, REG_DST_ADDR, "RW");

        length = dma_rw32_reg::type_id::create("length");
        length.configure(this, null, "");
        length.build();
        default_map.add_reg(length, REG_LENGTH, "RW");

        tag = dma_rw32_reg::type_id::create("tag");
        tag.configure(this, null, "");
        tag.build();
        default_map.add_reg(tag, REG_TAG, "RW");

        submit = dma_command_reg::type_id::create("submit");
        submit.configure(this, null, "");
        submit.build();
        default_map.add_reg(submit, REG_SUBMIT, "WO");

        comp_tag = dma_ro32_reg::type_id::create("comp_tag");
        comp_tag.configure(this, null, "");
        comp_tag.build();
        default_map.add_reg(comp_tag, REG_COMP_TAG, "RO");

        comp_length = dma_ro32_reg::type_id::create("comp_length");
        comp_length.configure(this, null, "");
        comp_length.build();
        default_map.add_reg(comp_length, REG_COMP_LENGTH, "RO");

        comp_status = dma_completion_status_reg::type_id::create(
            "comp_status");
        comp_status.configure(this, null, "");
        comp_status.build();
        default_map.add_reg(comp_status, REG_COMP_STATUS, "RO");

        comp_pop = dma_command_reg::type_id::create("comp_pop");
        comp_pop.configure(this, null, "");
        comp_pop.build();
        default_map.add_reg(comp_pop, REG_COMP_POP, "WO");

        queue_levels = dma_queue_levels_reg::type_id::create("queue_levels");
        queue_levels.configure(this, null, "");
        queue_levels.build();
        default_map.add_reg(queue_levels, REG_QUEUE_LEVELS, "RO");

        submitted_count = dma_ro32_reg::type_id::create("submitted_count");
        submitted_count.configure(this, null, "");
        submitted_count.build();
        default_map.add_reg(submitted_count, REG_SUBMITTED_COUNT, "RO");

        completed_count = dma_ro32_reg::type_id::create("completed_count");
        completed_count.configure(this, null, "");
        completed_count.build();
        default_map.add_reg(completed_count, REG_COMPLETED_COUNT, "RO");

        lock_model();
    endfunction
endclass
