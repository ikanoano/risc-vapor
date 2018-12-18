`default_nettype none
`timescale 1ns/100ps
`include "UTIL.v"

module DCACHE #(
  parameter MEM_SCALE = 27,
  parameter SCALE     = 10  // 2**SCALE byte is allocated
) (
  input   wire                clk,
  input   wire                rst,
  // r/w from processor
  input   wire[        4-1:0] oe,
  input   wire[MEM_SCALE-1:0] addr,
  input   wire[       32-1:0] wdata,
  input   wire[        4-1:0] we,
  output  wire[       32-1:0] rdata,
  output  wire                hit,
  // load data from dram
  input   wire                load_oe,
  input   wire[MEM_SCALE-1:0] load_addr,
  input   wire[       32-1:0] load_wdata,
  input   wire[        4-1:0] load_we
);
  localparam WIDTH_TAG = MEM_SCALE-SCALE;

  reg [4+WIDTH_TAG-1:0] valid_and_tag[0:2**(SCALE-2)-1];
  RAM #(
    .SCALE(SCALE)
  ) body (
    .clk(clk),
    .rst(rst),

    .oe0(oe[0]),
    .addr0(addr[0+:SCALE]),
    .wdata0(wdata),
    .we0(we),
    .rdata0(rdata),

    .oe1(load_oe),
    .addr1(load_addr[0+:SCALE]),
    .wdata1(load_wdata),
    .we1(load_we),
    .rdata1()
  );

  reg [WIDTH_TAG-1:0] rtag=0;
  reg [        4-1:0] rvalid=0;
  always @(posedge clk) {rvalid, rtag} <= valid_and_tag[addr[2+:SCALE-2]];

  reg [MEM_SCALE-1:0] waddr=0;
  reg [        4-1:0] wwe=0;
  always @(posedge clk) waddr     <= we[0] ? addr : load_addr;
  always @(posedge clk) wwe       <= we | load_we;
  wire[WIDTH_TAG-1:0] wtag        = waddr[SCALE+:WIDTH_TAG];
  wire[        4-1:0] wvalid      = (wwe<<waddr[1:0]) | (rtag==wtag ? rvalid : 4'h0);
  always @(posedge clk) if(wwe[0]) valid_and_tag[waddr[2+:SCALE-2]] <= {wvalid, wtag};

  reg [        4-1:0] prev_oe=0;
  reg [MEM_SCALE-1:0] prev_addr=0;
  always @(posedge clk) prev_oe   <= oe;
  always @(posedge clk) prev_addr <= addr;
  wire[WIDTH_TAG-1:0] htag        = prev_addr[SCALE+:WIDTH_TAG];
  wire[        4-1:0] hvalid      = prev_oe<<prev_addr[1:0];
  assign hit = prev_oe[0] && rtag==htag && (hvalid&rvalid)==hvalid;

  always @(posedge clk) begin
    //if(load_oe && oe[0]) begin
    //  $display("Conflict oe: %b %b", load_oe, oe);
    //  $finish();
    //end
    if(load_we[0] && we[0]) begin
      $display("Conflict we: %b %b", load_we, we);
      $finish();
    end
    if(we[0] && ({2'd0, we}<<addr[1:0])>=16) begin
      $display("Missaligned update not supported: %b %x", we, addr);
      $finish();
    end
    if(load_we[0] && {2'd0, load_we}<<load_addr[1:0]>=16) begin
      $display("Missaligned load not supported: %b %x", load_we, load_addr);
      $finish();
    end
  end


  integer i;
  initial for(i=0; i<2**(SCALE-2); i=i+1) valid_and_tag[i] = 0;
endmodule

`default_nettype wire
