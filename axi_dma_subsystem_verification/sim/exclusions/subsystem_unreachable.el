// Reviewed AXI DMA subsystem code-coverage exclusions
// Built from URG full-exclusion templates without Verdi.
// Metrics: LINE, COND, TOGGLE, FSM, BRANCH.
// Scope mode: module.
// Only audited WAIVE candidates are present.
// Assertions and functional covergroups are reported but never waived here.

CHECKSUM: "4154399110 2789773242"
// ANNOTATION: "ModuleName: dma_desc_manager"
MODULE: dma_desc_manager

// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_desc_manager.sv, LineNumber: 284"
// WAIVER-EVIDENCE: ST_VALIDATE lasts one clock and the subsystem AXI-Lite path cannot accept and commit a second abort write before the manager leaves this state.
Block 67 "894737450" "base_error_reg[seq_index] <= DMA_ERR_ABORT_PENDING;"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_desc_manager.sv, LineNumber: 300"
// WAIVER-EVIDENCE: These statements require a registered software abort to coincide exactly with an internal route or descriptor READY handshake; that phase is not deterministically controllable through the subsystem AXI-Lite interface, and forcing the handshake would verify a TB artifact rather than legal integration behavior.
Block 73 "944788888" "base_error_reg[seq_index] <= DMA_ERR_ABORT_PENDING;"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_desc_manager.sv, LineNumber: 318"
// WAIVER-EVIDENCE: These statements require a registered software abort to coincide exactly with an internal route or descriptor READY handshake; that phase is not deterministically controllable through the subsystem AXI-Lite interface, and forcing the handshake would verify a TB artifact rather than legal integration behavior.
Block 80 "786153028" "abort_seen_reg[seq_index] <= 1'b1;"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_desc_manager.sv, LineNumber: 332"
// WAIVER-EVIDENCE: These statements require a registered software abort to coincide exactly with an internal route or descriptor READY handshake; that phase is not deterministically controllable through the subsystem AXI-Lite interface, and forcing the handshake would verify a TB artifact rather than legal integration behavior.
Block 88 "951759381" "abort_seen_reg[seq_index] <= 1'b1;"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_desc_manager.sv, LineNumber: 336"
// WAIVER-EVIDENCE: rd_status_accept requires rd_desc_issued_reg, which becomes one only on the same edge that leaves ISSUE_RD_DESC.
Block 91 "315156832" "state_reg[seq_index] <= ST_COMPLETE;"

CHECKSUM: "3709405175 1487234720"
// ANNOTATION: "ModuleName: dma_ctrl_regs"
MODULE: dma_ctrl_regs

// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_ctrl_regs.sv, LineNumber: 275"
// WAIVER-EVIDENCE: Direct cmd_valid/cmd_ready coupling prevents a pending unaccepted command while both pending_cmd_accept and busy_i are low.
Block 66 "448905071" "cmd_valid <= 1'b0;"

CHECKSUM: "3709405175 3002091158"
// ANNOTATION: "ModuleName: dma_ctrl_regs"
MODULE: dma_ctrl_regs

// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_ctrl_regs.sv, LineNumber: 138"
// WAIVER-EVIDENCE: The configured AXI-Lite crossbar never forwards local WVALID before AW has decoded a target.
Condition 1 "522868291" "(aw_hold_valid && w_hold_valid) 1 -1" (1 "01")
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_ctrl_regs.sv, LineNumber: 154"
// WAIVER-EVIDENCE: write_commit is defined from both hold-valid bits and BVALID state, so these vectors contradict the RTL definition.
Condition 15 "3773021727" "(aw_hold_valid && w_hold_valid && ((!s_axil_bvalid))) 1 -1" (1 "011")
// WAIVER-EVIDENCE: write_commit is defined from both hold-valid bits and BVALID state, so these vectors contradict the RTL definition.
Condition 15 "3773021727" "(aw_hold_valid && w_hold_valid && ((!s_axil_bvalid))) 1 -1" (3 "110")
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_ctrl_regs.sv, LineNumber: 155"
// WAIVER-EVIDENCE: cmd_valid is generated only while the directly coupled manager is IDLE/cmd_ready; reset clears both.
Condition 16 "999312428" "(cmd_valid && cmd_ready) 1 -1" (2 "10")
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_ctrl_regs.sv, LineNumber: 156"
// WAIVER-EVIDENCE: write_commit or write_valid cannot be true when its prerequisite term is false.
Condition 17 "2593678384" "(write_commit && write_valid && (aw_hold_addr == dma_subsystem_pkg::REG_CTRL) && w_hold_strb[0] && w_hold_data[0]) 1 -1" (1 "01111")
// WAIVER-EVIDENCE: write_commit or write_valid cannot be true when its prerequisite term is false.
Condition 17 "2593678384" "(write_commit && write_valid && (aw_hold_addr == dma_subsystem_pkg::REG_CTRL) && w_hold_strb[0] && w_hold_data[0]) 1 -1" (2 "10111")
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_ctrl_regs.sv, LineNumber: 158"
// WAIVER-EVIDENCE: write_commit or write_valid cannot be true when its prerequisite term is false.
Condition 19 "3054304091" "(write_commit && write_valid && (aw_hold_addr == dma_subsystem_pkg::REG_CTRL) && w_hold_strb[0] && w_hold_data[1]) 1 -1" (1 "01111")
// WAIVER-EVIDENCE: write_commit or write_valid cannot be true when its prerequisite term is false.
Condition 19 "3054304091" "(write_commit && write_valid && (aw_hold_addr == dma_subsystem_pkg::REG_CTRL) && w_hold_strb[0] && w_hold_data[1]) 1 -1" (2 "10111")
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_ctrl_regs.sv, LineNumber: 160"
// WAIVER-EVIDENCE: write_commit or write_valid cannot be true when its prerequisite term is false.
Condition 21 "1998188464" "(write_commit && write_valid && (aw_hold_addr == dma_subsystem_pkg::REG_CTRL) && w_hold_strb[0] && w_hold_data[4]) 1 -1" (1 "01111")
// WAIVER-EVIDENCE: write_commit or write_valid cannot be true when its prerequisite term is false.
Condition 21 "1998188464" "(write_commit && write_valid && (aw_hold_addr == dma_subsystem_pkg::REG_CTRL) && w_hold_strb[0] && w_hold_data[4]) 1 -1" (2 "10111")
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_ctrl_regs.sv, LineNumber: 220"
// WAIVER-EVIDENCE: cmd_valid is generated only while the directly coupled manager is IDLE/cmd_ready; reset clears both.
Condition 7 "1691314779" "(cmd_valid && cmd_ready) 1 -1" (2 "10")
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_ctrl_regs.sv, LineNumber: 259"
// WAIVER-EVIDENCE: pending_cmd_accept equals cmd_valid AND cmd_ready, so it cannot assert alone or while cmd_valid is zero.
Condition 10 "1798661775" "(busy_i || cmd_valid || pending_cmd_accept) 1 -1" (2 "001")
// WAIVER-EVIDENCE: pending_cmd_accept equals cmd_valid AND cmd_ready, so it cannot assert alone or while cmd_valid is zero.
Condition 10 "1798661775" "(busy_i || cmd_valid || pending_cmd_accept) 1 -1" (3 "010")
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_ctrl_regs.sv, LineNumber: 274"
// WAIVER-EVIDENCE: Direct cmd_valid/cmd_ready coupling makes these pending/busy combinations temporally contradictory.
Condition 11 "1122234016" "(cmd_valid && ((!pending_cmd_accept)) && ((!busy_i))) 1 -1" (2 "101")
// WAIVER-EVIDENCE: Direct cmd_valid/cmd_ready coupling makes these pending/busy combinations temporally contradictory.
Condition 11 "1122234016" "(cmd_valid && ((!pending_cmd_accept)) && ((!busy_i))) 1 -1" (3 "110")
// WAIVER-EVIDENCE: Direct cmd_valid/cmd_ready coupling makes these pending/busy combinations temporally contradictory.
Condition 11 "1122234016" "(cmd_valid && ((!pending_cmd_accept)) && ((!busy_i))) 1 -1" (4 "111")
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_ctrl_regs.sv, LineNumber: 279"
// WAIVER-EVIDENCE: pending_cmd_accept cannot remain asserted with busy_i low at the software-visible abort commit edge.
Condition 12 "3803161617" "(busy_i || pending_cmd_accept) 1 -1" (2 "01")

CHECKSUM: "1724574153 983958077"
// ANNOTATION: "ModuleName: dma_irq_status_ctrl"
MODULE: dma_irq_status_ctrl

// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_irq_status_ctrl.sv, LineNumber: 131"
// WAIVER-EVIDENCE: The configured AXI-Lite crossbar never forwards local WVALID before AW has decoded a target.
Condition 2 "930054110" "(aw_hold_valid && w_hold_valid && ((aw_hold_addr == dma_subsystem_pkg::REG_IRQ_ENABLE) || (aw_hold_addr == dma_subsystem_pkg::REG_IRQ_CLEAR))) 1 -1" (1 "011")
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_irq_status_ctrl.sv, LineNumber: 138"
// WAIVER-EVIDENCE: write_commit is defined from both hold-valid bits and BVALID state, so these vectors contradict the RTL definition.
Condition 21 "3773021727" "(aw_hold_valid && w_hold_valid && ((!s_axil_bvalid))) 1 -1" (1 "011")
// WAIVER-EVIDENCE: write_commit is defined from both hold-valid bits and BVALID state, so these vectors contradict the RTL definition.
Condition 21 "3773021727" "(aw_hold_valid && w_hold_valid && ((!s_axil_bvalid))) 1 -1" (3 "110")
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_irq_status_ctrl.sv, LineNumber: 199"
// WAIVER-EVIDENCE: The compound IRQ write predicate cannot be true when either write_valid or its selected-address prerequisite is false.
Condition 14 "1906749225" "(write_commit && write_valid && (aw_hold_addr == dma_subsystem_pkg::REG_IRQ_CLEAR)) 1 -1" (1 "011")
// WAIVER-EVIDENCE: The compound IRQ write predicate cannot be true when either write_valid or its selected-address prerequisite is false.
Condition 14 "1906749225" "(write_commit && write_valid && (aw_hold_addr == dma_subsystem_pkg::REG_IRQ_CLEAR)) 1 -1" (2 "101")

CHECKSUM: "3961876855 19325081"
// ANNOTATION: "ModuleName: axi_dma_subsystem_core"
MODULE: axi_dma_subsystem_core

// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 15"
// WAIVER-EVIDENCE: All software and DMA accesses in this word-oriented subsystem are 32-bit aligned.
Toggle s_axil_awaddr [1:0] "logic s_axil_awaddr[31:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 26"
// WAIVER-EVIDENCE: All software and DMA accesses in this word-oriented subsystem are 32-bit aligned.
Toggle s_axil_araddr [1:0] "logic s_axil_araddr[31:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 38"
// WAIVER-EVIDENCE: On a 32-bit AXI data bus, SIZE bit 2 is zero for every supported one-, two-, or four-byte beat.
Toggle s_axi_ext_awsize [5] "logic s_axi_ext_awsize[5:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 40"
// WAIVER-EVIDENCE: Exclusive/locked transfers are outside this subsystem configuration and all instantiated masters use NOLOCK.
Toggle s_axi_ext_awlock [1:0] "logic s_axi_ext_awlock[1:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 57"
// WAIVER-EVIDENCE: On a 32-bit AXI data bus, SIZE bit 2 is zero for every supported one-, two-, or four-byte beat.
Toggle s_axi_ext_arsize [5] "logic s_axi_ext_arsize[5:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 59"
// WAIVER-EVIDENCE: Exclusive/locked transfers are outside this subsystem configuration and all instantiated masters use NOLOCK.
Toggle s_axi_ext_arlock [1:0] "logic s_axi_ext_arlock[1:0]"
// WAIVER-EVIDENCE: Each decoded memory-side AXI lane is confined to one 64-KiB target window, so these upper address bits are target constants.
Toggle m_axi_mem_awaddr [27:16] "logic m_axi_mem_awaddr[63:0]"
// WAIVER-EVIDENCE: Each decoded memory-side AXI lane is confined to one 64-KiB target window, so these upper address bits are target constants.
Toggle m_axi_mem_awaddr [31:29] "logic m_axi_mem_awaddr[63:0]"
// WAIVER-EVIDENCE: Each decoded memory-side AXI lane is confined to one 64-KiB target window, so these upper address bits are target constants.
Toggle m_axi_mem_awaddr [59:48] "logic m_axi_mem_awaddr[63:0]"
// WAIVER-EVIDENCE: Each decoded memory-side AXI lane is confined to one 64-KiB target window, so these upper address bits are target constants.
Toggle m_axi_mem_awaddr [63:61] "logic m_axi_mem_awaddr[63:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 76"
// WAIVER-EVIDENCE: The second memory target uses a 32-bit data bus, so its per-lane SIZE bit 2 is fixed low.
Toggle m_axi_mem_awsize [5] "logic m_axi_mem_awsize[5:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 78"
// WAIVER-EVIDENCE: Exclusive/locked transfers are outside this subsystem configuration and all instantiated masters use NOLOCK.
Toggle m_axi_mem_awlock [1:0] "logic m_axi_mem_awlock[1:0]"
// WAIVER-EVIDENCE: Each decoded memory-side AXI lane is confined to one 64-KiB target window, so these upper address bits are target constants.
Toggle m_axi_mem_araddr [27:16] "logic m_axi_mem_araddr[63:0]"
// WAIVER-EVIDENCE: Each decoded memory-side AXI lane is confined to one 64-KiB target window, so these upper address bits are target constants.
Toggle m_axi_mem_araddr [31:29] "logic m_axi_mem_araddr[63:0]"
// WAIVER-EVIDENCE: Each decoded memory-side AXI lane is confined to one 64-KiB target window, so these upper address bits are target constants.
Toggle m_axi_mem_araddr [59:48] "logic m_axi_mem_araddr[63:0]"
// WAIVER-EVIDENCE: Each decoded memory-side AXI lane is confined to one 64-KiB target window, so these upper address bits are target constants.
Toggle m_axi_mem_araddr [63:61] "logic m_axi_mem_araddr[63:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 95"
// WAIVER-EVIDENCE: The second memory target uses a 32-bit data bus, so its per-lane SIZE bit 2 is fixed low.
Toggle m_axi_mem_arsize [5] "logic m_axi_mem_arsize[5:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 97"
// WAIVER-EVIDENCE: Exclusive/locked transfers are outside this subsystem configuration and all instantiated masters use NOLOCK.
Toggle m_axi_mem_arlock [1:0] "logic m_axi_mem_arlock[1:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_subsystem_pkg.sv, LineNumber: 111"
// WAIVER-EVIDENCE: Each register/manager lane is statically bound to its source channel.
Toggle cmd_payload[0].src_ch "logic cmd_payload[0].src_ch"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_subsystem_pkg.sv, LineNumber: 108"
// WAIVER-EVIDENCE: DMA commands and the configured DMA engines are word aligned because ENABLE_UNALIGNED is disabled.
Toggle cmd_payload[0].src_addr [1:0] "logic cmd_payload[0].src_addr[31:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_subsystem_pkg.sv, LineNumber: 109"
// WAIVER-EVIDENCE: DMA commands and the configured DMA engines are word aligned because ENABLE_UNALIGNED is disabled.
Toggle cmd_payload[1].dst_addr [1:0] "logic cmd_payload[1].dst_addr[31:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_subsystem_pkg.sv, LineNumber: 120"
// WAIVER-EVIDENCE: A legal transfer cannot exceed one configured 64-KiB RAM window; bit 16 is covered by the legal-extent test.
Toggle completion[0].completed_len [19:17] "logic completion[0].completed_len[19:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_subsystem_pkg.sv, LineNumber: 118"
// WAIVER-EVIDENCE: Completion lane zero is permanently owned by DMA0, so the hardware-tag owner bit is fixed low.
Toggle completion[0].hw_tag [7] "logic completion[0].hw_tag[7:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_subsystem_pkg.sv, LineNumber: 117"
// WAIVER-EVIDENCE: Each completion array lane is statically bound to its owner channel.
Toggle completion[0].owner_ch "logic completion[0].owner_ch"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_subsystem_pkg.sv, LineNumber: 120"
// WAIVER-EVIDENCE: A legal transfer cannot exceed one configured 64-KiB RAM window; bit 16 is covered by the legal-extent test.
Toggle completion[1].completed_len [19:17] "logic completion[1].completed_len[19:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 138"
// WAIVER-EVIDENCE: The route controller emits only ROUTE_CONFLICT (0x20) from ROUTE source (3'b100).
Toggle route_fault_code [4:0] "logic route_fault_code[7:0]"
// WAIVER-EVIDENCE: The route controller emits only ROUTE_CONFLICT (0x20) from ROUTE source (3'b100).
Toggle route_fault_code [7:6] "logic route_fault_code[7:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 139"
// WAIVER-EVIDENCE: The route controller emits only ROUTE_CONFLICT (0x20) from ROUTE source (3'b100).
Toggle route_fault_source [1:0] "logic route_fault_source[2:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 149"
// WAIVER-EVIDENCE: DMA descriptor and DMA AXI IDs are fixed by channel/configuration rather than software programmable.
Toggle rd_desc_id [1:0][1:0] "logic [1:0][1:0]rd_desc_id"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 151"
// WAIVER-EVIDENCE: USER width is one and this subsystem configuration ties USER to zero end-to-end.
Toggle rd_desc_user [1:0][0] "logic [1:0][0:0]rd_desc_user"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 165"
// WAIVER-EVIDENCE: These grouped residuals are fixed USER/ID configuration fields.
Toggle wr_status_id [1:0][1] "logic [1:0][1:0]wr_status_id"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 167"
// WAIVER-EVIDENCE: USER width is one and this subsystem configuration ties USER to zero end-to-end.
Toggle wr_status_user [1:0][0] "logic [1:0][0:0]wr_status_user"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 176"
// WAIVER-EVIDENCE: AXIS ID bit one is unused by the two-channel source encoding and is tied low; bit zero is covered by legal CH1 traffic followed by reset.
Toggle axis_read_tid [1:0][1] "logic [1:0][1:0]axis_read_tid"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 178"
// WAIVER-EVIDENCE: USER width is one and this subsystem configuration ties USER to zero end-to-end.
Toggle axis_read_tuser [1:0][0] "logic [1:0][0:0]axis_read_tuser"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 184"
// WAIVER-EVIDENCE: These grouped residuals are fixed USER/ID configuration fields.
Toggle axis_write_tid [1:0][1] "logic [1:0][1:0]axis_write_tid"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 186"
// WAIVER-EVIDENCE: USER width is one and this subsystem configuration ties USER to zero end-to-end.
Toggle axis_write_tuser [1:0][0] "logic [1:0][0:0]axis_write_tuser"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 188"
// WAIVER-EVIDENCE: DMA descriptor and DMA AXI IDs are fixed by channel/configuration rather than software programmable.
Toggle dma_axi_awid [1:0][3:0] "logic [1:0][3:0]dma_axi_awid"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 191"
// WAIVER-EVIDENCE: DMA wrappers are configured for 4-byte INCR, CACHE=0011, PROT=010 transactions.
Toggle dma_axi_awsize [1:0][2:0] "logic [1:0][2:0]dma_axi_awsize"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 192"
// WAIVER-EVIDENCE: DMA wrappers are configured for 4-byte INCR, CACHE=0011, PROT=010 transactions.
Toggle dma_axi_awburst [1:0][1:0] "logic [1:0][1:0]dma_axi_awburst"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 194"
// WAIVER-EVIDENCE: DMA wrappers are configured for 4-byte INCR, CACHE=0011, PROT=010 transactions.
Toggle dma_axi_awcache [1:0][3:0] "logic [1:0][3:0]dma_axi_awcache"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 195"
// WAIVER-EVIDENCE: DMA wrappers are configured for 4-byte INCR, CACHE=0011, PROT=010 transactions.
Toggle dma_axi_awprot [1:0][2:0] "logic [1:0][2:0]dma_axi_awprot"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 207"
// WAIVER-EVIDENCE: DMA descriptor and DMA AXI IDs are fixed by channel/configuration rather than software programmable.
Toggle dma_axi_arid [1:0][3:0] "logic [1:0][3:0]dma_axi_arid"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 210"
// WAIVER-EVIDENCE: DMA wrappers are configured for 4-byte INCR, CACHE=0011, PROT=010 transactions.
Toggle dma_axi_arsize [1:0][2:0] "logic [1:0][2:0]dma_axi_arsize"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 211"
// WAIVER-EVIDENCE: DMA wrappers are configured for 4-byte INCR, CACHE=0011, PROT=010 transactions.
Toggle dma_axi_arburst [1:0][1:0] "logic [1:0][1:0]dma_axi_arburst"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 213"
// WAIVER-EVIDENCE: DMA wrappers are configured for 4-byte INCR, CACHE=0011, PROT=010 transactions.
Toggle dma_axi_arcache [1:0][3:0] "logic [1:0][3:0]dma_axi_arcache"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 214"
// WAIVER-EVIDENCE: DMA wrappers are configured for 4-byte INCR, CACHE=0011, PROT=010 transactions.
Toggle dma_axi_arprot [1:0][2:0] "logic [1:0][2:0]dma_axi_arprot"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 224"
// WAIVER-EVIDENCE: The first two packed AXI source lanes are the DMA engines, whose AXI IDs are fixed to zero.
Toggle axi_s_awid [7:0] "logic axi_s_awid[15:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 225"
// WAIVER-EVIDENCE: All software and DMA accesses in this word-oriented subsystem are 32-bit aligned.
Toggle axi_s_awaddr [1:0] "logic axi_s_awaddr[127:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 226"
// WAIVER-EVIDENCE: The first two packed AXI source lanes are DMA engines configured for at most 16 beats per burst.
Toggle axi_s_awlen [7:4] "logic axi_s_awlen[31:0]"
// WAIVER-EVIDENCE: The first two packed AXI source lanes are DMA engines configured for at most 16 beats per burst.
Toggle axi_s_awlen [15:12] "logic axi_s_awlen[31:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 227"
// WAIVER-EVIDENCE: The first two packed AXI source lanes are 32-bit DMA engines with fixed SIZE=010 attributes.
Toggle axi_s_awsize [5:0] "logic axi_s_awsize[11:0]"
// WAIVER-EVIDENCE: On a 32-bit AXI data bus, SIZE bit 2 is zero for every supported one-, two-, or four-byte beat.
Toggle axi_s_awsize [11] "logic axi_s_awsize[11:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 228"
// WAIVER-EVIDENCE: The low packed slices belong to DMA0/DMA1, whose burst type is fixed to INCR.
Toggle axi_s_awburst [3:0] "logic axi_s_awburst[7:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 229"
// WAIVER-EVIDENCE: Exclusive/locked transfers are outside this subsystem configuration and all instantiated masters use NOLOCK.
Toggle axi_s_awlock [3:2] "logic axi_s_awlock[3:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 230"
// WAIVER-EVIDENCE: The first two packed AXI source lanes are DMA engines with fixed CACHE=0011 attributes.
Toggle axi_s_awcache [7:0] "logic axi_s_awcache[15:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 231"
// WAIVER-EVIDENCE: The first two packed AXI source lanes are DMA engines with fixed PROT=010 attributes.
Toggle axi_s_awprot [5:0] "logic axi_s_awprot[11:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 244"
// WAIVER-EVIDENCE: The first two packed AXI source lanes are the DMA engines, whose AXI IDs are fixed to zero.
Toggle axi_s_arid [7:0] "logic axi_s_arid[15:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 245"
// WAIVER-EVIDENCE: All software and DMA accesses in this word-oriented subsystem are 32-bit aligned.
Toggle axi_s_araddr [1:0] "logic axi_s_araddr[127:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 246"
// WAIVER-EVIDENCE: The first two packed AXI source lanes are DMA engines configured for at most 16 beats per burst.
Toggle axi_s_arlen [7:4] "logic axi_s_arlen[31:0]"
// WAIVER-EVIDENCE: The first two packed AXI source lanes are DMA engines configured for at most 16 beats per burst.
Toggle axi_s_arlen [15:12] "logic axi_s_arlen[31:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 247"
// WAIVER-EVIDENCE: The first two packed AXI source lanes are 32-bit DMA engines with fixed SIZE=010 attributes.
Toggle axi_s_arsize [5:0] "logic axi_s_arsize[11:0]"
// WAIVER-EVIDENCE: On a 32-bit AXI data bus, SIZE bit 2 is zero for every supported one-, two-, or four-byte beat.
Toggle axi_s_arsize [11] "logic axi_s_arsize[11:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 248"
// WAIVER-EVIDENCE: The low packed slices belong to DMA0/DMA1, whose burst type is fixed to INCR.
Toggle axi_s_arburst [3:0] "logic axi_s_arburst[7:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 249"
// WAIVER-EVIDENCE: Exclusive/locked transfers are outside this subsystem configuration and all instantiated masters use NOLOCK.
Toggle axi_s_arlock [3:2] "logic axi_s_arlock[3:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 250"
// WAIVER-EVIDENCE: The first two packed AXI source lanes are DMA engines with fixed CACHE=0011 attributes.
Toggle axi_s_arcache [7:0] "logic axi_s_arcache[15:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 251"
// WAIVER-EVIDENCE: The first two packed AXI source lanes are DMA engines with fixed PROT=010 attributes.
Toggle axi_s_arprot [5:0] "logic axi_s_arprot[11:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 263"
// WAIVER-EVIDENCE: Each decoded memory-side AXI lane is confined to one 64-KiB target window, so these upper address bits are target constants.
Toggle axi_m_awaddr [27:16] "logic axi_m_awaddr[63:0]"
// WAIVER-EVIDENCE: Each decoded memory-side AXI lane is confined to one 64-KiB target window, so these upper address bits are target constants.
Toggle axi_m_awaddr [31:29] "logic axi_m_awaddr[63:0]"
// WAIVER-EVIDENCE: Each decoded memory-side AXI lane is confined to one 64-KiB target window, so these upper address bits are target constants.
Toggle axi_m_awaddr [59:48] "logic axi_m_awaddr[63:0]"
// WAIVER-EVIDENCE: Each decoded memory-side AXI lane is confined to one 64-KiB target window, so these upper address bits are target constants.
Toggle axi_m_awaddr [63:61] "logic axi_m_awaddr[63:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 265"
// WAIVER-EVIDENCE: The second memory target uses a 32-bit data bus, so its per-lane SIZE bit 2 is fixed low.
Toggle axi_m_awsize [5] "logic axi_m_awsize[5:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 267"
// WAIVER-EVIDENCE: Exclusive/locked transfers are outside this subsystem configuration and all instantiated masters use NOLOCK.
Toggle axi_m_awlock [1:0] "logic axi_m_awlock[1:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 282"
// WAIVER-EVIDENCE: Each decoded memory-side AXI lane is confined to one 64-KiB target window, so these upper address bits are target constants.
Toggle axi_m_araddr [27:16] "logic axi_m_araddr[63:0]"
// WAIVER-EVIDENCE: Each decoded memory-side AXI lane is confined to one 64-KiB target window, so these upper address bits are target constants.
Toggle axi_m_araddr [31:29] "logic axi_m_araddr[63:0]"
// WAIVER-EVIDENCE: Each decoded memory-side AXI lane is confined to one 64-KiB target window, so these upper address bits are target constants.
Toggle axi_m_araddr [59:48] "logic axi_m_araddr[63:0]"
// WAIVER-EVIDENCE: Each decoded memory-side AXI lane is confined to one 64-KiB target window, so these upper address bits are target constants.
Toggle axi_m_araddr [63:61] "logic axi_m_araddr[63:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 284"
// WAIVER-EVIDENCE: The second memory target uses a 32-bit data bus, so its per-lane SIZE bit 2 is fixed low.
Toggle axi_m_arsize [5] "logic axi_m_arsize[5:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 286"
// WAIVER-EVIDENCE: Exclusive/locked transfers are outside this subsystem configuration and all instantiated masters use NOLOCK.
Toggle axi_m_arlock [1:0] "logic axi_m_arlock[1:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 298"
// WAIVER-EVIDENCE: All software and DMA accesses in this word-oriented subsystem are 32-bit aligned.
Toggle axil_m_awaddr [1:0] "logic axil_m_awaddr[95:0]"
// WAIVER-EVIDENCE: These packed bits are the word-alignment bits of the CH1 local AXI-Lite lane.
Toggle axil_m_awaddr [33:32] "logic axil_m_awaddr[95:0]"
// WAIVER-EVIDENCE: These packed bits are the word-alignment bits of the global-IRQ local AXI-Lite lane.
Toggle axil_m_awaddr [65:64] "logic axil_m_awaddr[95:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 306"
// WAIVER-EVIDENCE: Local AXI-Lite blocks return only OKAY (00) or SLVERR (10), so response bit zero is fixed.
Toggle axil_m_bresp [0] "logic axil_m_bresp[5:0]"
// WAIVER-EVIDENCE: These packed positions are response bit zero of local AXI-Lite lanes, which is fixed for OKAY/SLVERR-only targets.
Toggle axil_m_bresp [2] "logic axil_m_bresp[5:0]"
// WAIVER-EVIDENCE: These packed positions are response bit zero of local AXI-Lite lanes, which is fixed for OKAY/SLVERR-only targets.
Toggle axil_m_bresp [4] "logic axil_m_bresp[5:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 309"
// WAIVER-EVIDENCE: All software and DMA accesses in this word-oriented subsystem are 32-bit aligned.
Toggle axil_m_araddr [1:0] "logic axil_m_araddr[95:0]"
// WAIVER-EVIDENCE: These packed bits are the word-alignment bits of the CH1 local AXI-Lite lane.
Toggle axil_m_araddr [33:32] "logic axil_m_araddr[95:0]"
// WAIVER-EVIDENCE: These packed bits are the word-alignment bits of the global-IRQ local AXI-Lite lane.
Toggle axil_m_araddr [65:64] "logic axil_m_araddr[95:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 314"
// WAIVER-EVIDENCE: Local AXI-Lite blocks return only OKAY (00) or SLVERR (10), so response bit zero is fixed.
Toggle axil_m_rresp [0] "logic axil_m_rresp[5:0]"
// WAIVER-EVIDENCE: These packed positions are response bit zero of local AXI-Lite lanes, which is fixed for OKAY/SLVERR-only targets.
Toggle axil_m_rresp [2] "logic axil_m_rresp[5:0]"
// WAIVER-EVIDENCE: These packed positions are response bit zero of local AXI-Lite lanes, which is fixed for OKAY/SLVERR-only targets.
Toggle axil_m_rresp [4] "logic axil_m_rresp[5:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 318"
// WAIVER-EVIDENCE: All software and DMA accesses in this word-oriented subsystem are 32-bit aligned.
Toggle ctrl_awaddr [1:0] "logic ctrl_awaddr[23:0]"
// WAIVER-EVIDENCE: These packed bits are the word-alignment bits of the CH1 local AXI-Lite lane.
Toggle ctrl_awaddr [13:12] "logic ctrl_awaddr[23:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 326"
// WAIVER-EVIDENCE: Local AXI-Lite blocks return only OKAY (00) or SLVERR (10), so response bit zero is fixed.
Toggle ctrl_bresp [0] "logic ctrl_bresp[3:0]"
// WAIVER-EVIDENCE: These packed positions are response bit zero of local AXI-Lite lanes, which is fixed for OKAY/SLVERR-only targets.
Toggle ctrl_bresp [2] "logic ctrl_bresp[3:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 329"
// WAIVER-EVIDENCE: All software and DMA accesses in this word-oriented subsystem are 32-bit aligned.
Toggle ctrl_araddr [1:0] "logic ctrl_araddr[23:0]"
// WAIVER-EVIDENCE: These packed bits are the word-alignment bits of the CH1 local AXI-Lite lane.
Toggle ctrl_araddr [13:12] "logic ctrl_araddr[23:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 334"
// WAIVER-EVIDENCE: Local AXI-Lite blocks return only OKAY (00) or SLVERR (10), so response bit zero is fixed.
Toggle ctrl_rresp [0] "logic ctrl_rresp[3:0]"
// WAIVER-EVIDENCE: These packed positions are response bit zero of local AXI-Lite lanes, which is fixed for OKAY/SLVERR-only targets.
Toggle ctrl_rresp [2] "logic ctrl_rresp[3:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 338"
// WAIVER-EVIDENCE: All software and DMA accesses in this word-oriented subsystem are 32-bit aligned.
Toggle irq_awaddr [1:0] "logic irq_awaddr[11:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 346"
// WAIVER-EVIDENCE: Local AXI-Lite blocks return only OKAY (00) or SLVERR (10), so response bit zero is fixed.
Toggle irq_bresp [0] "logic irq_bresp[1:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 349"
// WAIVER-EVIDENCE: All software and DMA accesses in this word-oriented subsystem are 32-bit aligned.
Toggle irq_araddr [1:0] "logic irq_araddr[11:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/axi_dma_subsystem_core.sv, LineNumber: 354"
// WAIVER-EVIDENCE: Local AXI-Lite blocks return only OKAY (00) or SLVERR (10), so response bit zero is fixed.
Toggle irq_rresp [0] "logic irq_rresp[1:0]"

CHECKSUM: "4154399110 1224159250"
// ANNOTATION: "ModuleName: dma_desc_manager"
MODULE: dma_desc_manager

// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_subsystem_pkg.sv, LineNumber: 111"
// WAIVER-EVIDENCE: Each register/manager lane is statically bound to its source channel.
Toggle cmd_payload[0].src_ch "logic cmd_payload[0].src_ch"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_subsystem_pkg.sv, LineNumber: 108"
// WAIVER-EVIDENCE: DMA commands and the configured DMA engines are word aligned because ENABLE_UNALIGNED is disabled.
Toggle cmd_payload[0].src_addr [1:0] "logic cmd_payload[0].src_addr[31:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_subsystem_pkg.sv, LineNumber: 109"
// WAIVER-EVIDENCE: DMA commands and the configured DMA engines are word aligned because ENABLE_UNALIGNED is disabled.
Toggle cmd_payload[1].dst_addr [1:0] "logic cmd_payload[1].dst_addr[31:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_desc_manager.sv, LineNumber: 27"
// WAIVER-EVIDENCE: DMA descriptor and DMA AXI IDs are fixed by channel/configuration rather than software programmable.
Toggle rd_desc_id [1:0][1:0] "logic [1:0][1:0]rd_desc_id"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_desc_manager.sv, LineNumber: 29"
// WAIVER-EVIDENCE: USER width is one and this subsystem configuration ties USER to zero end-to-end.
Toggle rd_desc_user [1:0][0] "logic [1:0][0:0]rd_desc_user"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_desc_manager.sv, LineNumber: 45"
// WAIVER-EVIDENCE: These grouped residuals are fixed USER/ID configuration fields.
Toggle wr_status_id [1:0][1] "logic [1:0][1:0]wr_status_id"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_desc_manager.sv, LineNumber: 47"
// WAIVER-EVIDENCE: USER width is one and this subsystem configuration ties USER to zero end-to-end.
Toggle wr_status_user [1:0][0] "logic [1:0][0:0]wr_status_user"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_subsystem_pkg.sv, LineNumber: 120"
// WAIVER-EVIDENCE: A legal transfer cannot exceed one configured 64-KiB RAM window; bit 16 is covered by the legal-extent test.
Toggle completion[0].completed_len [19:17] "logic completion[0].completed_len[19:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_subsystem_pkg.sv, LineNumber: 118"
// WAIVER-EVIDENCE: Completion lane zero is permanently owned by DMA0, so the hardware-tag owner bit is fixed low.
Toggle completion[0].hw_tag [7] "logic completion[0].hw_tag[7:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_subsystem_pkg.sv, LineNumber: 117"
// WAIVER-EVIDENCE: Each completion array lane is statically bound to its owner channel.
Toggle completion[0].owner_ch "logic completion[0].owner_ch"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_subsystem_pkg.sv, LineNumber: 120"
// WAIVER-EVIDENCE: A legal transfer cannot exceed one configured 64-KiB RAM window; bit 16 is covered by the legal-extent test.
Toggle completion[1].completed_len [19:17] "logic completion[1].completed_len[19:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_subsystem_pkg.sv, LineNumber: 108"
// WAIVER-EVIDENCE: DMA commands and the configured DMA engines are word aligned because ENABLE_UNALIGNED is disabled.
Toggle cmd_reg[0].src_addr [1:0] "logic cmd_reg[0].src_addr[31:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_subsystem_pkg.sv, LineNumber: 109"
// WAIVER-EVIDENCE: DMA commands and the configured DMA engines are word aligned because ENABLE_UNALIGNED is disabled.
Toggle cmd_reg[1].dst_addr [1:0] "logic cmd_reg[1].dst_addr[31:0]"

CHECKSUM: "3709405175 2309048752"
// ANNOTATION: "ModuleName: dma_ctrl_regs"
MODULE: dma_ctrl_regs

// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_ctrl_regs.sv, LineNumber: 12"
// WAIVER-EVIDENCE: All software and DMA accesses in this word-oriented subsystem are 32-bit aligned.
Toggle s_axil_awaddr [1:0] "logic s_axil_awaddr[11:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_ctrl_regs.sv, LineNumber: 20"
// WAIVER-EVIDENCE: Local AXI-Lite blocks return only OKAY (00) or SLVERR (10), so response bit zero is fixed.
Toggle s_axil_bresp [0] "logic s_axil_bresp[1:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_ctrl_regs.sv, LineNumber: 23"
// WAIVER-EVIDENCE: All software and DMA accesses in this word-oriented subsystem are 32-bit aligned.
Toggle s_axil_araddr [1:0] "logic s_axil_araddr[11:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_ctrl_regs.sv, LineNumber: 28"
// WAIVER-EVIDENCE: Local AXI-Lite blocks return only OKAY (00) or SLVERR (10), so response bit zero is fixed.
Toggle s_axil_rresp [0] "logic s_axil_rresp[1:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_subsystem_pkg.sv, LineNumber: 120"
// WAIVER-EVIDENCE: A legal transfer cannot exceed one configured 64-KiB RAM window; bit 16 is covered by the legal-extent test.
Toggle completion_i.completed_len [19:17] "logic completion_i.completed_len[19:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_ctrl_regs.sv, LineNumber: 42"
// WAIVER-EVIDENCE: All software and DMA accesses in this word-oriented subsystem are 32-bit aligned.
Toggle aw_hold_addr [1:0] "logic aw_hold_addr[11:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_ctrl_regs.sv, LineNumber: 59"
// WAIVER-EVIDENCE: A legal transfer cannot exceed one configured 64-KiB RAM window; bit 16 is covered by the legal-extent test.
Toggle completed_len_reg [19:17] "logic completed_len_reg[19:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_subsystem_pkg.sv, LineNumber: 109"
// WAIVER-EVIDENCE: Address bit zero is covered; the remaining uncovered alignment bit is retained for the configured aligned-DMA mode.
Toggle cmd_payload.dst_addr [1] "logic cmd_payload.dst_addr[31:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_subsystem_pkg.sv, LineNumber: 108"
// WAIVER-EVIDENCE: Address bit zero is covered; the remaining uncovered alignment bit is retained for the configured aligned-DMA mode.
Toggle cmd_payload.src_addr [1] "logic cmd_payload.src_addr[31:0]"

CHECKSUM: "1129391697 3046346442"
// ANNOTATION: "ModuleName: dma_channel_wrap"
MODULE: dma_channel_wrap

// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_channel_wrap.sv, LineNumber: 15"
// WAIVER-EVIDENCE: DMA descriptor and DMA AXI IDs are fixed by channel/configuration rather than software programmable.
Toggle rd_desc_id [1:0] "net rd_desc_id[1:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_channel_wrap.sv, LineNumber: 17"
// WAIVER-EVIDENCE: USER width is one and this subsystem configuration ties USER to zero end-to-end.
Toggle rd_desc_user "net rd_desc_user[0:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_channel_wrap.sv, LineNumber: 21"
// WAIVER-EVIDENCE: The vendor read-status mapping emits only 0, 4, or 5.
Toggle rd_status_error [1] "net rd_status_error[3:0]"
// WAIVER-EVIDENCE: The vendor read-status mapping emits only 0, 4, or 5.
Toggle rd_status_error [3] "net rd_status_error[3:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_channel_wrap.sv, LineNumber: 29"
// WAIVER-EVIDENCE: AXIS ID bit one is unused by the two-channel source encoding and is tied low; bit zero is covered by legal CH1 traffic followed by reset.
Toggle read_axis_tid [1] "net read_axis_tid[1:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_channel_wrap.sv, LineNumber: 31"
// WAIVER-EVIDENCE: USER width is one and this subsystem configuration ties USER to zero end-to-end.
Toggle read_axis_tuser "net read_axis_tuser[0:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_channel_wrap.sv, LineNumber: 38"
// WAIVER-EVIDENCE: AXIS ID is derived solely from the statically assigned DMA source channel; unused ID bits are zero.
Toggle write_axis_tid [1] "net write_axis_tid[1:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_channel_wrap.sv, LineNumber: 40"
// WAIVER-EVIDENCE: USER width is one and this subsystem configuration ties USER to zero end-to-end.
Toggle write_axis_tuser "net write_axis_tuser[0:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_channel_wrap.sv, LineNumber: 42"
// WAIVER-EVIDENCE: DMA commands and the configured DMA engines are word aligned because ENABLE_UNALIGNED is disabled.
Toggle wr_desc_addr [1:0] "net wr_desc_addr[31:0]"
// WAIVER-EVIDENCE: Validated descriptors can address only the two configured 64-KiB windows; bit 28 selects RAM1.
Toggle wr_desc_addr [27:16] "net wr_desc_addr[31:0]"
// WAIVER-EVIDENCE: Validated descriptors can address only the two configured 64-KiB windows; bit 28 selects RAM1.
Toggle wr_desc_addr [31:29] "net wr_desc_addr[31:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_channel_wrap.sv, LineNumber: 43"
// WAIVER-EVIDENCE: A legal transfer cannot exceed one configured 64-KiB RAM window; bit 16 is covered by the legal-extent test.
Toggle wr_desc_len [19:17] "net wr_desc_len[19:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_channel_wrap.sv, LineNumber: 47"
// WAIVER-EVIDENCE: A legal transfer cannot exceed one configured 64-KiB RAM window; bit 16 is covered by the legal-extent test.
Toggle wr_status_len [19:17] "net wr_status_len[19:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_channel_wrap.sv, LineNumber: 49"
// WAIVER-EVIDENCE: DMA descriptor and DMA AXI IDs are fixed by channel/configuration rather than software programmable.
Toggle wr_status_id [1] "net wr_status_id[1:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_channel_wrap.sv, LineNumber: 51"
// WAIVER-EVIDENCE: USER width is one and this subsystem configuration ties USER to zero end-to-end.
Toggle wr_status_user "net wr_status_user[0:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_channel_wrap.sv, LineNumber: 52"
// WAIVER-EVIDENCE: The vendor write-status mapping emits only 0, 6, or 7.
Toggle wr_status_error [3] "net wr_status_error[3:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_channel_wrap.sv, LineNumber: 56"
// WAIVER-EVIDENCE: DMA commands and the configured DMA engines are word aligned because ENABLE_UNALIGNED is disabled.
Toggle m_axi_awaddr [1:0] "net m_axi_awaddr[31:0]"
// WAIVER-EVIDENCE: A DMA engine can issue addresses only inside the two configured 64-KiB RAM windows; bit 28 selects RAM1.
Toggle m_axi_awaddr [27:16] "net m_axi_awaddr[31:0]"
// WAIVER-EVIDENCE: A DMA engine can issue addresses only inside the two configured 64-KiB RAM windows; bit 28 selects RAM1.
Toggle m_axi_awaddr [31:29] "net m_axi_awaddr[31:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_channel_wrap.sv, LineNumber: 57"
// WAIVER-EVIDENCE: The configured DMA maximum burst length is 16 beats, so upper LEN bits are zero.
Toggle m_axi_awlen [7:4] "net m_axi_awlen[7:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_channel_wrap.sv, LineNumber: 75"
// WAIVER-EVIDENCE: DMA commands and the configured DMA engines are word aligned because ENABLE_UNALIGNED is disabled.
Toggle m_axi_araddr [1:0] "net m_axi_araddr[31:0]"
// WAIVER-EVIDENCE: A DMA engine can issue addresses only inside the two configured 64-KiB RAM windows; bit 28 selects RAM1.
Toggle m_axi_araddr [27:16] "net m_axi_araddr[31:0]"
// WAIVER-EVIDENCE: A DMA engine can issue addresses only inside the two configured 64-KiB RAM windows; bit 28 selects RAM1.
Toggle m_axi_araddr [31:29] "net m_axi_araddr[31:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_channel_wrap.sv, LineNumber: 76"
// WAIVER-EVIDENCE: The configured DMA maximum burst length is 16 beats, so upper LEN bits are zero.
Toggle m_axi_arlen [7:4] "net m_axi_arlen[7:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_channel_wrap.sv, LineNumber: 99"
// WAIVER-EVIDENCE: USER width is one and this subsystem configuration ties USER to zero end-to-end.
Toggle dma_read_tuser "net dma_read_tuser[0:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_channel_wrap.sv, LineNumber: 106"
// WAIVER-EVIDENCE: The upper AXIS ID bit is unused by the two-channel source encoding and is tied low.
Toggle dma_write_tid [1] "net dma_write_tid[1:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_channel_wrap.sv, LineNumber: 108"
// WAIVER-EVIDENCE: USER width is one and this subsystem configuration ties USER to zero end-to-end.
Toggle dma_write_tuser "net dma_write_tuser[0:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_channel_wrap.sv, LineNumber: 115"
// WAIVER-EVIDENCE: AXIS ID bit one is unused by the two-channel source encoding and is tied low; bit zero is covered by legal CH1 traffic followed by reset.
Toggle read_fifo_tid [1] "net read_fifo_tid[1:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_channel_wrap.sv, LineNumber: 117"
// WAIVER-EVIDENCE: USER width is one and this subsystem configuration ties USER to zero end-to-end.
Toggle read_fifo_tuser "net read_fifo_tuser[0:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_channel_wrap.sv, LineNumber: 124"
// WAIVER-EVIDENCE: AXIS ID is derived solely from the statically assigned DMA source channel; unused ID bits are zero.
Toggle write_fifo_tid [1] "net write_fifo_tid[1:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_channel_wrap.sv, LineNumber: 126"
// WAIVER-EVIDENCE: USER width is one and this subsystem configuration ties USER to zero end-to-end.
Toggle write_fifo_tuser "net write_fifo_tuser[0:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_channel_wrap.sv, LineNumber: 97"
// WAIVER-EVIDENCE: AXIS ID bit one is unused by the two-channel source encoding and is tied low; bit zero is covered by legal CH1 traffic followed by reset.
Toggle dma_read_tid [1] "net dma_read_tid[1:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_channel_wrap.sv, LineNumber: 12"
// WAIVER-EVIDENCE: Address bit zero is covered; the remaining uncovered alignment bit is retained for the configured aligned-DMA mode.
Toggle rd_desc_addr [1] "net rd_desc_addr[31:0]"

CHECKSUM: "2108361433 362600838"
// ANNOTATION: "ModuleName: dma_axis_route_ctrl"
MODULE: dma_axis_route_ctrl

// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_axis_route_ctrl.sv, LineNumber: 19"
// WAIVER-EVIDENCE: The route controller emits only ROUTE_CONFLICT (0x20) from ROUTE source (3'b100).
Toggle route_fault_code [4:0] "logic route_fault_code[7:0]"
// WAIVER-EVIDENCE: The route controller emits only ROUTE_CONFLICT (0x20) from ROUTE source (3'b100).
Toggle route_fault_code [7:6] "logic route_fault_code[7:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_axis_route_ctrl.sv, LineNumber: 20"
// WAIVER-EVIDENCE: The route controller emits only ROUTE_CONFLICT (0x20) from ROUTE source (3'b100).
Toggle route_fault_source [1:0] "logic route_fault_source[2:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_axis_route_ctrl.sv, LineNumber: 30"
// WAIVER-EVIDENCE: The manager drops route_req_valid immediately after accepting a grant, so an active idempotent request cannot occur.
Toggle idempotent_grant [1] "logic idempotent_grant[1:0]"

CHECKSUM: "1724574153 394237168"
// ANNOTATION: "ModuleName: dma_irq_status_ctrl"
MODULE: dma_irq_status_ctrl

// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_irq_status_ctrl.sv, LineNumber: 10"
// WAIVER-EVIDENCE: All software and DMA accesses in this word-oriented subsystem are 32-bit aligned.
Toggle s_axil_awaddr [1:0] "logic s_axil_awaddr[11:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_irq_status_ctrl.sv, LineNumber: 18"
// WAIVER-EVIDENCE: Local AXI-Lite blocks return only OKAY (00) or SLVERR (10), so response bit zero is fixed.
Toggle s_axil_bresp [0] "logic s_axil_bresp[1:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_irq_status_ctrl.sv, LineNumber: 21"
// WAIVER-EVIDENCE: All software and DMA accesses in this word-oriented subsystem are 32-bit aligned.
Toggle s_axil_araddr [1:0] "logic s_axil_araddr[11:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_irq_status_ctrl.sv, LineNumber: 26"
// WAIVER-EVIDENCE: Local AXI-Lite blocks return only OKAY (00) or SLVERR (10), so response bit zero is fixed.
Toggle s_axil_rresp [0] "logic s_axil_rresp[1:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_subsystem_pkg.sv, LineNumber: 120"
// WAIVER-EVIDENCE: A legal transfer cannot exceed one configured 64-KiB RAM window; bit 16 is covered by the legal-extent test.
Toggle completion[0].completed_len [19:17] "logic completion[0].completed_len[19:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_subsystem_pkg.sv, LineNumber: 118"
// WAIVER-EVIDENCE: Completion lane zero is permanently owned by DMA0, so the hardware-tag owner bit is fixed low.
Toggle completion[0].hw_tag [7] "logic completion[0].hw_tag[7:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_subsystem_pkg.sv, LineNumber: 117"
// WAIVER-EVIDENCE: Each completion array lane is statically bound to its owner channel.
Toggle completion[0].owner_ch "logic completion[0].owner_ch"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_subsystem_pkg.sv, LineNumber: 120"
// WAIVER-EVIDENCE: A legal transfer cannot exceed one configured 64-KiB RAM window; bit 16 is covered by the legal-extent test.
Toggle completion[1].completed_len [19:17] "logic completion[1].completed_len[19:0]"
// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_irq_status_ctrl.sv, LineNumber: 42"
// WAIVER-EVIDENCE: All software and DMA accesses in this word-oriented subsystem are 32-bit aligned.
Toggle aw_hold_addr [1:0] "logic aw_hold_addr[11:0]"

CHECKSUM: "4154399110 316728565"
// ANNOTATION: "ModuleName: dma_desc_manager"
MODULE: dma_desc_manager

// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_desc_manager.sv, LineNumber: 213"
// WAIVER-EVIDENCE: rd_status_accept requires rd_desc_issued_reg, which becomes one only on the same edge that leaves ISSUE_RD_DESC; the direct completion predicate cannot be true on that edge.
Fsm state_reg_0 "1249877999"
Transition ST_ISSUE_RD_DESC->ST_COMPLETE "4->6"
// WAIVER-EVIDENCE: rd_status_accept requires rd_desc_issued_reg, which becomes one only on the same edge that leaves ISSUE_RD_DESC; the direct completion predicate cannot be true on that edge.
Fsm state_reg_1 "3341634346"
Transition ST_ISSUE_RD_DESC->ST_COMPLETE "4->6"

CHECKSUM: "3709405175 3630342595"
// ANNOTATION: "ModuleName: dma_ctrl_regs"
MODULE: dma_ctrl_regs

// ANNOTATION: "FileName: /home/ranran/Desktop/verify_study/axi_dma_subsystem_verification/sim/../rtl/dma_ctrl_regs.sv, LineNumber: 164"
// WAIVER-EVIDENCE: The inner pending-command-only abort predicate is unreachable with the integrated direct manager handshake.
Branch 2 "3240599406" "rst" (24) "rst 0,-,-,-,-,-,-,-,-,-,1,-,1,dma_subsystem_pkg::REG_CTRL ,-,-,-,1,1,-"
// WAIVER-EVIDENCE: The enclosing write_valid predicate is false for every address that selects the case default item.
Branch 2 "3240599406" "rst" (33) "rst 0,-,-,-,-,-,-,-,-,-,1,-,1,default,-,-,-,-,-,-"
