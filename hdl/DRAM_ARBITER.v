`default_nettype none
`timescale 1ns/100ps
`include "UTIL.v"

module DRAM_ARBITER #(
  parameter MEM_SCALE = 27
) (
  input   wire                clk,
  input   wire                rst,

  // imem
  input   wire                ioe,
  input   wire[MEM_SCALE-1:0] iaddr,
  output  reg [       32-1:0] irdata,
  output  reg                 ivalid,
  // dmem
  input   wire[        4-1:0] doe,
  input   wire[MEM_SCALE-1:0] daddr,
  input   wire[       32-1:0] dwdata,
  input   wire[        4-1:0] dwe,
  output  reg [       32-1:0] drdata,
  output  reg                 dvalid,
  output  wire                dwritten,
  // dram
  output  reg                 dram_oe,
  output  reg [MEM_SCALE-1:0] dram_addr,
  output  reg [       32-1:0] dram_wdata,
  output  reg [        4-1:0] dram_we,
  input   wire[       32-1:0] dram_rdata,
  input   wire                dram_valid,
  input   wire                dram_written
);

  // imem
  reg                 last_ioe;
  reg [MEM_SCALE-1:0] last_iaddr;
  always @(posedge clk) if(ioe) last_iaddr  <= iaddr;
  // dmem
  reg [        4-1:0] last_doe;
  reg [        4-1:0] last_dwe;
  reg [MEM_SCALE-1:0] last_daddr;
  reg [       32-1:0] last_dwdata;
  always @(posedge clk) if(doe[0])  last_dwe    <= dwe;
  always @(posedge clk) if(doe[0])  last_daddr  <= daddr;
  always @(posedge clk) if(doe[0])  last_dwdata <= dwdata;

  localparam[1:0]     S_IDLE=2'd0, S_IMEM=2'd1, S_DMEM=2'd2;
  reg [1:0]           state=S_IDLE;
  always @(posedge clk) begin
    ivalid    <= !rst && state==S_IMEM && dram_valid;
    dvalid    <= !rst && state==S_DMEM && dram_valid;
    irdata    <= dram_rdata;
    drdata    <= dram_rdata;

    if(rst) begin
      state       <= S_IDLE;
      last_ioe    <= 1'b0;
      last_doe    <= 4'b0;
      dram_oe     <= 1'b0;
      dram_we     <= 4'b0;
      dram_addr   <= {MEM_SCALE{1'bx}};
      dram_wdata  <= 32'hxxxx;
    end else if(state==S_IDLE && last_ioe) begin
      state       <= S_IMEM;
      last_ioe    <= ioe; // basically 1'b0
      last_doe    <= last_doe | doe;
      dram_oe     <= 1'b1;
      dram_we     <= 4'b0;
      dram_addr   <= last_iaddr;
      dram_wdata  <= 32'hxxxx;
    end else if(state==S_IDLE && last_doe[0]) begin
      state       <= S_DMEM;
      last_ioe    <= last_ioe | ioe;
      last_doe    <= doe; // basically 1'b0
      dram_oe     <= 1'b1;
      dram_we     <= last_dwe;
      dram_addr   <= last_daddr;
      dram_wdata  <= last_dwdata;
    end else begin
      state       <= (dram_valid || dram_written) ? S_IDLE : state;
      last_ioe    <= last_ioe | ioe;
      last_doe    <= last_doe | doe;
      dram_oe     <= 1'b0;
      dram_we     <= 4'b0;
      dram_addr   <= {MEM_SCALE{1'bx}};
      dram_wdata  <= 32'hxxxx;
    end
  end
  assign  dwritten  = dram_written;

endmodule

`default_nettype wire
