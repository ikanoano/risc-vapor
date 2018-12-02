`default_nettype none
`timescale 1ps/1ps

module IBUF (
  output  wire  O,
  input   wire  I
);
  assign  O = I;
endmodule

module GENCLK_CPU (
  input   wire      clk_in,
  input   wire      reset,
  output  wire      clk_out,
  output  wire      locked
);
  assign  clk_out = clk_in;
  assign  locked  = ~reset;
endmodule

module GENCLK_REF (
  input   wire      clk_in,
  input   wire      reset,
  output  wire      clk_out,
  output  wire      locked
);
  assign  clk_out = clk_in;
  assign  locked  = ~reset;
endmodule

module DRAM (
  input   wire          clk,
  input   wire          rst_mig,
  input   wire          clk_mig_200,

  output  wire          calib_done,
  output  wire          locked_mig,

  input   wire          dram_oe,
  input   wire[32-1:0]  dram_addr,
  input   wire[32-1:0]  dram_wdata,
  input   wire[ 4-1:0]  dram_we,
  output  reg [32-1:0]  dram_rdata,
  output  reg           dram_valid,
  output  wire          dram_busy,

  output  wire[13-1:0]  ddr2_addr,
  output  wire[2:0]     ddr2_ba,
  output  wire          ddr2_cas_n,
  output  wire[0:0]     ddr2_ck_n,
  output  wire[0:0]     ddr2_ck_p,
  output  wire[0:0]     ddr2_cke,
  output  wire[0:0]     ddr2_cs_n,
  output  wire[1:0]     ddr2_dm,
  inout   wire[16-1:0]  ddr2_dq,
  inout   wire[1:0]     ddr2_dqs_n,
  inout   wire[1:0]     ddr2_dqs_p,
  output  wire[0:0]     ddr2_odt,
  output  wire          ddr2_ras_n,
  output  wire          ddr2_we_n
);
  assign  calib_done  = 1'b1;
  assign  locked_mig  = 1'b1;

  wire[32-1:0]  _dram_rdata;
  RAM #(.SCALE(27)) dram (
    .clk(clk),
    .rst(rst_mig),

    .oe0(dram_oe),
    .addr0(dram_addr[0+:27]),
    .wdata0(dram_wdata),
    .we0(dram_we),
    .rdata0(_dram_rdata),

    .oe1(1'b0),
    .addr1(27'h0),
    .wdata1(32'h0),
    .we1(4'b0),
    .rdata1()
  );
  reg           dram_reading=1'b0;
  reg           dram_writing=1'b0;
  reg [32-1:0]  dram_rdata_hold;
  always @(posedge clk) begin
    dram_writing    <= dram_we;
    dram_reading    <= dram_oe && !dram_we;
    dram_valid      <= dram_reading;
    dram_rdata      <= _dram_rdata;
  end
  assign  dram_busy = dram_reading | dram_writing;
endmodule


`default_nettype wire
