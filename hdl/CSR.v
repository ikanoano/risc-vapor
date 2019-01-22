`default_nettype none
`timescale 1ns/100ps
`include "UTIL.v"
`include "INST.v"
`include "CONSTS.v"

module CSR (
  input   wire          clk,
  input   wire          rst,
  input   wire          halt,
  input   wire[32-1:0]  pc,
  input   wire[32-1:0]  ir,
  input   wire[32-1:0]  rrs1,
  // I/F for memory
  output  reg [32-1:0]  crslt,
  output  reg [32-1:0]  mtvec,  // h305
  output  reg [32-1:0]  mepc,   // h34x
  output  wire[64-1:0]  cycle
);

  // control and status registers
  wire[32-1:0]  mhartid=0;                                              // hf14
  wire[32-1:0]  misa={2'h1, 4'h0, 26'b00000000000000000100000000};      // h301
  initial       mtvec=`BOOT;                                            // h305
  reg [32-1:0]  mscratch, mcause;                                       // h34x
  initial       mepc=`BOOT;                                             // h34x
  reg [32-1:0]  mcycleh, mcycle;                                        // hbxx
  assign        cycle = {mcycleh, mcycle};
  always @(posedge clk) {mcycleh, mcycle} <=
    rst ? 64'h0 : ({mcycleh, mcycle}+{63'h0, ~halt});

  // CSR* result
  always @(posedge clk) begin
    // CSR read
    case(ir[20+:12])
      12'hf14: crslt <= mhartid;
      12'h301: crslt <= misa;
      12'h305: crslt <= mtvec & ~32'b11;
      12'h340: crslt <= mscratch;
      12'h341: crslt <= mepc;
      12'h342: crslt <= mcause;
      12'hb00: crslt <= mcycle;
      12'hb80: crslt <= mcycleh;
      default: crslt <= 32'h0;
    endcase

    // CSR write
    if(OPCODE(ir)==`SYSTEM) begin
      if(FUNCT3(ir)==3'h0) begin
        case(ir[21])
          1'b0: begin mepc<=pc; mcause<=32'hb; end // ECALL
          1'b1: begin end // MRET
        endcase
      end else begin
        case(ir[20+:12])
          12'h305: `CSRUPDATE(mtvec,    rrs1, ir)
          12'h340: `CSRUPDATE(mscratch, rrs1, ir)
          12'h341: `CSRUPDATE(mepc,     rrs1, ir)
          12'h342: `CSRUPDATE(mcause,   rrs1, ir)
          default: begin end
        endcase
      end
    end
  end

  function[ 5-1:0]  OPCODE(input[32-1:0] inst); OPCODE  = inst[ 6: 2]; endfunction
  function[ 5-1:0]  RS1   (input[32-1:0] inst); RS1     = inst[19:15]; endfunction
  function[ 3-1:0]  FUNCT3(input[32-1:0] inst); FUNCT3  = inst[14:12]; endfunction

endmodule

`default_nettype wire
