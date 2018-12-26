`default_nettype none
`timescale 1ns/100ps

module M_7SEGCON (
  input   wire          clk,
  input   wire[32-1:0]  din,
  output  reg [   7:0]  cs,   // cathode segments
  output  reg [   7:0]  an    // common anode
);
  localparam  DELAY7SEG = 17; // 18 for 100MHz, 17 for 50MHz

  reg [DELAY7SEG-1:0] cnt=0;
  reg         [4-1:0] din4=0;
  reg         [3-1:0] digit = 0;

  always@(posedge clk) begin
    cnt <= cnt + 1;
    if(cnt==0) begin
      digit <= digit + 1;
      an    <= ~(8'b1 << digit);
      din4  <= din[4*digit +: 4];
    end
  end
  wire [7:0] w_segments =
    din4==4'h0  ? 8'b00111111 :
    din4==4'h1  ? 8'b00000110 :
    din4==4'h2  ? 8'b01011011 :
    din4==4'h3  ? 8'b01001111 :
    din4==4'h4  ? 8'b01100110 :
    din4==4'h5  ? 8'b01101101 :
    din4==4'h6  ? 8'b01111101 :
    din4==4'h7  ? 8'b00000111 :
    din4==4'h8  ? 8'b01111111 :
    din4==4'h9  ? 8'b01101111 :
    din4==4'ha  ? 8'b01110111 :
    din4==4'hb  ? 8'b01111100 :
    din4==4'hc  ? 8'b00111001 :
    din4==4'hd  ? 8'b01011110 :
    din4==4'he  ? 8'b01111001 :
                  8'b01110001;
  always@(posedge clk) cs <= ~w_segments;
endmodule

`default_nettype wire
