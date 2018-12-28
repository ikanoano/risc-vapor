`default_nettype none
`timescale 1ns/100ps
`include "UTIL.v"
`include "INST.v"

//https://www.xilinx.com/support/documentation/application_notes/xapp210.pdf
module LFSR (
  input   wire          clk,
  output  wire[32-1:0]  rnd
);
  reg [38:1] sr=38'h19;
  always @(posedge clk) sr <= {sr[37:1], ~^{sr[38], sr[6], sr[5], sr[1]}};
  assign  rnd = sr[1+:32];
endmodule

`default_nettype wire
