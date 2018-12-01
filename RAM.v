`default_nettype none
`timescale 1ns/100ps
`include "UTIL.v"

// dual-port partial read/write block RAM
module RAM #(
  parameter SCALE = 10  // 2**SCALE byte is allocated
) (
  input   wire            clk,
  input   wire            rst,

  input   wire            oe0,
  input   wire[SCALE-1:0] addr0,
  input   wire[   32-1:0] wdata0,
  input   wire[    4-1:0] we0,
  output  wire[   32-1:0] rdata0,

  input   wire            oe1,
  input   wire[SCALE-1:0] addr1,
  input   wire[   32-1:0] wdata1,
  input   wire[    4-1:0] we1,
  output  wire[   32-1:0] rdata1
);
  wire[SCALE-3:0] word0 = addr0[2+:SCALE-2];
  wire[SCALE-3:0] word1 = addr1[2+:SCALE-2];

  // 2**(SCALE-2) word = 2**SCALE byte
  (* ram_style = "block" *)
  reg [ 8-1:0]
    ram3[0:2**(SCALE-2)-1],
    ram2[0:2**(SCALE-2)-1],
    ram1[0:2**(SCALE-2)-1],
    ram0[0:2**(SCALE-2)-1];

  wire[32-1:0]  pad_wdata0  = wdata0  << ({3'h0, addr0[1:0]}<<3);
  wire[32-1:0]  pad_wdata1  = wdata1  << ({3'h0, addr1[1:0]}<<3);
  wire[ 4-1:0]  pad_we0     = we0     << (addr0[1:0]);
  wire[ 4-1:0]  pad_we1     = we1     << (addr1[1:0]);

  reg [   1:0]  offset0, offset1;
  reg [32-1:0]  _rdata0, _rdata1;
  always @(posedge clk) begin
    if(oe0) begin
      if(pad_we0[3]) ram3[word0] <= pad_wdata0[8*3+:8];
      if(pad_we0[2]) ram2[word0] <= pad_wdata0[8*2+:8];
      if(pad_we0[1]) ram1[word0] <= pad_wdata0[8*1+:8];
      if(pad_we0[0]) ram0[word0] <= pad_wdata0[8*0+:8];
      _rdata0     <= {ram3[word0], ram2[word0], ram1[word0], ram0[word0]};
      offset0     <= addr0[1:0];
    end

    if(oe1) begin
      if(pad_we1[3]) ram3[word0] <= pad_wdata1[8*3+:8];
      if(pad_we1[2]) ram2[word0] <= pad_wdata1[8*2+:8];
      if(pad_we1[1]) ram1[word0] <= pad_wdata1[8*1+:8];
      if(pad_we1[0]) ram0[word0] <= pad_wdata1[8*0+:8];
      _rdata1     <= {ram3[word1], ram2[word1], ram1[word1], ram0[word1]};
      offset1     <= addr1[1:0];
    end

    if(!rst && (
        (we0==4'b0011 && addr0[1:0]==2'd3) ||
        (we1==4'b0011 && addr1[1:0]==2'd3) ||
        (we0==4'b1111 && addr0[1:0]!=2'd0) ||
        (we1==4'b1111 && addr1[1:0]!=2'd0))) begin
      $display("Not implemented: non-aligned r/w: %b %b %b %b",
        we0, addr0[1:0], we1, addr1[1:0]);
      $finish();
    end
  end
  assign rdata0 = _rdata0 >> ({3'h0, offset0}<<3);
  assign rdata1 = _rdata1 >> ({3'h0, offset1}<<3);

  // Initialize with dummy value or the ram may be eliminated by optimization.
  //integer i;
  //initial begin
  //  $display("%m init");
  //  for(i=0; i<2**SCALE; i=i+1) ram[i]=SCALE+i;
  //  $display("%m done");
  //end

  initial if(SCALE<3) begin $display("SCALE must be >=3"); $finish(); end
endmodule

`default_nettype wire
