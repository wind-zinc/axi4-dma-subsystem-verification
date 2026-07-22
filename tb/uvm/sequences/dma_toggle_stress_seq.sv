/* Uses diverse addresses, lengths, and tags to improve meaningful toggles. */
class dma_toggle_stress_seq extends dma_ral_base_seq;

    `uvm_object_utils(dma_toggle_stress_seq)

    function new(string name = "dma_toggle_stress_seq");
        super.new(name);
    endfunction

    virtual task body();
        bit [15:0] src_addr[8];
        bit [15:0] dst_addr[8];
        bit [19:0] byte_length[8];
        bit [7:0] tag[8];

        src_addr = '{16'h0100, 16'h8200, 16'h4000, 16'hc100,
                     16'h0ff0, 16'h5000, 16'h2000, 16'h6000};
        dst_addr = '{16'h8100, 16'h0200, 16'hc000, 16'h4100,
                     16'h7000, 16'h0ff0, 16'h9000, 16'he000};
        byte_length = '{20'd4, 20'd8, 20'd64, 20'd256,
                        20'd64, 20'd64, 20'd4096, 20'd4096};
        tag = '{8'h00, 8'hff, 8'haa, 8'h55,
                8'h0f, 8'hf0, 8'h33, 8'hcc};

        ral_write(ral.control, 32'h1);
        for (int index = 0; index < 8; index++) begin
            ral_submit_descriptor(src_addr[index], dst_addr[index],
                                  byte_length[index], tag[index]);
            check_and_pop_completion(tag[index], byte_length[index]);
        end
    endtask

endclass

