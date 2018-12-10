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
  output  reg [ 2-1:0]  bp_data,  // processor memorize this
  // feedback
  input   wire[32-1:0]  fb_pc,
  input   wire          fb_taken,
  input   wire          fb_we,
  input   wire[ 2-1:0]  fb_data   // feedback bp_data
);
  (* ram_style = "block" *)
  reg [ 2-1:0] bicounter[0:2**SCALE-1];

  // prediction
  always @(posedge clk) bp_data <= bicounter[bp_pc[2+:SCALE]];
  assign  bp_taken  = bp_data[1];

  // feedback
  wire[ 2-1:0] bcincdec =
    fb_taken  && fb_data==2'b11 ? 2'b11      :
    fb_taken                    ? fb_data+1  :
    !fb_taken && fb_data==2'b00 ? 2'b00      :
    !fb_taken                   ? fb_data-1  :
                                  2'bxx;
  always @(posedge clk) if(fb_we) bicounter[fb_pc[2+:SCALE]]  <= bcincdec;
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
