`default_nettype none
`timescale 1ns/100ps

module ICACHE #(
  parameter MEM_SCALE = 27,
  parameter SCALE     = 10  // 2**SCALE WORD is allocated
) (
  input   wire                clk,
  input   wire                rst,
  // read from processor
  input   wire                oe,
  input   wire[MEM_SCALE-1:0] addr,
  output  wire[32-1:0]        rdata,
  output  wire                valid,
  // load data from dram
  output  wire                super_oe,
  output  wire[MEM_SCALE-1:0] super_addr,
  input   wire[32-1:0]        super_rdata,
  input   wire                super_valid,
  // clear
  input   wire                clear,
  // stat
  output  reg [32-1:0]        ic_cnt_hit,
  output  reg [32-1:0]        ic_cnt_access
);
  localparam WIDTH_TAG = MEM_SCALE-SCALE;

  reg                 prev_oe;
  reg [MEM_SCALE-1:0] last_addr=0;
  always @(posedge clk) prev_oe <= oe;
  always @(posedge clk) if(oe) last_addr <= addr;

  reg [SCALE-1:0]  clear_addr=0;
  always @(posedge clk) if(clear) clear_addr <= clear_addr + 1;

  reg           reading=1'b0;
  always @(posedge clk) reading <=
    rst       ? 1'b0 :
    oe        ? 1'b1 :
    valid     ? 1'b0 :
                reading;

  //                  valid    tag      inst
  localparam  ICWIDTH = 1 + WIDTH_TAG + 32;
  wire                ic_valid;
  wire[WIDTH_TAG-1:0] ic_tag;
  wire[32-1:0]        ic_inst;
  BARERAM #(
    .SCALE(SCALE),
    .WIDTH(ICWIDTH),
    .INIT (1)
  ) icache (
    .clk(clk),
    .rst(rst),

    .oe0(1'b1),
    .addr0(oe ? addr[0+:SCALE] : last_addr[0+:SCALE]),
    .wdata0({ICWIDTH{1'b0}}),
    .we0(1'b0),
    .rdata0({ic_valid, ic_tag, ic_inst}),

    .oe1(super_valid || clear),
    .addr1(clear ? clear_addr : last_addr[0+:SCALE]),
    .wdata1({~clear, TAG(last_addr), super_rdata}),
    .we1(super_valid || clear),
    .rdata1()
  );

  assign  rdata   = ic_inst;
  assign  valid   = ic_valid && reading && (ic_tag == TAG(last_addr));

  reg     loading=1'b0;
  always @(posedge clk) loading <=
    rst         ? 1'b0 :
    super_oe    ? 1'b1 :
    super_valid ? 1'b0 :
                  loading;
  assign  super_addr  = last_addr;
  assign  super_oe    = prev_oe && !valid && !loading;

  // stat
  always @(posedge clk) begin
    ic_cnt_hit    <= rst ? 32'b0 : ic_cnt_hit    + (prev_oe&valid);
    ic_cnt_access <= rst ? 32'b0 : ic_cnt_access + oe;
  end

  function[WIDTH_TAG-1:0]  TAG(input[MEM_SCALE-1:0] a);
    TAG = a[SCALE +: WIDTH_TAG];
  endfunction
endmodule

`default_nettype wire
