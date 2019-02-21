`default_nettype none
`timescale 1ns/100ps
`include "UTIL.v"

module DCACHE #(
  parameter MEM_SCALE = 27,
  parameter SCALE     = 10  // 2**SCALE BYTE is allocated
) (
  input   wire                clk,
  input   wire                rst,
  // r/w from processor
  input   wire[        4-1:0] oe,
  input   wire[MEM_SCALE-1:0] addr,
  input   wire[       32-1:0] wdata,
  input   wire[        4-1:0] we,
  output  wire[       32-1:0] rdata,
  output  wire                valid,
  output  wire                busy,
  // load data from dram
  output  wire                super_oe,     // request to load 4byte / write
  output  wire[MEM_SCALE-1:0] super_addr,
  output  wire[       32-1:0] super_wdata,
  output  wire[        4-1:0] super_we,
  input   wire[       32-1:0] super_rdata,
  input   wire                super_valid,
  input   wire                super_written,
  // clear
  input   wire                clear,
  // stat
  output  reg [32-1:0]        dc_cnt_hit,
  output  reg [32-1:0]        dc_cnt_access
);
  localparam WIDTH_TAG = MEM_SCALE-SCALE;

  reg [        4-1:0] prev_oe=4'h0;
  reg [        4-1:0] prev_we=4'h0;
  reg [        4-1:0] last_oe=4'h0;
  reg [MEM_SCALE-1:0] last_addr=0;
  reg [       32-1:0] last_wdata=0;
  always @(posedge clk) prev_oe <= rst ? 4'h0 : oe;
  always @(posedge clk) prev_we <= rst ? 4'h0 : oe & we;

  always @(posedge clk) if(oe[0]) last_oe     <= oe;
  always @(posedge clk) if(oe[0]) last_addr   <= addr;
  always @(posedge clk) if(oe[0] & we[0]) last_wdata  <= wdata;

  reg [SCALE-2-1:0]   clear_addr=0;
  always @(posedge clk) if(clear) clear_addr <= clear_addr + 1;

  reg     reading=1'b0;
  always @(posedge clk) reading <=
    rst             ? 1'b0 :
    oe[0] && !we[0] ? 1'b1 :
    valid           ? 1'b0 :
                      reading;
  wire    written;
  reg     writing=1'b0;
  always @(posedge clk) writing <=
    rst             ? 1'b0 :
    oe[0] && we[0]  ? 1'b1 :
    written         ? 1'b0 :
                      writing;
  assign  busy  = reading || writing || oe[0];

  RAM #(
    .SCALE(SCALE)
  ) dcache (
    .clk(clk),
    .rst(rst),

    .oe0(oe[0] || reading),
    .addr0(oe[0] ? addr[0+:SCALE] : last_addr[0+:SCALE]),
    .wdata0(wdata),
    .we0(we),
    .rdata0(rdata),

    .oe1(super_valid),
    .addr1(super_addr[0+:SCALE]),
    .wdata1(super_rdata),
    .we1({4{super_valid}}),
    .rdata1()
  );

  // valid and tag array with byte granularity
  wire[        4-1:0] rvalid;
  wire[WIDTH_TAG-1:0] rtag, wtag;
  reg [MEM_SCALE-1:0] vta_waddr=0;
  reg [        4-1:0] wvalid_add=0;
  wire[        4-1:0] wvalid_org, wvalid;
  BARERAM #(
    .WIDTH(4+WIDTH_TAG),
    .SCALE(SCALE-2), // 2**SCALE word is allocated
    .INIT (1)
  ) vta (
    .clk(clk),
    .rst(rst),

    .oe0(1'b1),
    .addr0(oe[0] ? addr[2+:SCALE-2] : last_addr[2+:SCALE-2]),
    .wdata0(),
    .we0(1'b0),
    .rdata0({rvalid, rtag}),

    .oe1(|wvalid_add || clear),
    .addr1(clear ? clear_addr : vta_waddr[2+:SCALE-2]),
    .wdata1({clear ? 4'h0 : wvalid, wtag}),
    .we1(|wvalid_add || clear),
    .rdata1()
  );

  // Confirm that the cache was hit, then load data if necessary.
  // valid is eventually asserted when not hit but load is completed.
  wire[4-1:0] hvalid = last_oe << last_addr[1:0];
  assign  valid = (hvalid&rvalid)==hvalid && TAG(last_addr)==rtag && reading;
  reg     loading=1'b0;
  always @(posedge clk) loading <=
    rst                       ? 1'b0 :
    super_oe && !super_we[0]  ? 1'b1 :
    super_valid               ? 1'b0 :
                              loading;

  // load and write through
  //                                  load                 ||  write
  assign  super_oe    = (prev_oe[0] && !valid && !loading) || |prev_we;
  assign  super_addr  = // To load 4byte, mask 2bit LSB if load.
    {last_addr[2+:MEM_SCALE-2], prev_we[0] ? last_addr[0+:2] : 2'b00};
  assign  super_wdata = last_wdata;
  assign  super_we    = prev_oe & prev_we;
  assign  written     = super_written;

  // Update vta[addr] when we is asserted.
  // Overwrite vta[super_addr] when super_valid is asserted.
  // It is guaranteed that we and super_addr are not asserted at the same time.
  always @(posedge clk) vta_waddr   <= oe[0]&&we[0] ? addr : super_addr;
  always @(posedge clk) wvalid_add  <= ((oe&we)<<addr[1:0]) | {4{super_valid}};
  assign  wtag        = TAG(vta_waddr);
  assign  wvalid_org  = (prev_we[0] && rtag==wtag) ? rvalid : 4'h0;
  assign  wvalid      = wvalid_org | wvalid_add;

  // stat
  always @(posedge clk) begin
    dc_cnt_hit    <= rst ? 32'b0 : dc_cnt_hit +    (prev_oe[0]&&!prev_we[0]&&valid);
    dc_cnt_access <= rst ? 32'b0 : dc_cnt_access + (prev_oe[0]&&!prev_we[0]);
  end

  always @(posedge clk) begin
    if(super_valid && (oe[0]&&we[0])) begin
      $display("super_valid and we must not be asserted at the same time: %b %b",
        super_valid, we);
      $finish();
    end
    if((oe[0]&&we[0]) && ({2'd0, we}<<addr[1:0])>=16) begin
      $display("Missaligned update not supported: %b %x", we, addr);
      $finish();
    end
  end

  function[WIDTH_TAG-1:0]  TAG(input[MEM_SCALE-1:0] a);
    TAG = a[SCALE +: WIDTH_TAG];
  endfunction
endmodule

`default_nettype wire
