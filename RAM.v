`default_nettype none
`timescale 1ns/100ps
`include "UTIL.v"

// dual-port block RAM with two write ports
module RAM #(
  parameter SCALE = 10
) (
  input   wire            clk,
  input   wire            rst,

  input   wire            oe0,
  input   wire[SCALE-1:0] addr0,
  input   wire[   32-1:0] wdata0,
  input   wire[    4-1:0] we0,
  output  reg [   32-1:0] rdata0,

  input   wire            oe1,
  input   wire[SCALE-1:0] addr1,
  input   wire[   32-1:0] wdata1,
  input   wire[    4-1:0] we1,
  output  reg [   32-1:0] rdata1
);

  (* ram_style = "block" *)
  reg [32-1:0] ram[0:2**SCALE-1];

  always @(posedge clk) begin
    if(oe0) begin
      if(we0[0]) ram[addr0]  <= wdata0;
      rdata0  <= we0[0] ? wdata0 : ram[addr0];
    end

    if(oe1) begin
      if(we1[0]) ram[addr1]  <= wdata1;
      rdata1  <= we1[0] ? wdata1 : ram[addr1];
    end

    if(!rst && (
        (we0!=4'b1111 && we0!=4'b0000) ||
        (we1!=4'b1111 && we1!=4'b0000))) begin
      $display("Not implemented: byte write");
      $finish();
    end
  end

  // Initialize with dummy value or the ram may be eliminated by optimization.
  //integer i;
  //initial begin
  //  $display("%m init");
  //  for(i=0; i<2**SCALE; i=i+1) ram[i]=SCALE+i;
  //  $display("%m done");
  //end

  initial if(SCALE<1) begin $display("SCALE must be >=1"); $finish(); end
endmodule
