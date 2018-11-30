`default_nettype none
`timescale 1ns/100ps
// Clock Interval Definition
// b = baud rate (in Mbps)
// f = frequency of the clk for the MIPS core (in MHz)
// SERIAL_WCNT = f/b
// e.g. b = 1, f = 50 -> SERIAL_WCNT = 50/1 = 50

module UARTTX #(
  parameter SERIAL_WCNT = 50
) (CLK, RST_X, DATA, WE, TXD, READY);
    input       CLK, RST_X, WE;
    input [7:0] DATA;
    output reg  TXD, READY;

    reg [8:0]   cmd;
    reg [11:0]  waitnum;
    reg [3:0]   cnt;

    always @(posedge CLK) begin
        if(!RST_X) begin
            TXD       <= 1'b1;
            READY     <= 1'b1;
            cmd       <= 9'h1ff;
            waitnum   <= 0;
            cnt       <= 0;
        end else if( READY ) begin
            TXD       <= 1'b1;
            waitnum   <= 0;
            if( WE )begin
                READY <= 1'b0;
                cmd   <= {DATA, 1'b0};
                cnt   <= 10;
            end
        end else if( waitnum >= SERIAL_WCNT ) begin
            TXD       <= cmd[0];
            READY     <= (cnt == 1);
            cmd       <= {1'b1, cmd[8:1]};
            waitnum   <= 1;
            cnt       <= cnt - 1;
        end else begin
            waitnum   <= waitnum + 1;
        end
    end
endmodule

/******************************************************************************************************/
/* RS232C serial controller (deserializer):                                                           */
/******************************************************************************************************/
`define SS_SER_WAIT  'd0         // RS232C deserializer, State WAIT
`define SS_SER_RCV0  'd1         // RS232C deserializer, State Receive 0th bit
                                 // States Receive 1st bit to 7th bit are not used
`define SS_SER_DONE  'd9         // RS232C deserializer, State DONE
/******************************************************************************************************/
module UARTRX #(
  parameter SERIAL_WCNT = 50
) (CLK, RST_X, RXD, DATA, EN);
    input          CLK, RST_X, RXD; // clock, reset, RS232C input
    output [7:0]   DATA;            // 8bit output data
    output reg     EN;              // 8bit output data enable

    reg    [7:0]   DATA;
    reg    [3:0]   stage;
    reg    [12:0]  cnt;             // counter to latch D0, D1, ..., D7
    reg    [11:0]  cnt_start;       // counter to detect the Start Bit
    wire   [12:0]  waitcnt;

    assign waitcnt = SERIAL_WCNT;

    always @(posedge CLK)
      if (!RST_X) cnt_start <= 0;
      else        cnt_start <= (RXD) ? 0 : cnt_start + 1;

    always @(posedge CLK)
      if(!RST_X) begin
          EN     <= 0;
          stage  <= `SS_SER_WAIT;
          cnt    <= 1;
          DATA   <= 0;
      end else if (stage == `SS_SER_WAIT) begin // detect the Start Bit
          EN <= 0;
          stage <= (cnt_start == (waitcnt >> 1)) ? `SS_SER_RCV0 : stage;
      end else begin
          if (cnt != waitcnt) begin
              cnt <= cnt + 1;
              EN <= 0;
          end else begin               // receive 1bit data
              stage  <= (stage == `SS_SER_DONE) ? `SS_SER_WAIT : stage + 1;
              EN     <= (stage == 8)  ? 1 : 0;
              DATA   <= {RXD, DATA[7:1]};
              cnt <= 1;
          end
      end
endmodule

