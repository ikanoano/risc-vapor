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
  output  wire[16-1:0]  imem_addr,
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
  localparam  IF = 0, ID = 1, EM = 2, WB = 3;

  // stall request
  wire[WB:IF]   stall_req;
  // Stall all stages preceding a stage which requests to stall
  wire[WB:IF]   stall   = stall_req |  {1'b0, stall[WB:ID]};
  // Insert bubble if succeeding stages don't assert stall_req.
  wire[WB:IF]   insertb = stall_req & ~{1'b0, stall[WB:ID]};

  // branch target, branch taken, signal to flush ID to EM stage
  wire[32-1:0]  btarget;
  wire          btaken, bflush;
  // branch prediction addr
  wire[32-1:0]  bptarget_id;
  reg [WB:ID]   bptaken;
  wire          bpmiss;

  reg [WB:IF]   prev_stall=0;   // stall in last cycle
  reg [WB:IF]   prev_insertb=0; // insertb in last cycle
  reg           prev_bflush=0;  // bflush in last cycle
  always @(posedge clk) prev_stall    <= stall;
  always @(posedge clk) prev_insertb  <= insertb;
  always @(posedge clk) prev_bflush   <= bflush;

  // Program Counters for each stage
  reg [32-1:0]  pc_if_no_bpred=0;
  reg [32-1:0]  pc[IF:WB];
  integer i;

  always @(posedge clk) pc_if_no_bpred <=
    rst             ? `BOOT       :
    bflush          ? btarget     :
    stall[IF]       ? pc[IF]      :
                      pc[IF]+4;
  always @(*) pc[IF] = bptaken[ID] ? bptarget_id : pc_if_no_bpred; // combinational
  always @(posedge clk) begin
    for(i=ID; i<=WB; i=i+1) pc[i] <= // sequential
      rst           ? `BOOT       :
      stall[i]      ? pc[i]       :
                      pc[i-1];
  end
  assign  pc_disp = pc[WB];

  // Instruction Registers for each stage
  reg [32-1:0]  ir[ID:WB];
  always @(*)           ir[ID]  = // combinational
      rst                     ? `NOP        :
      prev_bflush             ? `NOP        :
      prev_insertb[IF]        ? `NOP        :
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
  assign  imem_addr   = pc[IF][0+:16];
  assign  imem_oe     = !stall[IF];

  reg     imem_reading = 1'b0;
  wire    imem_miss    = imem_reading && !imem_valid;
  always @(posedge clk) imem_reading <=
    rst         ? 1'b0 :
    imem_oe     ? 1'b1 :
    imem_valid  ? 1'b0 :
                  imem_reading;

  assign  stall_req[IF] = 1'b0;

  // Instruction Decode stage ========================================
  wire[32-1:0]  pre_rrs1, pre_rrs2, rrd;
  GPR gpr(
    .clk(clk),
    .rst(rst),

    // If EM is stalling, forward a register value.
    // Otherwise, read normally
    .rs1(!stall[EM] ? RS1(ir[ID]) : RS1(ir[EM])),
    .rrs1(pre_rrs1),
    .rs2(!stall[EM] ? RS2(ir[ID]) : RS2(ir[EM])),
    .rrs2(pre_rrs2),

    .rd(RD(ir[WB])),
    .rrd(rrd),  // rrd is forwarded to rrs1 and rrs2 in GPR module
    .we(GPRWE(ir[WB]))
  );

  reg [32-1:0]  rrs1, rrs2;
  always @(posedge clk) begin
    rrs1    <= pre_rrs1;
    rrs2    <= pre_rrs2;
  end

  // prefetch values used by branch instructions
  reg           isecall, ismret;
  reg [32-1:0]  btarget_jal, btarget_jalr, btarget_branch;
  reg [ 8-1:0]  bcond=8'hxx;
  always @(posedge clk) if(!stall[EM]) begin
    isecall <= !bflush && OPCODE(ir[ID])==`SYSTEM && FUNCT3(ir[ID])==3'h0 && !ir[ID][21];
    ismret  <= !bflush && OPCODE(ir[ID])==`SYSTEM && FUNCT3(ir[ID])==3'h0 &&  ir[ID][21];
    btarget_jal   <= pc[ID]   +JIMM(ir[ID]);
    btarget_jalr  <= pre_rrs1 +IIMM(ir[ID]);
    btarget_branch<= pc[ID]   +BIMM(ir[ID]);
    bcond[`BEQ ]  <=           pre_rrs1  ==           pre_rrs2;
    bcond[`BNE ]  <=           pre_rrs1  !=           pre_rrs2;
    bcond[`BLT ]  <=   $signed(pre_rrs1) <    $signed(pre_rrs2);
    bcond[`BGE ]  <=   $signed(pre_rrs1) >=   $signed(pre_rrs2);
    bcond[`BLTU]  <= $unsigned(pre_rrs1) <  $unsigned(pre_rrs2);
    bcond[`BGEU]  <= $unsigned(pre_rrs1) >= $unsigned(pre_rrs2);
  end

  // stall if (ir[ID] is not ready) or (source operand is still in EM stage)
  // TUNE: deal with the case where rs2 or rs1 is not used
  assign  stall_req[ID] = imem_miss || (
    GPRWE(ir[EM]) &&
    (RD(ir[EM])==RS1(ir[ID]) || RD(ir[EM])==RS2(ir[ID])) &&
    (OPCODE(ir[ID])==`BRANCH || OPCODE(ir[ID])==`JALR)  // they use pre_rrs1
  );

  // Execute and Memory access stage ========================================
  wire[ 5-1:0]  op_em = OPCODE(ir[EM]);
  wire[32-1:0]  arslt;
  reg [32-1:0]  urslt, jrslt;
  wire[32-1:0]  crslt;

  // rrs1 rrs2 forwarding
  wire[32-1:0]  rrs1_fwd = RS1(ir[EM])==RD(ir[WB]) && GPRWE(ir[WB]) ? rrd : rrs1;
  wire[32-1:0]  rrs2_fwd = RS2(ir[EM])==RD(ir[WB]) && GPRWE(ir[WB]) ? rrd : rrs2;

  // R-type and I-type instructions result
  wire[32-1:0]  operand1 = rrs1_fwd;
  wire[32-1:0]  operand2 = OPCODE(ir[EM])==`OP ? rrs2_fwd : IIMM(ir[EM]);
  ALU alu (
    .clk(clk),
    .rst(rst),
    .opcode(OPCODE(ir[EM])),
    .funct3(FUNCT3(ir[EM])),
    .funct7(FUNCT7(ir[EM])),
    .opd1(operand1),
    .opd2(operand2),
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
  reg sel_mem, sel_urslt, sel_jrslt, sel_crslt;
  always @(posedge clk) if(!stall[WB]) begin
    sel_mem   <= op_em==`LOAD;
    sel_urslt <= op_em==`AUIPC || op_em==`LUI;
    sel_jrslt <= op_em==`JALR  || op_em==`JAL;
    sel_crslt <= op_em==`SYSTEM;
  end

  // branch
  assign  btarget = ~32'h1 & (
    op_em==`JAL           ? btarget_jal     :
    op_em==`JALR          ? btarget_jalr    :
    op_em==`BRANCH && bcond[FUNCT3(ir[EM])] ? btarget_branch  :
    isecall               ? mtvec & ~32'b11 : // don't support vectored trap address
    ismret                ? mepc            :
                            pc[EM]+4);
  assign  btaken  = op_em==`JAL || op_em==`JALR || isecall || ismret ||
                    (op_em==`BRANCH && bcond[FUNCT3(ir[EM])]);
  assign  bpmiss  = bptaken[EM] != btaken;
  // flush if (branch prediction miss or btb was not updated)
  assign  bflush  = (bpmiss || (btaken && pc[ID]!=btarget)) && !stall[EM];

  // mem I/F
  wire[32-1:0] pre_mem_addr   = rrs1_fwd + (ir[EM][5] ? SIMM(ir[EM]) : IIMM(ir[EM]));
  wire[ 4-1:0] pre_mem_oe     = MEMOE(ir[EM]) & {4{!stall[EM]}};
  wire[32-1:0] pre_mem_wdata  = rrs2_fwd;
  wire[ 4-1:0] pre_mem_we     = MEMWE(ir[EM]) & {4{!stall[EM]}};
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
  wire[32-1:0]  mem_rdata_extended = LOADEXT(ir[WB], mem_rdata);
  assign  rrd     =
    sel_mem   ? mem_rdata_extended :
    sel_urslt ? urslt :
    sel_jrslt ? jrslt :
    sel_crslt ? crslt :
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
      rst               ? 1'b0  :
      prev_bflush       ? 1'b0  :
      prev_insertb[IF]  ? 1'b0  :
                          bptaken_id;
    bpdata[ID]  =
      rst               ? 2'b00 :
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

  // instrunction parser
  function[ 5-1:0]  OPCODE(input[32-1:0] inst); OPCODE  = inst[ 6: 2]; endfunction
  function[ 5-1:0]  RD    (input[32-1:0] inst); RD      = inst[11: 7]; endfunction
  function[ 5-1:0]  RS1   (input[32-1:0] inst); RS1     = inst[19:15]; endfunction
  function[ 5-1:0]  RS2   (input[32-1:0] inst); RS2     = inst[24:20]; endfunction
  function[ 3-1:0]  FUNCT3(input[32-1:0] inst); FUNCT3  = inst[14:12]; endfunction
  function[ 7-1:0]  FUNCT7(input[32-1:0] inst); FUNCT7  = inst[31:25]; endfunction

  function[32-1:0]  IIMM  (input[32-1:0] inst); IIMM    = {{21{inst[31]}},                           inst[30:25],inst[24:21],inst[20]}; endfunction
  function[32-1:0]  SIMM  (input[32-1:0] inst); SIMM    = {{21{inst[31]}},                           inst[30:25],inst[11: 8],inst[ 7]}; endfunction
  function[32-1:0]  BIMM  (input[32-1:0] inst); BIMM    = {{20{inst[31]}},                  inst[ 7],inst[30:25],inst[11: 8],    1'b0}; endfunction
  function[32-1:0]  UIMM  (input[32-1:0] inst); UIMM    = {inst[31],inst[30:20],inst[19:12],                                    12'b0}; endfunction
  function[32-1:0]  JIMM  (input[32-1:0] inst); JIMM    = {{12{inst[31]}},      inst[19:12],inst[20],inst[30:25],inst[24:21],    1'b0}; endfunction
  function[32-1:0]  IMM   (input[32-1:0] inst); IMM     =
    OPCODE(inst)==`STORE  ? SIMM(inst)  :
    OPCODE(inst)==`BRANCH ? BIMM(inst)  :
    OPCODE(inst)==`AUIPC  ? UIMM(inst)  :
    OPCODE(inst)==`LUI    ? UIMM(inst)  :
    OPCODE(inst)==`JAL    ? JIMM(inst)  :
                            IIMM(inst);
  endfunction

  function[   0:0]  GPRWE (input[32-1:0] inst); GPRWE  =  // gpr write enable
    RD(inst)!=5'd0 && OPCODE(inst)!=`STORE && OPCODE(inst)!=`BRANCH;
  endfunction
  function[ 4-1:0]  MEMOE (input[32-1:0] inst); MEMOE  =  // mem output enable
    OPCODE(inst)!=`LOAD   ? MEMWE(inst) : // not store
    FUNCT3(inst)==`LB     ? 4'b0001 :
    FUNCT3(inst)==`LH     ? 4'b0011 :
    FUNCT3(inst)==`LW     ? 4'b1111 :
    FUNCT3(inst)==`LBU    ? 4'b0001 :
    FUNCT3(inst)==`LHU    ? 4'b0011 :
                            4'bxxxx;
  endfunction
  function[ 4-1:0]  MEMWE (input[32-1:0] inst); MEMWE  =  // mem write enable
    OPCODE(inst)!=`STORE  ? 4'b0000 : // not store
    FUNCT3(inst)==`SB     ? 4'b0001 :
    FUNCT3(inst)==`SH     ? 4'b0011 :
    FUNCT3(inst)==`SW     ? 4'b1111 :
                            4'bxxxx;
  endfunction

  function[ 1-1:0]  USERD (input[32-1:0] inst); USERD  =
    OPCODE(inst)!=`STORE  &&
    OPCODE(inst)!=`BRANCH &&
    OPCODE(inst)!=`MISCMEM;
  endfunction
  function[ 1-1:0]  USERS1(input[32-1:0] inst); USERS1 =
    OPCODE(inst)!=`AUIPC  &&
    OPCODE(inst)!=`LUI    &&
    OPCODE(inst)!=`JAL    &&
    OPCODE(inst)!=`MISCMEM;
    //OPCODE(inst)==`SYSTEM && (...);  TUNE: some functs in SYSTEM don't use RS1
  endfunction
  function[ 1-1:0]  USERS2(input[32-1:0] inst); USERS2 =
    OPCODE(inst)==`STORE  ||
    OPCODE(inst)==`OP     ||
    OPCODE(inst)==`BRANCH;
  endfunction
  function[ 1-1:0]  USEIMM(input[32-1:0] inst); USEIMM =
    OPCODE(inst)!=`OP     &&
    OPCODE(inst)!=`MISCMEM;
  endfunction

  function[ 1-1:0]  CTRLXFER(input[32-1:0] inst); CTRLXFER =
    OPCODE(inst)==`JAL    ||
    OPCODE(inst)==`JALR   ||
    OPCODE(inst)==`BRANCH;
  endfunction

  function[32-1:0]  LOADEXT(input[32-1:0] inst, input[32-1:0] ledata);  LOADEXT =
    FUNCT3(inst)==`LB   ? {{24{ledata[ 7]}}, ledata[0+: 8]} :
    FUNCT3(inst)==`LH   ? {{16{ledata[15]}}, ledata[0+:16]} :
    FUNCT3(inst)==`LW   ?                    ledata[0+:32]  :
    FUNCT3(inst)==`LBU  ? {{24{      1'b0}}, ledata[0+: 8]} :
    FUNCT3(inst)==`LHU  ? {{16{      1'b0}}, ledata[0+:16]} :
                          32'hxxxxxxxx;
  endfunction

endmodule

`default_nettype wire
