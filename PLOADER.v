`default_nettype none
`timescale 1ns/100ps
/******************************************************************************************************/
/* Program Loader: Initialize the main memory, copy memory image to the main memory                   */
/******************************************************************************************************/
module PLOADER #(
  parameter SERIAL_WCNT = 50,
  parameter PROG_SIZE   = 512*1024
) (
  input   wire        CLK, RST_X, RXD,
  output  reg [31:0]  ADDR,
  output  reg [31:0]  DATA,
  output  reg         WE,
  output  reg         DONE  // program load is done
);

    reg [31:0] waddr; // memory write address

    wire SER_EN;
    wire [7:0] SER_DATA;
    UARTRX #(.SERIAL_WCNT(SERIAL_WCNT)) serc (
      CLK, RST_X, RXD, SER_DATA, SER_EN
    );

    always @(posedge CLK) begin
        if(!RST_X) begin
            {ADDR, DATA, WE, waddr, DONE} <= 0;
        end else begin
            if(DONE==0 && SER_EN) begin
                ADDR  <= waddr & ~32'h3;
                //ADDR  <= (waddr<32'h40000) ? waddr : {8'h04, 6'd0, waddr[17:0]};
                DATA  <= {SER_DATA, DATA[31:8]};
                WE    <= (waddr[1:0]==3);
                waddr <= waddr + 1;
            end else begin
                WE <= 0;
                if(waddr>=PROG_SIZE) DONE <= 1;
            end
        end
    end
endmodule

`default_nettype wire
