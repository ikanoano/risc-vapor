`default_nettype none
`timescale 1ns/100ps
`include "CONSTS.v"

module MMIO #(
  parameter MEM_SCALE   = 27,
  parameter CPU_FREQ    = 100000000,
  parameter BAUDRATE    = 1000000
) (
  input   wire                clk,
  input   wire                rst,

  input   wire[        4-1:0] oe,
  input   wire[MEM_SCALE-1:0] addr,
  input   wire[       32-1:0] wdata,
  input   wire[        4-1:0] we,
  output  reg [       32-1:0] rdata,
  output  reg                 valid,

  input   wire[        5-1:0] btn,  // {down, right, left, up, center}
  input   wire[       16-1:0] sw,
  input   wire[       32-1:0] bp_cnt_hit, bp_cnt_pred,
  input   wire[       32-1:0] dc_cnt_hit, dc_cnt_access,

  output  reg                 halt,
  output  reg [       16-1:0] led,
  output  reg [       32-1:0] seg7,

  output  wire[        8-1:0] rx_rdata,
  output  wire                rx_valid
);

  wire[32-1:0]  rnd;
  reg [ 8-1:0]  tx_wdata;
  reg           tx_we, tx_ready;
  reg [ 8-1:0]  rx_rdata_hold;
  reg           unread=1'b0;
  always @(posedge clk) begin
    // write
    if(rst) begin
      {unread, halt, led, seg7} <= 0;
    end else if(oe[0] && we[0]) begin
      case (addr[0+:16])
        `MMIO_HALT      : halt      <= 1'b1;
        `MMIO_TO_HOST   : tx_wdata  <= wdata[0+:8];
        `MMIO_FROM_HOST : unread    <= 1'b0;  // "I've read the rx_rdata."
        `MMIO_LED       : led       <= wdata[0+:16];
        `MMIO_SEG7      : seg7      <= wdata;
      endcase
    end else begin
      unread <= unread | rx_valid;
    end
    tx_we <= oe[0] && we[0] && addr[0+:16]==`MMIO_TO_HOST;// assert for only 1 cycle

    // read
    if(oe[0] && !we[0]) begin
      valid  <= 1'b1;
      case (addr[0+:16])
        // return non zero when TX is available
        `MMIO_TO_HOST   : rdata <= {31'h0, tx_ready};
        `MMIO_FROM_HOST : rdata <= {~unread, 23'h0, rx_rdata_hold};
        `MMIO_BTN       : rdata <= {27'h0, btn};
        `MMIO_SW        : rdata <= {16'h0, sw};
        `MMIO_LFSR      : rdata <= {rnd};
        `MMIO_CPU_FREQ  : rdata <= CPU_FREQ;
        `MMIO_BP_HIT    : rdata <= {bp_cnt_hit};
        `MMIO_BP_PRED   : rdata <= {bp_cnt_pred};
        `MMIO_DC_HIT    : rdata <= {dc_cnt_hit};
        `MMIO_DC_ACCESS : rdata <= {dc_cnt_access};
        default         : rdata <= {32'h0};
      endcase
    end else begin
      valid  <= 1'b0;
    end
  end

  // random
  LFSR lfsr(clk, rnd);

  // uart tx
  UARTTX #(.SERIAL_WCNT(CPU_FREQ/BAUDRATE)) utx (
    .CLK(clk),
    .RST_X(~rst),
    .DATA(tx_wdata),
    .WE(tx_we),
    .TXD(uart_txd),
    .READY(tx_ready)
  );

  // uart rx
  UARTRX #(.SERIAL_WCNT(CPU_FREQ/BAUDRATE)) urx (
    .CLK(clk),
    .RST_X(~rst),
    .RXD(uart_rxd),
    .DATA(rx_rdata),
    .VALID(rx_valid)
  );
  always @(posedge clk) if(rx_valid) rx_rdata_hold <= rx_rdata;

  initial halt = 1'b0;

endmodule

`default_nettype wire
