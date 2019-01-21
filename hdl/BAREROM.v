`default_nettype none
`timescale 1ns/100ps
`include "UTIL.v"

module BAREROM #(
  parameter WIDTH = 8,
  parameter SCALE = 10  // 2**SCALE word is allocated
) (
  input   wire            clk,
  input   wire            rst,

  input   wire            oe0,
  input   wire[SCALE-1:0] addr0,
  output  wire[WIDTH-1:0] rdata0,

  input   wire            oe1,
  input   wire[SCALE-1:0] addr1,
  output  wire[WIDTH-1:0] rdata1
);
  BARERAM #(.WIDTH(WIDTH), .SCALE(SCALE)) rom (
    clk, rst,
    oe0, addr0, {WIDTH{1'b0}}, 1'h0, rdata0,
    oe1, addr1, {WIDTH{1'b0}}, 1'h0, rdata1
  );
endmodule

`default_nettype wire
