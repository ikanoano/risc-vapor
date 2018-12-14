`default_nettype none
`timescale 1ns/100ps
`include "UTIL.v"

module BIMODAL_PREDICTOR #(
  parameter SCALE = 10
) (
  input   wire          clk,
  input   wire          rst,
  // prediction
  input   wire[32-1:0]  bp_pc,
  output  wire          bp_taken,
  input   wire          bp_oe,
  output  wire[ 2-1:0]  bp_data,  // processor memorize this
  // feedback
  input   wire[32-1:0]  fb_pc,
  input   wire          fb_taken,
  input   wire          fb_we,
  input   wire[ 2-1:0]  fb_data   // feedback bp_data
);
  localparam  WIDTH_TAG = 30-SCALE;
  (* ram_style = "block" *)
  reg [2+WIDTH_TAG-1:0] bicounter[0:2**SCALE-1];
  reg [2+WIDTH_TAG-1:0] bicounter_rdata=0;

  // prediction
  reg [32-1:0]  prev_bp_pc;
  always @(posedge clk) if(bp_oe) begin
    bicounter_rdata <= bicounter[bp_pc[2+:SCALE]];
    prev_bp_pc      <= bp_pc;
  end
  wire    bp_valid  = prev_bp_pc[2+SCALE+:WIDTH_TAG]==bicounter_rdata[2+:WIDTH_TAG];
  assign  bp_data   = bicounter_rdata[1:0];
  assign  bp_taken  = bp_data[1] && bp_valid;

  // feedback
  wire[ 2-1:0] bcincdec =
    fb_taken  && fb_data==2'b11 ? 2'b11      :
    fb_taken                    ? fb_data+1  :
    !fb_taken && fb_data==2'b00 ? 2'b00      :
    !fb_taken                   ? fb_data-1  :
                                  2'bxx;
  always @(posedge clk) if(fb_we) begin
    bicounter[fb_pc[2+:SCALE]]  <= {fb_pc[2+SCALE+:WIDTH_TAG], bcincdec};
  end
  always @(posedge clk) if(fb_we && ^bcincdec===1'bx) begin
    $display("Error: bcincdec has x: %b %b %b", bcincdec, fb_taken, fb_data);
    $finish();
  end

  integer i;
  initial begin
    for(i=0; i<2**SCALE; i=i+1) bicounter[i] = 2'b00;
  end

endmodule

`default_nettype wire
