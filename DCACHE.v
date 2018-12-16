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
  output  reg                 hit,
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

  wire[WIDTH_TAG-1:0] tag;
  wire[        4-1:0] valid;
  assign {valid, tag} = valid_and_tag[addr[2+:SCALE-2]];

  wire[WIDTH_TAG-1:0] utag    = addr[SCALE+:WIDTH_TAG];
  wire[        4-1:0] uvalid  =
    tag==utag   ? (we<<addr[1:0]) | valid :
                  (we<<addr[1:0]);

  wire[WIDTH_TAG-1:0] ltag    = load_addr[SCALE+:WIDTH_TAG];
  wire[        4-1:0] lvalid  = load_we<<load_addr[1:0];

  always @(posedge clk) if(we[0]) begin
    valid_and_tag[     addr[2+:SCALE-2]] <= {uvalid, utag};
  end
  always @(posedge clk) if(load_we[0]) begin
    valid_and_tag[load_addr[2+:SCALE-2]] <= {lvalid, ltag};
  end

  always @(posedge clk) hit <=
    oe[0] &&
    tag==utag &&
    ((oe<<addr[1:0])&valid)==valid;

  always @(posedge clk) begin
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
