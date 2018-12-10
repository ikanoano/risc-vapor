`default_nettype none
`timescale 1ns/100ps
`include "UTIL.v"

module BARERAM #(
  parameter WIDTH = 8,
  parameter SCALE = 10, // 2**SCALE word is allocated
  parameter INIT  = 0
) (
  input   wire            clk,
  input   wire            rst,

  input   wire            oe0,
  input   wire[SCALE-1:0] addr0,
  input   wire[WIDTH-1:0] wdata0,
  input   wire            we0,
  output  reg [WIDTH-1:0] rdata0,

  input   wire            oe1,
  input   wire[SCALE-1:0] addr1,
  input   wire[WIDTH-1:0] wdata1,
  input   wire            we1,
  output  reg [WIDTH-1:0] rdata1
);
  (* ram_style = "block" *)
  reg [WIDTH-1:0] ram[0:2**(SCALE)-1];

  always @(posedge clk) begin
    if(oe0) begin
      if(we0) begin
        ram[addr0]  <= wdata0;
        rdata0      <= wdata0;
      end else begin
        rdata0      <= ram[addr0];
      end
    end

    if(oe1) begin
      if(we1) begin
        ram[addr1]  <= wdata1;
        rdata1      <= wdata1;
      end else begin
        rdata1      <= ram[addr1];
      end
    end
  end

  initial if(SCALE<1) begin $display("SCALE must be >=1"); $finish(); end

  integer i;
  initial if(INIT) begin
    for(i=0; i<2**SCALE; i=i+1) ram[i] = {WIDTH{1'b0}};
  end
endmodule

`default_nettype wire
