`default_nettype none
`timescale 1ns/100ps
`include "INST.v"

// Arithmetic logic unit only process I-type or R-type instructions.
module ALU (
  input   wire          clk,
  input   wire          rst,
  input   wire[ 5-1:0]  opcode,
  input   wire[   2:0]  funct3,
  input   wire[ 7-1:0]  funct7,
  input   wire[32-1:0]  opd1, // first operand
  input   wire[32-1:0]  opd2, // second operand
  output  wire[32-1:0]  rslt  // has 1-cycle latency
);
wire[ 5-1:0]  shamt   = opd2[0+:5];
wire          r_type  = opcode[3];

// arithmetic logic
reg [32-1:0]  rslt_logi,rslt_add, rslt_sub, rslt_sll,
              rslt_slt, rslt_sltu,rslt_srl, rslt_sra;
always @(posedge clk) begin
  rslt_logi <=
    funct3==`XOR  ? opd1 ^ opd2 :
    funct3==`OR   ? opd1 | opd2 :
    funct3==`AND  ? opd1 & opd2 :
                    32'hXXXX;
  rslt_add  <= opd1 + opd2;
  rslt_sub  <= opd1 - opd2;
  rslt_slt  <= $signed(opd1) < $signed(opd2)  ? 32'b1 : 32'b0;
  rslt_sltu <=         opd1  <         opd2   ? 32'b1 : 32'b0;
  rslt_sll  <=         opd1  <<  shamt;
  rslt_srl  <=         opd1  >>  shamt;
  rslt_sra  <= $signed(opd1) >>> shamt;
end

// result selector
localparam[3-1:0]
  RSLT_LOGI = 0,
  RSLT_ADD  = 1,
  RSLT_SUB  = 2,
  RSLT_SLL  = 3,
  RSLT_SLT  = 4,
  RSLT_SLTU = 5,
  RSLT_SRL  = 6,
  RSLT_SRA  = 7;

reg [ 3-1:0]  rslt_sel=0;
always @(posedge clk) rslt_sel <=
  funct3==`SUB && r_type && funct7[5]==`SUB7  ? RSLT_SUB  :
  funct3==`ADD                                ? RSLT_ADD  :
  funct3==`SLL                                ? RSLT_SLL  :
  funct3==`SLT                                ? RSLT_SLT  :
  funct3==`SLTU                               ? RSLT_SLTU :
  funct3==`SRL  && funct7[5]==`SRL7           ? RSLT_SRL  :
  funct3==`SRA  && funct7[5]==`SRA7           ? RSLT_SRA  :
                                      RSLT_LOGI;

// select a proper result
assign  rslt =
  rslt_sel==RSLT_LOGI ? rslt_logi:
  rslt_sel==RSLT_ADD  ? rslt_add :
  rslt_sel==RSLT_SUB  ? rslt_sub :
  rslt_sel==RSLT_SLL  ? rslt_sll :
  rslt_sel==RSLT_SLT  ? rslt_slt :
  rslt_sel==RSLT_SLTU ? rslt_sltu:
  rslt_sel==RSLT_SRL  ? rslt_srl :
  rslt_sel==RSLT_SRA  ? rslt_sra :
                        32'hXXXX;

endmodule
