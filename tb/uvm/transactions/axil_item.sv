/*
 * One abstract AXI4-Lite register access.
 *
 * AW/W/B and AR/R channel timing is deliberately absent from this class.
 * A sequence describes "read or write this register"; the future driver
 * translates that request into the five AXI4-Lite channel handshakes.
 */

typedef enum bit {
    AXIL_READ  = 1'b0,
    AXIL_WRITE = 1'b1
} axil_op_e;

class axil_item extends uvm_sequence_item;

    rand axil_op_e                 op;
    rand bit [AXIL_ADDR_WIDTH-1:0] addr;
    rand bit [AXIL_DATA_WIDTH-1:0] wdata;
    rand bit [AXIL_STRB_WIDTH-1:0] wstrb;
    rand bit [2:0]                 prot;

    /* Verification timing knobs.  Zero preserves the original agent
     * behavior.  A directed SVA test delays response acceptance so the DUT
     * must hold B/R payload stable while VALID is asserted. */
    rand int unsigned bready_delay;
    rand int unsigned rready_delay;

    /* Filled by the driver when the bus response is received. */
    bit [AXIL_DATA_WIDTH-1:0] rdata;
    bit [1:0]                 resp;

    /*
     * Register accesses are normally word aligned and writes normally update
     * all bytes.  "soft" lets a negative or WSTRB test override these values.
     */
    constraint c_default_addr {
        soft addr[1:0] == 2'b00;
    }

    constraint c_operation_fields {
        if (op == AXIL_READ) {
            wdata == '0;
            wstrb == '0;
        } else {
            soft wstrb == '1;
        }
    }

    constraint c_default_response_delay {
        soft bready_delay == 0;
        soft rready_delay == 0;
    }

    /* Normal software accesses are unprivileged data accesses.  Directed
     * sideband tests may override this soft default with any legal value. */
    constraint c_default_prot {
        soft prot == 3'b000;
    }

    `uvm_object_utils_begin(axil_item)
        `uvm_field_enum(axil_op_e, op, UVM_DEFAULT)
        `uvm_field_int(addr,  UVM_HEX)
        `uvm_field_int(wdata, UVM_HEX)
        `uvm_field_int(wstrb, UVM_HEX)
        `uvm_field_int(prot, UVM_BIN)
        `uvm_field_int(bready_delay, UVM_DEC)
        `uvm_field_int(rready_delay, UVM_DEC)
        `uvm_field_int(rdata, UVM_HEX)
        `uvm_field_int(resp,  UVM_HEX)
    `uvm_object_utils_end

    function new(string name = "axil_item");
        super.new(name);
        op    = AXIL_READ;
        addr  = '0;
        wdata = '0;
        wstrb = '0;
        prot  = 3'b000;
        bready_delay = 0;
        rready_delay = 0;
        rdata = '0;
        resp  = 2'b00;
    endfunction

    function bit is_okay();
        return resp == 2'b00;
    endfunction

    function string convert2string();
        if (op == AXIL_WRITE) begin
            return $sformatf(
                "AXIL_WRITE addr=0x%0h data=0x%0h strb=0x%0h prot=%0b resp=%0b",
                addr, wdata, wstrb, prot, resp
            );
        end

        return $sformatf(
            "AXIL_READ addr=0x%0h data=0x%0h prot=%0b resp=%0b",
            addr, rdata, prot, resp
        );
    endfunction

endclass
