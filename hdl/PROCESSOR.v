`default_nettype none
`timescale 1ns/100ps
`include "UTIL.v"
`include "INST.v"
`include "CONSTS.v"

module PROCESSOR (
  input   wire          clk,
  input   wire          rst,
  input   wire          halt,
  // I/F for memory
  output  wire[32-1:0]  imem_addr,
  output  wire          imem_oe,
  input   wire[32-1:0]  imem_rdata,
  input   wire          imem_valid,

  output  reg [32-1:0]  mem_addr,
  output  reg [ 4-1:0]  mem_oe,
  output  reg [32-1:0]  mem_wdata,
  output  reg [ 4-1:0]  mem_we,
  input   wire[32-1:0]  mem_rdata,
  input   wire          mem_valid,
  input   wire          mem_ready,

  // stat
  output  wire[64-1:0]  cycle,
  output  wire[32-1:0]  pc_disp,
  output  wire[32-1:0]  bp_cnt_hit,
  output  wire[32-1:0]  bp_cnt_pred
);
  `include "LCONSTS.v"

  // stall request
  wire[WB:IF]   stall_req;
  // Stall all stages preceding a stage which requests to stall
  wire[WB:IF]   stall   = stall_req |  {1'b0, stall[WB:ID]};
  // Insert bubble if succeeding stages don't assert stall_req.
  wire[WB:IF]   insertb = stall_req & ~{1'b0, stall[WB:ID]};

  // branch target, branch taken, signal to flush ID to EM stage
  wire[32-1:0]  btarget;
  wire          btaken, bflush;
  reg           bflush_reading_inst=1'b0;
  // branch prediction address
  wire[32-1:0]  bptarget_id;
  reg [WB:ID]   bptaken;

  reg [WB:IF]   prev_insertb=0; // insertb in last cycle
  reg           prev_bflush=0;  // bflush in last cycle
  always @(posedge clk) prev_insertb  <= insertb;
  always @(posedge clk) prev_bflush   <= bflush;

  // Program Counters for each stage
  reg [32-1:0]  pc_if_no_bpred=0;
  reg [32-1:0]  pc[IF:WB];
  wire[32-1:0]  pc_if = pc[IF]; // tmp for debug
  assign  pc_disp = pc[WB];

  always @(posedge clk) pc_if_no_bpred <=
    rst                       ? `BOOT       :
    bflush                    ? btarget     :
    stall[IF]                 ? pc[IF]      :
                                pc[IF]+4;
  always @(*)           pc[IF] =  // combinational
    bptaken[ID]               ? bptarget_id   :
                                pc_if_no_bpred;
  always @(posedge clk) pc[ID] <= // sequential
    rst                       ? `BOOT       :
    stall[ID]                 ? pc[ID]      :
                                pc[IF];
  always @(posedge clk) pc[EM] <= // sequential
    rst                       ? `BOOT       :
    stall[EM]                 ? pc[EM]      :
                                pc[ID];
  always @(posedge clk) pc[WB] <= // sequential
    rst                       ? `BOOT       :
    stall[WB]                 ? pc[WB]      :
                                pc[EM];


  // Instruction Registers for each stage
  reg [32-1:0]  ir[ID:WB];
  always @(*)           ir[ID]  = // combinational
    rst                       ? `NOP        :
    bflush_reading_inst       ? `NOP        :
    prev_insertb[IF]          ? `NOP        :
                                imem_rdata;
  always @(posedge clk) ir[EM] <= // sequential
    rst                       ? `NOP        :
    bflush                    ? `NOP        :
    insertb[ID]               ? `NOP        :
    stall[EM]                 ? ir[EM]      :
                                ir[ID];
  always @(posedge clk) ir[WB] <= // sequential
    rst                       ? `NOP        :
    insertb[EM]               ? `NOP        :
    stall[WB]                 ? ir[WB]      :
                                ir[EM];
  initial {ir[ID], ir[EM], ir[WB]} = 0;

  // Instruction Fetch stage ========================================
  // imem I/F
  assign  imem_addr   = pc[IF];
  assign  imem_oe     = !rst && !stall[IF];

  reg     imem_reading = 1'b0;
  wire    imem_miss    = imem_reading && !imem_valid;
  always @(posedge clk) imem_reading <=
    rst         ? 1'b0 :
    imem_oe     ? 1'b1 :
    imem_valid  ? 1'b0 :
                  imem_reading;
  always @(posedge clk) bflush_reading_inst  <=
    rst                     ? 1'b0 :
    imem_reading && bflush  ? 1'b1 :
    imem_valid              ? 1'b0 :
                              bflush_reading_inst;

  assign  stall_req[IF] = 1'b0;

  // Instruction Decode stage ========================================
  wire[32-1:0]  pre_rrs1, pre_rrs2, rrs1, rrs2, rrd;
  GPR gpr(
    .clk(clk),
    .rst(rst),

    // If EM is stalling, re-read values used in EM stage in case they are updated.
    .rs1(stall[EM] ? RS1(ir[EM]) : RS1(ir[ID])),
    .pre_rrs1(pre_rrs1),
    .rrs1(rrs1),
    .rs2(stall[EM] ? RS2(ir[EM]) : RS2(ir[ID])),
    .pre_rrs2(pre_rrs2),
    .rrs2(rrs2),

    .rd(RD(ir[WB])),
    .rrd(rrd),  // rrd is forwarded to rrs1 and rrs2 in GPR module
    .we(GPRWE(ir[WB]))
  );

  // predetermine branch condition
  // bcond[7:0] is for branch instruction, [12:9] is for others like jal and mret.
  localparam[4-1:0] BC_JAL=4'd9, BC_JALR=4'd10, BC_ECALL=4'd11, BC_MRET=4'd12;
  reg [16-1:0]  bcond=16'h0;
  reg [32-1:0]  btarget_jal, btarget_jalr, btarget_branch;
  always @(posedge clk) if(!stall[EM]) begin
    if(!bflush && !insertb[ID]) begin
      if(OPCODE(ir[ID])==`BRANCH) begin
        bcond[`BEQ ] <=         pre_rrs1  ==         pre_rrs2;
        bcond[`BNE ] <=         pre_rrs1  !=         pre_rrs2;
        bcond[`BLT ] <= $signed(pre_rrs1) <  $signed(pre_rrs2);
        bcond[`BGE ] <= $signed(pre_rrs1) >= $signed(pre_rrs2);
        bcond[`BLTU] <=         pre_rrs1  <          pre_rrs2;
        bcond[`BGEU] <=         pre_rrs1  >=         pre_rrs2;
      end else begin
        bcond[`BGEU:`BEQ] <= 8'h00;
      end

      bcond[BC_JAL  ] <= OPCODE(ir[ID])==`JAL;
      bcond[BC_JALR ] <= OPCODE(ir[ID])==`JALR;
      bcond[BC_ECALL] <= OPCODE(ir[ID])==`SYSTEM && FUNCT3(ir[ID])==3'h0 && !ir[ID][21];
      bcond[BC_MRET ] <= OPCODE(ir[ID])==`SYSTEM && FUNCT3(ir[ID])==3'h0 &&  ir[ID][21];
    end else begin
      // When (bflush || insertb[ID]) is true, ir[EM] will be `NOP.
      // bcond should be deasserted so as to sync the state with ir[EM].
      bcond <= 16'h0;
    end
    btarget_jal   <= pc[ID]   +JIMM(ir[ID]);
    btarget_jalr  <= pre_rrs1 +IIMM(ir[ID]);
    btarget_branch<= pc[ID]   +BIMM(ir[ID]);
  end

  // stall if (ir[ID] is not ready) || (pre_rrs1 or pre_rrs2 is not ready but used)
  // TUNE: deal with the case where rs2 or rs1 is not used
  assign  stall_req[ID] = imem_miss || (
    GPRWE(ir[EM]) &&
    (RS1(ir[ID])==RD(ir[EM]) || RS2(ir[ID])==RD(ir[EM])) &&
    (OPCODE(ir[ID])==`BRANCH || OPCODE(ir[ID])==`JALR)  // they use pre_rrs1,2
  );

  // Execute and Memory access stage ========================================
  wire[32-1:0]  arslt, crslt;
  reg [32-1:0]  urslt, jrslt;

  // rrs1 rrs2 forwarding
  wire[32-1:0]  rrs1_fwd = RS1(ir[EM])==RD(ir[WB]) && GPRWE(ir[WB]) ? rrd : rrs1;
  wire[32-1:0]  rrs2_fwd = RS2(ir[EM])==RD(ir[WB]) && GPRWE(ir[WB]) ? rrd : rrs2;

  // R-type and I-type instructions result
  ALU alu (
    .clk(clk),
    .rst(rst),
    .opcode(OPCODE(ir[EM])),
    .funct3(FUNCT3(ir[EM])),
    .funct7(FUNCT7(ir[EM])),
    .opd1(rrs1_fwd),
    .opd2(OPCODE(ir[EM])==`OP ? rrs2_fwd : IIMM(ir[EM])), // OP or OPIMM ?
    .rslt(arslt)
  );
  always @(posedge clk) if(!stall[WB]) begin
    // AUIPC and LUI result
    urslt <= UIMM(ir[EM]) + (ir[EM][5] ? 32'h0 : pc[EM]);
    // JAL and JALR result
    jrslt <= pc[EM]+4;  // rrd <- pc+4
  end

  // CSR result
  wire[32-1:0]  mtvec, mepc;
  CSR csr (
    .clk(clk),
    .rst(rst),
    .halt(halt),
    .pc(pc[EM]),
    .ir(ir[EM]),
    .rrs1(rrs1_fwd),
    .crslt(crslt),
    .mtvec(mtvec),
    .mepc(mepc),
    .cycle(cycle)
  );

  // result selector
  localparam[2-1:0] DSEL_M=2'd0, DSEL_U=2'd1, DSEL_J=2'd2, DSEL_C=2'd3;
  reg [DSEL_C:DSEL_M] dsel;
  always @(posedge clk) if(!stall[WB]) begin
    dsel[DSEL_M]  <= OPCODE(ir[EM])==`LOAD;
    dsel[DSEL_U]  <= OPCODE(ir[EM])==`AUIPC   || OPCODE(ir[EM])==`LUI;
    dsel[DSEL_J]  <= OPCODE(ir[EM])==`JALR    || OPCODE(ir[EM])==`JAL;
    dsel[DSEL_C]  <= OPCODE(ir[EM])==`SYSTEM;
  end

  // branch
  assign  btarget = ~32'h1 & (
    bcond[FUNCT3(ir[EM])] ? btarget_branch  :
    bcond[BC_JAL]         ? btarget_jal     :
    bcond[BC_JALR]        ? btarget_jalr    :
    bcond[BC_ECALL]       ? mtvec & ~32'b11 : // don't support vectored trap address
    bcond[BC_MRET]        ? mepc            :
                            pc[EM]+4);
  assign  btaken  = |bcond;
  wire    bpmiss  = bptaken[EM] != btaken;
  // flush if (branch prediction miss) or (btb was not updated)
  assign  bflush  = (bpmiss || (btaken && pc[ID]!=btarget)) && !stall[EM];

  // mem I/F
  wire[32-1:0] pre_mem_addr   = rrs1_fwd + (ir[EM][5] ? SIMM(ir[EM]) : IIMM(ir[EM]));
  wire[ 4-1:0] pre_mem_oe     = rst ? 4'h0 : MEMOE(ir[EM]) & {4{!stall[EM]}};
  wire[32-1:0] pre_mem_wdata  = rrs2_fwd;
  wire[ 4-1:0] pre_mem_we     = rst ? 4'h0 : MEMWE(ir[EM]) & {4{!stall[EM]}};
  always @(posedge clk) mem_addr  <= pre_mem_addr;
  always @(posedge clk) mem_oe    <= pre_mem_oe;
  always @(posedge clk) mem_wdata <= pre_mem_wdata;
  always @(posedge clk) mem_we    <= pre_mem_we;
  initial {mem_addr, mem_oe, mem_wdata, mem_we} = 0;

  wire          mem_read      = pre_mem_oe[0] && !pre_mem_we[0];
  reg           mem_reading   = 1'b0;
  wire          mem_miss      = mem_reading && !mem_valid;
  always @(posedge clk) mem_reading <=
    rst         ? 1'b0 :
    mem_read    ? 1'b1 :
    mem_valid   ? 1'b0 :
                  mem_reading;

  assign  stall_req[EM] = |MEMOE(ir[EM]) & ~mem_ready; // cannot perform memory access

  // Write Back stage ========================================
  assign  rrd     =
    dsel[DSEL_M]  ? LOADEXT(ir[WB], mem_rdata) :
    dsel[DSEL_U]  ? urslt :
    dsel[DSEL_J]  ? jrslt :
    dsel[DSEL_C]  ? crslt :
                    arslt;

  assign  stall_req[WB] = mem_miss | halt;



  // Misc ========================================
  // branch prediction
  localparam  BTB_PC_WIDTH = 10;
  BARERAM #(.WIDTH(32), .SCALE(BTB_PC_WIDTH), .INIT(1)) btb (
    .clk(clk), .rst(rst),
    // read
    .oe0(!stall[ID]),
    .addr0(pc[IF][2+:BTB_PC_WIDTH]),
    .wdata0(32'h0),
    .we0(1'b0),
    .rdata0(bptarget_id),
    // write
    .oe1(CTRLXFER(ir[EM])),
    .addr1(pc[EM][2+:BTB_PC_WIDTH]),
    .wdata1(btarget),
    .we1(CTRLXFER(ir[EM])),
    .rdata1()
  );
  wire[ 2-1:0]  bpdata_id;
  wire          bptaken_id;
  reg [ 2-1:0]  bpdata[WB:ID];
  BIMODAL_PREDICTOR #(.SCALE(BTB_PC_WIDTH)) bp (
    .clk(clk),
    .rst(rst),
    // prediction
    .bp_pc(pc[IF]),
    .bp_taken(bptaken_id),
    .bp_oe(!stall[ID]),
    .bp_data(bpdata_id), // memorize this
    // feedback
    .fb_pc(pc[EM]),
    .fb_taken(btaken),
    .fb_we(CTRLXFER(ir[EM])),
    .fb_data(bpdata[EM]),
    // stat
    .cnt_hit(bp_cnt_hit),
    .cnt_pred(bp_cnt_pred)
  );
  always @(*) begin
    bptaken[ID] =
      rst                 ? 1'b0  :
      bflush_reading_inst ? 1'b0  :
      prev_insertb[IF]    ? 1'b0  :
                            bptaken_id;
    bpdata[ID]  =
      rst                 ? 2'b00 :
                            bpdata_id;
  end
  integer j;
  always @(posedge clk) begin
    for(j=EM; j<=WB; j=j+1) bptaken[j] <=
      rst           ? 1'b0        :
      j==EM&&bflush ? 1'b0        :
      insertb[j-1]  ? 1'b0        :
      stall[j]      ? bptaken[j]  :
                      bptaken[j-1];
    for(j=EM; j<=WB; j=j+1) bpdata[j] <=
      rst           ? 2'b00       :
      insertb[j-1]  ? 2'bxx       : // this data should not be written to bp
      stall[j]      ? bpdata[j]   :
                      bpdata[j-1];
  end

endmodule

`default_nettype wire
