`default_nettype none
`timescale 1ns/100ps
`include "INST.v"

module PROCESSOR (
  input   wire          clk,
  input   wire          rst,
  // I/F for memory
  output  wire[16-1:0]  imem_addr,
  output  wire          imem_oe,
  input   wire[32-1:0]  imem_rdata,
  input   wire          imem_ready,

  output  wire[32-1:0]  mem_addr,
  output  wire          mem_oe,
  output  wire[32-1:0]  mem_wdata,
  output  wire[ 4-1:0]  mem_we,
  input   wire[32-1:0]  mem_rdata,
  input   wire          mem_ready
);
localparam IF = 0, ID = 1, EM = 2, WB = 3;

// Stall all stages preceding a stage where stall_req signal asserts.
// Insert bubble if succeeding stages don't assert stall_req.
wire[WB:IF] stall_req;
wire[WB:IF] stall   = stall_req |  {1'b0, stall[WB:ID]};
wire[WB:IF] insertb = stall_req & ~{1'b0, stall[WB:ID]};

wire[32-1:0]  ir[ID:WB];    // Instruction Registers
reg [32-1:0]  pc[IF:WB];    // Program Counters

reg [32-1:0]  _ir[EM:WB];
reg           prev_bflush=0;  // bflush in last cycle
reg [WB:IF]   prev_stall=0;   // stall in last cycle
reg [WB:IF]   prev_insertb=0; // insertb in last cycle

integer i;
always @(posedge clk) begin
  for(i=EM; i<=WB; i=i+1) _ir[i] <=
    rst                       ? `NOP        :
    i==EM && bflush           ? `NOP        :
    insertb[i-1]              ? `NOP        :
    stall[i]                  ? ir[i]       :
                                ir[i-1];
  pc[IF]  <=
    rst                       ? 0           :
    btaken && bflush          ? btarget     :
    stall[IF]                 ? pc[IF]      :
                                pc[IF]+4;
  for(i=ID; i<=WB; i=i+1) pc[i] <=
    rst                       ? 0           :
    stall[i]                  ? pc[i]       :
                                pc[i-1];
end

generate genvar gi;
  // Because imem has 1-cycle latency, we have to set ir[ID] after rdata is ready
  assign  ir[ID]  =
    rst                       ? `NOP        :
    prev_bflush               ? `NOP        :
    prev_insertb[IF]          ? `NOP        :
                                imem_rdata;
  for(gi=EM; gi<=WB; gi=gi+1) assign ir[gi] = _ir[gi];
endgenerate

always @(posedge clk) prev_bflush   <= bflush;
always @(posedge clk) prev_stall    <= stall;
always @(posedge clk) prev_insertb  <= insertb;

// Instruction Fetch stage ========================================
// imem I/F
wire    imem_miss;
assign  imem_addr     = pc[IF][0+:16];
assign  imem_oe       = !stall[IF];
assign  stall_req[IF] = 1'b0;

// Instruction Decode stage ========================================
wire[32-1:0]  rrs1_gpr, rrs2_gpr, rrd;
GPR gpr(
  .clk(clk),
  .rst(rst),

  .rs1(RS1(ir[ID])),
  .rrs1(rrs1_gpr),
  .rs2(RS2(ir[ID])),
  .rrs2(rrs2_gpr),

  .rd(RD(ir[WB])),
  .rrd(rrd),  // rrd is forwarded to rrs1 and rrs2 in GPR module
  .we(GPRWE(ir[WB]))
);

reg [32-1:0]  rrs1, rrs2, opd1, opd2;
always @(posedge clk) begin
  rrs1    <= rrs1_gpr;
  rrs2    <= rrs2_gpr;

  // ALU operands
  opd1    <= rrs1_gpr;
  opd2    <= OPCODE(ir[ID])==`OP ? rrs2_gpr : IIMM(ir[ID]);
end

wire[5-1:0]   rd_em=RD(ir[EM]), rs1_id=RS1(ir[ID]), rs2_id=RS2(ir[ID]);

reg     prev_imem_read=1'b0;
always @(posedge clk) if(!imem_miss) prev_imem_read <= imem_oe;
assign  imem_miss = prev_imem_read & !imem_ready;

// stall if (ir[ID] is not ready) or (source operand is still in EM stage)
// TUNE: deal with the case where rs2 or rs1 is not used
assign  stall_req[ID] = !rst && (imem_miss ||
  (GPRWE(ir[EM]) && (rd_em==rs1_id || rd_em==rs2_id)));

// Execute and Memory access stage ========================================
wire[ 5-1:0]  op_em = OPCODE(ir[EM]);
wire[32-1:0]  rslt;
reg [32-1:0]  urslt, jrslt;

// R-type or I-type instructions result
ALU alu (
  .clk(clk),
  .rst(rst),
  .opcode(OPCODE(ir[EM])),
  .funct3(FUNCT3(ir[EM])),
  .funct7(FUNCT7(ir[EM])),
  .opd1(opd1),
  .opd2(opd2),
  .rslt(rslt)
);
// AUIPC and LUI result
always @(posedge clk) urslt <= UIMM(ir[EM]) + (ir[EM][5] ? 0 : pc[EM]);
// JAL and JALR result
always @(posedge clk) jrslt <= pc[EM]+4;  // rrd<-pc+4

// result selector
reg sel_dmem, sel_urslt, sel_jrslt;
always @(posedge clk) begin
  sel_dmem  <= op_em==`LOAD;
  sel_urslt <= op_em==`AUIPC || op_em==`LUI;
  sel_jrslt <= op_em==`JALR  || op_em==`JAL;
end

// branch instructions
wire[32-1:0]  btarget =
  op_em==`JAL     ? pc[EM]+JIMM(ir[EM]) :
  op_em==`JALR    ? rrs1  +IIMM(ir[EM]) :
  op_em==`BRANCH  ? pc[EM]+BIMM(ir[EM]) :
                    32'hxxxxxxxx;
wire  btaken  = op_em==`JAL || op_em==`JALR || (op_em==`BRANCH & (
  FUNCT3(ir[EM])==`BEQ  ? rrs1==rrs2                        :
  FUNCT3(ir[EM])==`BNE  ? rrs1!=rrs2                        :
  FUNCT3(ir[EM])==`BLT  ?   $signed(rrs1)<   $signed(rrs2)  :
  FUNCT3(ir[EM])==`BGE  ?   $signed(rrs1)>=  $signed(rrs2)  :
  FUNCT3(ir[EM])==`BLTU ? $unsigned(rrs1)< $unsigned(rrs2)  :
  FUNCT3(ir[EM])==`BGEU ? $unsigned(rrs1)>=$unsigned(rrs2)  :
                          1'bx));
wire  bflush  = btaken && pc[ID]!=btarget;

// mem I/F
assign  mem_addr      = rrs1 + (ir[EM][5] ? SIMM(ir[EM]) : IIMM(ir[EM]));
assign  mem_oe        = MEMOE(ir[EM]);
assign  mem_wdata     = rrs2;
assign  mem_we        = MEMWE(ir[EM]);

assign  stall_req[EM] = 1'b0;

// Write Back stage ========================================
assign  rrd           =
  sel_dmem  ? mem_rdata :
  sel_urslt ? urslt :
  sel_jrslt ? jrslt :
              rslt;

reg     prev_dmem_read=1'b0;
always @(posedge clk) prev_dmem_read <=
  rst         ? 1'b0 :
  !dmem_miss  ? mem_oe && !mem_we[0] :
                1'b1;//==prev_dmem_read;

wire    dmem_miss = prev_dmem_read & !mem_ready;
assign  stall_req[WB] = !rst && dmem_miss;



// Misc ========================================
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
function[   0:0]  MEMOE (input[32-1:0] inst); MEMOE  =  // dmem output enable
  OPCODE(inst)==`LOAD || OPCODE(inst)==`STORE;
endfunction
function[ 4-1:0]  MEMWE (input[32-1:0] inst); MEMWE  =  // dmem write enable
  OPCODE(inst)!=`STORE  ? 4'b0000 : // not store
  FUNCT3(inst)==`SB     ? 4'b0001 :
  FUNCT3(inst)==`SH     ? 4'b0011 :
  FUNCT3(inst)==`SW     ? 4'b1111 :
                          4'bxxxx;
endfunction

endmodule
