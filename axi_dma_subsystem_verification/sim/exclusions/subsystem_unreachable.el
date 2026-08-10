CHECKSUM: "4154399110 2789773242"
MODULE: dma_desc_manager

Block 67 "894737450" "base_error_reg[seq_index] <= DMA_ERR_ABORT_PENDING;"
Block 73 "944788888" "base_error_reg[seq_index] <= DMA_ERR_ABORT_PENDING;"
Block 80 "786153028" "abort_seen_reg[seq_index] <= 1'b1;"
Block 88 "951759381" "abort_seen_reg[seq_index] <= 1'b1;"
Block 91 "315156832" "state_reg[seq_index] <= ST_COMPLETE;"

CHECKSUM: "3709405175 1487234720"
MODULE: dma_ctrl_regs

Block 66 "448905071" "cmd_valid <= 1'b0;"

CHECKSUM: "3709405175 3002091158"
MODULE: dma_ctrl_regs

Condition 1 "522868291" "(aw_hold_valid && w_hold_valid) 1 -1" (1 "01")
Condition 15 "3773021727" "(aw_hold_valid && w_hold_valid && ((!s_axil_bvalid))) 1 -1" (1 "011")
Condition 15 "3773021727" "(aw_hold_valid && w_hold_valid && ((!s_axil_bvalid))) 1 -1" (3 "110")
Condition 16 "999312428" "(cmd_valid && cmd_ready) 1 -1" (2 "10")
Condition 17 "2593678384" "(write_commit && write_valid && (aw_hold_addr == dma_subsystem_pkg::REG_CTRL) && w_hold_strb[0] && w_hold_data[0]) 1 -1" (1 "01111")
Condition 17 "2593678384" "(write_commit && write_valid && (aw_hold_addr == dma_subsystem_pkg::REG_CTRL) && w_hold_strb[0] && w_hold_data[0]) 1 -1" (2 "10111")
Condition 19 "3054304091" "(write_commit && write_valid && (aw_hold_addr == dma_subsystem_pkg::REG_CTRL) && w_hold_strb[0] && w_hold_data[1]) 1 -1" (1 "01111")
Condition 19 "3054304091" "(write_commit && write_valid && (aw_hold_addr == dma_subsystem_pkg::REG_CTRL) && w_hold_strb[0] && w_hold_data[1]) 1 -1" (2 "10111")
Condition 21 "1998188464" "(write_commit && write_valid && (aw_hold_addr == dma_subsystem_pkg::REG_CTRL) && w_hold_strb[0] && w_hold_data[4]) 1 -1" (1 "01111")
Condition 21 "1998188464" "(write_commit && write_valid && (aw_hold_addr == dma_subsystem_pkg::REG_CTRL) && w_hold_strb[0] && w_hold_data[4]) 1 -1" (2 "10111")
Condition 7 "1691314779" "(cmd_valid && cmd_ready) 1 -1" (2 "10")
Condition 10 "1798661775" "(busy_i || cmd_valid || pending_cmd_accept) 1 -1" (2 "001")
Condition 10 "1798661775" "(busy_i || cmd_valid || pending_cmd_accept) 1 -1" (3 "010")
Condition 11 "1122234016" "(cmd_valid && ((!pending_cmd_accept)) && ((!busy_i))) 1 -1" (2 "101")
Condition 11 "1122234016" "(cmd_valid && ((!pending_cmd_accept)) && ((!busy_i))) 1 -1" (3 "110")
Condition 11 "1122234016" "(cmd_valid && ((!pending_cmd_accept)) && ((!busy_i))) 1 -1" (4 "111")
Condition 12 "3803161617" "(busy_i || pending_cmd_accept) 1 -1" (2 "01")

CHECKSUM: "1724574153 983958077"
MODULE: dma_irq_status_ctrl

Condition 2 "930054110" "(aw_hold_valid && w_hold_valid && ((aw_hold_addr == dma_subsystem_pkg::REG_IRQ_ENABLE) || (aw_hold_addr == dma_subsystem_pkg::REG_IRQ_CLEAR))) 1 -1" (1 "011")
Condition 21 "3773021727" "(aw_hold_valid && w_hold_valid && ((!s_axil_bvalid))) 1 -1" (1 "011")
Condition 21 "3773021727" "(aw_hold_valid && w_hold_valid && ((!s_axil_bvalid))) 1 -1" (3 "110")
Condition 14 "1906749225" "(write_commit && write_valid && (aw_hold_addr == dma_subsystem_pkg::REG_IRQ_CLEAR)) 1 -1" (1 "011")
Condition 14 "1906749225" "(write_commit && write_valid && (aw_hold_addr == dma_subsystem_pkg::REG_IRQ_CLEAR)) 1 -1" (2 "101")

CHECKSUM: "3961876855 19325081"
MODULE: axi_dma_subsystem_core

Toggle s_axil_awaddr [1:0] "logic s_axil_awaddr[31:0]"
Toggle s_axil_araddr [1:0] "logic s_axil_araddr[31:0]"
Toggle s_axi_ext_awsize [5] "logic s_axi_ext_awsize[5:0]"
Toggle s_axi_ext_awlock [1:0] "logic s_axi_ext_awlock[1:0]"
Toggle s_axi_ext_arsize [5] "logic s_axi_ext_arsize[5:0]"
Toggle s_axi_ext_arlock [1:0] "logic s_axi_ext_arlock[1:0]"
Toggle m_axi_mem_awaddr [27:16] "logic m_axi_mem_awaddr[63:0]"
Toggle m_axi_mem_awaddr [31:29] "logic m_axi_mem_awaddr[63:0]"
Toggle m_axi_mem_awaddr [59:48] "logic m_axi_mem_awaddr[63:0]"
Toggle m_axi_mem_awaddr [63:61] "logic m_axi_mem_awaddr[63:0]"
Toggle m_axi_mem_awsize [5] "logic m_axi_mem_awsize[5:0]"
Toggle m_axi_mem_awlock [1:0] "logic m_axi_mem_awlock[1:0]"
Toggle m_axi_mem_araddr [27:16] "logic m_axi_mem_araddr[63:0]"
Toggle m_axi_mem_araddr [31:29] "logic m_axi_mem_araddr[63:0]"
Toggle m_axi_mem_araddr [59:48] "logic m_axi_mem_araddr[63:0]"
Toggle m_axi_mem_araddr [63:61] "logic m_axi_mem_araddr[63:0]"
Toggle m_axi_mem_arsize [5] "logic m_axi_mem_arsize[5:0]"
Toggle m_axi_mem_arlock [1:0] "logic m_axi_mem_arlock[1:0]"
Toggle cmd_payload[0].src_ch "logic cmd_payload[0].src_ch"
Toggle cmd_payload[0].src_addr [1:0] "logic cmd_payload[0].src_addr[31:0]"
Toggle cmd_payload[1].dst_addr [1:0] "logic cmd_payload[1].dst_addr[31:0]"
Toggle completion[0].completed_len [19:17] "logic completion[0].completed_len[19:0]"
Toggle completion[0].hw_tag [7] "logic completion[0].hw_tag[7:0]"
Toggle completion[0].owner_ch "logic completion[0].owner_ch"
Toggle completion[1].completed_len [19:17] "logic completion[1].completed_len[19:0]"
Toggle route_fault_code [4:0] "logic route_fault_code[7:0]"
Toggle route_fault_code [7:6] "logic route_fault_code[7:0]"
Toggle route_fault_source [1:0] "logic route_fault_source[2:0]"
Toggle rd_desc_id [1:0][1:0] "logic [1:0][1:0]rd_desc_id"
Toggle rd_desc_user [1:0][0] "logic [1:0][0:0]rd_desc_user"
Toggle wr_status_id [1:0][1] "logic [1:0][1:0]wr_status_id"
Toggle wr_status_user [1:0][0] "logic [1:0][0:0]wr_status_user"
Toggle axis_read_tid [1:0][1] "logic [1:0][1:0]axis_read_tid"
Toggle axis_read_tuser [1:0][0] "logic [1:0][0:0]axis_read_tuser"
Toggle axis_write_tid [1:0][1] "logic [1:0][1:0]axis_write_tid"
Toggle axis_write_tuser [1:0][0] "logic [1:0][0:0]axis_write_tuser"
Toggle dma_axi_awid [1:0][3:0] "logic [1:0][3:0]dma_axi_awid"
Toggle dma_axi_awsize [1:0][2:0] "logic [1:0][2:0]dma_axi_awsize"
Toggle dma_axi_awburst [1:0][1:0] "logic [1:0][1:0]dma_axi_awburst"
Toggle dma_axi_awcache [1:0][3:0] "logic [1:0][3:0]dma_axi_awcache"
Toggle dma_axi_awprot [1:0][2:0] "logic [1:0][2:0]dma_axi_awprot"
Toggle dma_axi_arid [1:0][3:0] "logic [1:0][3:0]dma_axi_arid"
Toggle dma_axi_arsize [1:0][2:0] "logic [1:0][2:0]dma_axi_arsize"
Toggle dma_axi_arburst [1:0][1:0] "logic [1:0][1:0]dma_axi_arburst"
Toggle dma_axi_arcache [1:0][3:0] "logic [1:0][3:0]dma_axi_arcache"
Toggle dma_axi_arprot [1:0][2:0] "logic [1:0][2:0]dma_axi_arprot"
Toggle axi_s_awid [7:0] "logic axi_s_awid[15:0]"
Toggle axi_s_awaddr [1:0] "logic axi_s_awaddr[127:0]"
Toggle axi_s_awlen [7:4] "logic axi_s_awlen[31:0]"
Toggle axi_s_awlen [15:12] "logic axi_s_awlen[31:0]"
Toggle axi_s_awsize [5:0] "logic axi_s_awsize[11:0]"
Toggle axi_s_awsize [11] "logic axi_s_awsize[11:0]"
Toggle axi_s_awburst [3:0] "logic axi_s_awburst[7:0]"
Toggle axi_s_awlock [3:2] "logic axi_s_awlock[3:0]"
Toggle axi_s_awcache [7:0] "logic axi_s_awcache[15:0]"
Toggle axi_s_awprot [5:0] "logic axi_s_awprot[11:0]"
Toggle axi_s_arid [7:0] "logic axi_s_arid[15:0]"
Toggle axi_s_araddr [1:0] "logic axi_s_araddr[127:0]"
Toggle axi_s_arlen [7:4] "logic axi_s_arlen[31:0]"
Toggle axi_s_arlen [15:12] "logic axi_s_arlen[31:0]"
Toggle axi_s_arsize [5:0] "logic axi_s_arsize[11:0]"
Toggle axi_s_arsize [11] "logic axi_s_arsize[11:0]"
Toggle axi_s_arburst [3:0] "logic axi_s_arburst[7:0]"
Toggle axi_s_arlock [3:2] "logic axi_s_arlock[3:0]"
Toggle axi_s_arcache [7:0] "logic axi_s_arcache[15:0]"
Toggle axi_s_arprot [5:0] "logic axi_s_arprot[11:0]"
Toggle axi_m_awaddr [27:16] "logic axi_m_awaddr[63:0]"
Toggle axi_m_awaddr [31:29] "logic axi_m_awaddr[63:0]"
Toggle axi_m_awaddr [59:48] "logic axi_m_awaddr[63:0]"
Toggle axi_m_awaddr [63:61] "logic axi_m_awaddr[63:0]"
Toggle axi_m_awsize [5] "logic axi_m_awsize[5:0]"
Toggle axi_m_awlock [1:0] "logic axi_m_awlock[1:0]"
Toggle axi_m_araddr [27:16] "logic axi_m_araddr[63:0]"
Toggle axi_m_araddr [31:29] "logic axi_m_araddr[63:0]"
Toggle axi_m_araddr [59:48] "logic axi_m_araddr[63:0]"
Toggle axi_m_araddr [63:61] "logic axi_m_araddr[63:0]"
Toggle axi_m_arsize [5] "logic axi_m_arsize[5:0]"
Toggle axi_m_arlock [1:0] "logic axi_m_arlock[1:0]"
Toggle axil_m_awaddr [1:0] "logic axil_m_awaddr[95:0]"
Toggle axil_m_awaddr [33:32] "logic axil_m_awaddr[95:0]"
Toggle axil_m_awaddr [65:64] "logic axil_m_awaddr[95:0]"
Toggle axil_m_bresp [0] "logic axil_m_bresp[5:0]"
Toggle axil_m_bresp [2] "logic axil_m_bresp[5:0]"
Toggle axil_m_bresp [4] "logic axil_m_bresp[5:0]"
Toggle axil_m_araddr [1:0] "logic axil_m_araddr[95:0]"
Toggle axil_m_araddr [33:32] "logic axil_m_araddr[95:0]"
Toggle axil_m_araddr [65:64] "logic axil_m_araddr[95:0]"
Toggle axil_m_rresp [0] "logic axil_m_rresp[5:0]"
Toggle axil_m_rresp [2] "logic axil_m_rresp[5:0]"
Toggle axil_m_rresp [4] "logic axil_m_rresp[5:0]"
Toggle ctrl_awaddr [1:0] "logic ctrl_awaddr[23:0]"
Toggle ctrl_awaddr [13:12] "logic ctrl_awaddr[23:0]"
Toggle ctrl_bresp [0] "logic ctrl_bresp[3:0]"
Toggle ctrl_bresp [2] "logic ctrl_bresp[3:0]"
Toggle ctrl_araddr [1:0] "logic ctrl_araddr[23:0]"
Toggle ctrl_araddr [13:12] "logic ctrl_araddr[23:0]"
Toggle ctrl_rresp [0] "logic ctrl_rresp[3:0]"
Toggle ctrl_rresp [2] "logic ctrl_rresp[3:0]"
Toggle irq_awaddr [1:0] "logic irq_awaddr[11:0]"
Toggle irq_bresp [0] "logic irq_bresp[1:0]"
Toggle irq_araddr [1:0] "logic irq_araddr[11:0]"
Toggle irq_rresp [0] "logic irq_rresp[1:0]"

CHECKSUM: "4154399110 1224159250"
MODULE: dma_desc_manager

Toggle cmd_payload[0].src_ch "logic cmd_payload[0].src_ch"
Toggle cmd_payload[0].src_addr [1:0] "logic cmd_payload[0].src_addr[31:0]"
Toggle cmd_payload[1].dst_addr [1:0] "logic cmd_payload[1].dst_addr[31:0]"
Toggle rd_desc_id [1:0][1:0] "logic [1:0][1:0]rd_desc_id"
Toggle rd_desc_user [1:0][0] "logic [1:0][0:0]rd_desc_user"
Toggle wr_status_id [1:0][1] "logic [1:0][1:0]wr_status_id"
Toggle wr_status_user [1:0][0] "logic [1:0][0:0]wr_status_user"
Toggle completion[0].completed_len [19:17] "logic completion[0].completed_len[19:0]"
Toggle completion[0].hw_tag [7] "logic completion[0].hw_tag[7:0]"
Toggle completion[0].owner_ch "logic completion[0].owner_ch"
Toggle completion[1].completed_len [19:17] "logic completion[1].completed_len[19:0]"
Toggle cmd_reg[0].src_addr [1:0] "logic cmd_reg[0].src_addr[31:0]"
Toggle cmd_reg[1].dst_addr [1:0] "logic cmd_reg[1].dst_addr[31:0]"

CHECKSUM: "3709405175 2309048752"
MODULE: dma_ctrl_regs

Toggle s_axil_awaddr [1:0] "logic s_axil_awaddr[11:0]"
Toggle s_axil_bresp [0] "logic s_axil_bresp[1:0]"
Toggle s_axil_araddr [1:0] "logic s_axil_araddr[11:0]"
Toggle s_axil_rresp [0] "logic s_axil_rresp[1:0]"
Toggle completion_i.completed_len [19:17] "logic completion_i.completed_len[19:0]"
Toggle aw_hold_addr [1:0] "logic aw_hold_addr[11:0]"
Toggle completed_len_reg [19:17] "logic completed_len_reg[19:0]"
Toggle cmd_payload.dst_addr [1] "logic cmd_payload.dst_addr[31:0]"
Toggle cmd_payload.src_addr [1] "logic cmd_payload.src_addr[31:0]"

CHECKSUM: "1129391697 3046346442"
MODULE: dma_channel_wrap

Toggle rd_desc_id [1:0] "net rd_desc_id[1:0]"
Toggle rd_desc_user "net rd_desc_user[0:0]"
Toggle rd_status_error [1] "net rd_status_error[3:0]"
Toggle rd_status_error [3] "net rd_status_error[3:0]"
Toggle read_axis_tid [1] "net read_axis_tid[1:0]"
Toggle read_axis_tuser "net read_axis_tuser[0:0]"
Toggle write_axis_tid [1] "net write_axis_tid[1:0]"
Toggle write_axis_tuser "net write_axis_tuser[0:0]"
Toggle wr_desc_addr [1:0] "net wr_desc_addr[31:0]"
Toggle wr_desc_addr [27:16] "net wr_desc_addr[31:0]"
Toggle wr_desc_addr [31:29] "net wr_desc_addr[31:0]"
Toggle wr_desc_len [19:17] "net wr_desc_len[19:0]"
Toggle wr_status_len [19:17] "net wr_status_len[19:0]"
Toggle wr_status_id [1] "net wr_status_id[1:0]"
Toggle wr_status_user "net wr_status_user[0:0]"
Toggle wr_status_error [3] "net wr_status_error[3:0]"
Toggle m_axi_awaddr [1:0] "net m_axi_awaddr[31:0]"
Toggle m_axi_awaddr [27:16] "net m_axi_awaddr[31:0]"
Toggle m_axi_awaddr [31:29] "net m_axi_awaddr[31:0]"
Toggle m_axi_awlen [7:4] "net m_axi_awlen[7:0]"
Toggle m_axi_araddr [1:0] "net m_axi_araddr[31:0]"
Toggle m_axi_araddr [27:16] "net m_axi_araddr[31:0]"
Toggle m_axi_araddr [31:29] "net m_axi_araddr[31:0]"
Toggle m_axi_arlen [7:4] "net m_axi_arlen[7:0]"
Toggle dma_read_tuser "net dma_read_tuser[0:0]"
Toggle dma_write_tid [1] "net dma_write_tid[1:0]"
Toggle dma_write_tuser "net dma_write_tuser[0:0]"
Toggle read_fifo_tid [1] "net read_fifo_tid[1:0]"
Toggle read_fifo_tuser "net read_fifo_tuser[0:0]"
Toggle write_fifo_tid [1] "net write_fifo_tid[1:0]"
Toggle write_fifo_tuser "net write_fifo_tuser[0:0]"
Toggle dma_read_tid [1] "net dma_read_tid[1:0]"
Toggle rd_desc_addr [1] "net rd_desc_addr[31:0]"

CHECKSUM: "2108361433 362600838"
MODULE: dma_axis_route_ctrl

Toggle route_fault_code [4:0] "logic route_fault_code[7:0]"
Toggle route_fault_code [7:6] "logic route_fault_code[7:0]"
Toggle route_fault_source [1:0] "logic route_fault_source[2:0]"
Toggle idempotent_grant [1] "logic idempotent_grant[1:0]"

CHECKSUM: "1724574153 394237168"
MODULE: dma_irq_status_ctrl

Toggle s_axil_awaddr [1:0] "logic s_axil_awaddr[11:0]"
Toggle s_axil_bresp [0] "logic s_axil_bresp[1:0]"
Toggle s_axil_araddr [1:0] "logic s_axil_araddr[11:0]"
Toggle s_axil_rresp [0] "logic s_axil_rresp[1:0]"
Toggle completion[0].completed_len [19:17] "logic completion[0].completed_len[19:0]"
Toggle completion[0].hw_tag [7] "logic completion[0].hw_tag[7:0]"
Toggle completion[0].owner_ch "logic completion[0].owner_ch"
Toggle completion[1].completed_len [19:17] "logic completion[1].completed_len[19:0]"
Toggle aw_hold_addr [1:0] "logic aw_hold_addr[11:0]"

CHECKSUM: "4154399110 316728565"
MODULE: dma_desc_manager

Fsm state_reg_0 "1249877999"
Transition ST_ISSUE_RD_DESC->ST_COMPLETE "4->6"
Fsm state_reg_1 "3341634346"
Transition ST_ISSUE_RD_DESC->ST_COMPLETE "4->6"

CHECKSUM: "3709405175 3630342595"
MODULE: dma_ctrl_regs

Branch 2 "3240599406" "rst" (24) "rst 0,-,-,-,-,-,-,-,-,-,1,-,1,dma_subsystem_pkg::REG_CTRL ,-,-,-,1,1,-"
Branch 2 "3240599406" "rst" (33) "rst 0,-,-,-,-,-,-,-,-,-,1,-,1,default,-,-,-,-,-,-"
