`default_nettype none
`timescale 1ns/100ps
`include "UTIL.v"

// dual-port ROM
module ROM #(
  parameter SCALE = 10
) (
  input   wire            clk,
  input   wire            rst,

  input   wire            oe0,
  input   wire[SCALE-1:0] addr0,
  output  wire[   32-1:0] rdata0,

  input   wire            oe1,
  input   wire[SCALE-1:0] addr1,
  output  wire[   32-1:0] rdata1
);
  RAM #(.SCALE(SCALE)) rom (
    clk, rst,
    oe0, addr0, 0, 4'h0, rdata0,
    oe1, addr1, 0, 4'h0, rdata1
  );
endmodule
