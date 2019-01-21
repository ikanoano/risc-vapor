`default_nettype none
`timescale 1ns/100ps

// 32bitx32 2R/1W General Purpose Registers (Register File)
module GPR(
  input   wire            clk,
  input   wire            rst,

  input   wire[  5-1:0]   rs1,
  output  wire[ 32-1:0]   rrs1,
  input   wire[  5-1:0]   rs2,
  output  wire[ 32-1:0]   rrs2,

  input   wire[  5-1:0]   rd,
  input   wire[ 32-1:0]   rrd,
  input   wire            we  // write enable
);

reg [31:0]  r[0:31];

assign rrs1 = rs1==rd && we ? rrd : r[rs1];
assign rrs2 = rs2==rd && we ? rrd : r[rs2];

always @(posedge clk) begin
  if(we) r[rd] <= rrd;
  if(we&&rd==0) begin $display("bug: must deassert we if rd==0"); $finish(); end
end

integer i;
initial for(i=0; i<32; i=i+1) r[i]=0;

endmodule

`default_nettype wire
