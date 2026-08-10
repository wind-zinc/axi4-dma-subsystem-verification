CHECKSUM: "2948579457 1961492116"
INSTANCE: tb_uvm_top.dut.axi_dma_inst.axi_dma_rd_inst

Condition 3 "447560406" "(((!axis_cmd_valid_reg)) && enable) 1 -1" (1 "01")
Condition 6 "891277021" "(((((addr_reg & 12'hfff) + (op_word_count_reg & 12'hfff)) >> 12) != 0) || ((op_word_count_reg >> 12) != 0)) 1 -1" (2 "01")
Condition 8 "404925130" "((op_word_count_reg >> 12) != 0) 1 -1" (2 "1")
Condition 16 "585243658" "(m_axis_read_data_tready_int && input_active_reg) 1 -1" (2 "10")
Condition 17 "1519568921" "((m_axi_rready && m_axi_rvalid) || ((!input_active_reg))) 1 -1" (2 "01")
Condition 19 "405120038" "(m_axi_rready && m_axi_rvalid) 1 -1" (1 "01")
Condition 19 "405120038" "(m_axi_rready && m_axi_rvalid) 1 -1" (2 "10")
Condition 24 "3361008218" "(m_axis_read_data_tready_int && input_active_next) 1 -1" (2 "10")
Condition 26 "341360580" "(((!out_fifo_full)) && m_axis_read_data_tvalid_int) 1 -1" (1 "01")
Condition 29 "3469234635" "(out_fifo_wr_ptr_reg == (out_fifo_rd_ptr_reg ^ {1'b1, {OUTPUT_FIFO_ADDR_WIDTH {1'b0}}})) 1 -1" (2 "1")

CHECKSUM: "3897115958 3527555297"
INSTANCE: tb_uvm_top.dut.dma_desc_manager_inst

Condition 2 "3538427454" "(write_desc_valid && write_desc_ready) 1 -1" (1 "01")
Condition 3 "3463646043" "(read_desc_valid && read_desc_ready) 1 -1" (1 "01")
Condition 4 "2536678936" "(comp_fifo_s_valid && comp_fifo_s_ready) 1 -1" (1 "01")
Condition 4 "2536678936" "(comp_fifo_s_valid && comp_fifo_s_ready) 1 -1" (2 "10")
Condition 5 "3012679793" "(status_capture_enable && read_status_valid) 1 -1" (1 "01")
Condition 6 "4132147291" "(read_status_tag != active_tag_reg) 1 -1" (2 "1")
Condition 7 "2074514692" "(status_capture_enable && write_status_valid) 1 -1" (1 "01")
Condition 8 "1832710147" "(write_status_tag != active_tag_reg) 1 -1" (2 "1")
Condition 9 "2756855882" "(write_status_len != active_length_reg) 1 -1" (2 "1")
Condition 12 "56309009" "(status_capture_enable && read_status_valid && (read_status_tag != active_tag_reg)) 1 -1" (1 "011")
Condition 12 "56309009" "(status_capture_enable && read_status_valid && (read_status_tag != active_tag_reg)) 1 -1" (4 "111")
Condition 14 "3402462175" "(status_capture_enable && write_status_valid && ((write_status_tag != active_tag_reg) || (write_status_len != active_length_reg))) 1 -1" (1 "011")
Condition 14 "3402462175" "(status_capture_enable && write_status_valid && ((write_status_tag != active_tag_reg) || (write_status_len != active_length_reg))) 1 -1" (4 "111")
Condition 34 "3677739815" "((length_cfg_reg != 0) && src_addr_fits && dst_addr_fits && length_fits && tag_fits && addresses_aligned && src_range_fits && dst_range_fits && ((!ranges_overlap))) 1 -1" (2 "101111111")
Condition 34 "3677739815" "((length_cfg_reg != 0) && src_addr_fits && dst_addr_fits && length_fits && tag_fits && addresses_aligned && src_range_fits && dst_range_fits && ((!ranges_overlap))) 1 -1" (3 "110111111")
Condition 41 "332344838" "((read_status_seen_reg || (status_capture_enable && read_status_valid)) && (write_status_seen_reg || (status_capture_enable && write_status_valid))) 1 -1" (1 "01")
Condition 43 "2592665138" "(status_capture_enable && read_status_valid) 1 -1" (1 "01")
Condition 45 "4035857873" "(status_capture_enable && write_status_valid) 1 -1" (1 "01")
Condition 50 "659171351" "(read_status_tag != active_tag_reg) 1 -1" (2 "1")
Condition 52 "1824775300" "(write_status_tag != active_tag_reg) 1 -1" (2 "1")
Condition 54 "2583063201" "(write_status_len != active_length_reg) 1 -1" (2 "1")

CHECKSUM: "2143200820 1506587916"
INSTANCE: tb_uvm_top.dut.dma_desc_manager_inst.axil_reg_if_inst.axil_reg_if_rd_inst

Condition 2 "227437852" "(reg_rd_en_reg && (reg_rd_ack || (timeout_count_reg == 2'b0))) 1 -1" (2 "10")
Condition 5 "723625504" "(reg_rd_en && ((!reg_rd_wait)) && (timeout_count_reg != 2'b0)) 1 -1" (3 "110")
Condition 7 "4090995905" "(s_axil_arvalid_next && ((!s_axil_rvalid_next))) 1 -1" (2 "10")

CHECKSUM: "1305551659 2861663954"
INSTANCE: tb_uvm_top.dut.dma_desc_manager_inst.axil_reg_if_inst.axil_reg_if_wr_inst

Condition 2 "2615630745" "(reg_wr_en_reg && (reg_wr_ack || (timeout_count_reg == 2'b0))) 1 -1" (2 "10")
Condition 5 "2937500892" "(reg_wr_en && ((!reg_wr_wait)) && (timeout_count_reg != 2'b0)) 1 -1" (3 "110")
Condition 7 "831727322" "(s_axil_awvalid_next && s_axil_wvalid_next && ((!s_axil_bvalid_next))) 1 -1" (3 "110")

CHECKSUM: "3395582926 2438467832"
INSTANCE: tb_uvm_top.dut.axi_dma_inst.axi_dma_wr_inst

Condition 7 "2388994244" "(enable && active_count_av_reg) 1 -1" (2 "10")
Condition 10 "121156761" "(((((addr_reg & 12'hfff) + (op_word_count_reg & 12'hfff)) >> 12) != 0) || ((op_word_count_reg >> 12) != 0)) 1 -1" (2 "01")
Condition 12 "4216792251" "((op_word_count_reg >> 12) != 0) 1 -1" (2 "1")
Condition 18 "2218778156" "(s_axis_write_data_tvalid || ((!first_cycle_reg))) 1 -1" (2 "01")
Condition 19 "1034164829" "(m_axi_wready_int && input_active_next) 1 -1" (1 "01")
Condition 19 "1034164829" "(m_axi_wready_int && input_active_next) 1 -1" (2 "10")
Condition 20 "2521914572" "(m_axi_wready_int && (last_transfer_reg || input_active_reg) && shift_axis_input_tready) 1 -1" (2 "101")
Condition 20 "2521914572" "(m_axi_wready_int && (last_transfer_reg || input_active_reg) && shift_axis_input_tready) 1 -1" (3 "110")
Condition 21 "291244532" "(last_transfer_reg || input_active_reg) 1 -1" (1 "00")
Condition 21 "291244532" "(last_transfer_reg || input_active_reg) 1 -1" (3 "10")
Condition 22 "1349499702" "((s_axis_write_data_tready && shift_axis_tvalid) || (((!input_active_reg)) && ((!last_transfer_reg))) || ((!shift_axis_input_tready))) 1 -1" (2 "001")
Condition 22 "1349499702" "((s_axis_write_data_tready && shift_axis_tvalid) || (((!input_active_reg)) && ((!last_transfer_reg))) || ((!shift_axis_input_tready))) 1 -1" (3 "010")
Condition 24 "1391178774" "(((!input_active_reg)) && ((!last_transfer_reg))) 1 -1" (2 "10")
Condition 24 "1391178774" "(((!input_active_reg)) && ((!last_transfer_reg))) 1 -1" (3 "11")
Condition 25 "1799191492" "(s_axis_write_data_tready && s_axis_write_data_tvalid) 1 -1" (1 "01")
Condition 25 "1799191492" "(s_axis_write_data_tready && s_axis_write_data_tvalid) 1 -1" (2 "10")
Condition 30 "2943960956" "(last_transfer_reg && (last_cycle_offset_reg > 2'b0)) 1 -1" (1 "01")
Condition 31 "4093526939" "(AXIS_KEEP_ENABLE && ((!(shift_axis_tkeep & (~({AXI_STRB_WIDTH {1'b1}} >> (AXI_STRB_WIDTH - last_cycle_offset_reg))))))) 1 -1" (1 "-0")
Condition 32 "1969961486" "(enable && active_count_av_reg) 1 -1" (2 "10")
Condition 33 "1174216930" "(m_axi_wready_int && (last_transfer_reg || input_active_next) && shift_axis_input_tready) 1 -1" (2 "101")
Condition 33 "1174216930" "(m_axi_wready_int && (last_transfer_reg || input_active_next) && shift_axis_input_tready) 1 -1" (3 "110")
Condition 34 "3152089669" "(last_transfer_reg || input_active_next) 1 -1" (1 "00")
Condition 34 "3152089669" "(last_transfer_reg || input_active_next) 1 -1" (3 "10")
Condition 37 "1232101157" "(enable && active_count_av_reg) 1 -1" (2 "10")
Condition 38 "2302528344" "(s_axis_write_data_tready && s_axis_write_data_tvalid) 1 -1" (1 "01")
Condition 38 "2302528344" "(s_axis_write_data_tready && s_axis_write_data_tvalid) 1 -1" (3 "11")
Condition 39 "4040375653" "(enable && active_count_av_reg) 1 -1" (2 "10")
Condition 44 "2732940762" "(s_axis_write_data_tlast & ((s_axis_write_data_tkeep >> (AXIS_KEEP_WIDTH_INT - offset_reg)) != 0)) 1 -1" (1 "01")
Condition 44 "2732940762" "(s_axis_write_data_tlast & ((s_axis_write_data_tkeep >> (AXIS_KEEP_WIDTH_INT - offset_reg)) != 0)) 1 -1" (3 "11")
Condition 45 "419319103" "((s_axis_write_data_tkeep >> (AXIS_KEEP_WIDTH_INT - offset_reg)) != 0) 1 -1" (2 "1")
Condition 46 "1293907213" "((active_count_reg < (2 ** STATUS_FIFO_ADDR_WIDTH)) && inc_active && ((!dec_active))) 1 -1" (1 "011")
Condition 47 "3274927420" "((active_count_reg > 6'b0) && ((!inc_active)) && dec_active) 1 -1" (1 "011")
Condition 49 "1039912385" "(((!out_fifo_full)) && m_axi_wvalid_int) 1 -1" (1 "01")
Condition 52 "3469234635" "(out_fifo_wr_ptr_reg == (out_fifo_rd_ptr_reg ^ {1'b1, {OUTPUT_FIFO_ADDR_WIDTH {1'b0}}})) 1 -1" (2 "1")
