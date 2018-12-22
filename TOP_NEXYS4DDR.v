`default_nettype none
`timescale 1ns/100ps

module TOP_NEXYS4DDR (
  input   wire          clk100mhz,
  input   wire          cpu_resetn,
  input   wire[ 5-1:0]  btn,  // {down, right, left, up, center}
  input   wire[16-1:0]  sw,
  output  reg [16-1:0]  led,
  output  wire[6:0]     cs,   // 7-seg cathode segments
  output  wire[7:0]     an,   // 7-seg common anode
  input   wire          uart_rxd,
  output  wire          uart_txd,
  inout   wire[15:0]    ddr2_dq,
  inout   wire[1:0]     ddr2_dqs_n,
  inout   wire[1:0]     ddr2_dqs_p,
  output  wire[12:0]    ddr2_addr,
  output  wire[2:0]     ddr2_ba,
  output  wire          ddr2_ras_n,
  output  wire          ddr2_cas_n,
  output  wire          ddr2_we_n,
  output  wire          ddr2_ck_p,
  output  wire          ddr2_ck_n,
  output  wire          ddr2_cke,
  output  wire          ddr2_cs_n,
  output  wire [1:0]    ddr2_dm,
  output  wire          ddr2_odt
);
localparam  CPU_FREQ  = 120000000;
localparam  DOWN=4, RIGHT=3, LEFT=2, UP=1, CENTER=0;

// clocking
wire  clk100mhz_buf;
IBUF bufclk100 (.O (clk100mhz_buf), .I (clk100mhz));

wire  clk, clk_mig_200, locked, locked_ref, locked_mig, calib_done;
GENCLK_CPU  genclkc (
  .clk_in(clk100mhz_buf),
  .reset(~cpu_resetn),
  .clk_out(clk),
  .locked(locked)
);
GENCLK_REF  genclkr (
  .clk_in(clk100mhz_buf),
  .reset(~cpu_resetn),
  .clk_out(clk_mig_200),
  .locked(locked_ref)
);

// synchronize reset
wire      rst_async = ~locked | ~locked_mig | ~locked_ref |
                      ~cpu_resetn | ~calib_done;
reg [1:0] rst_sync=2'b00;
reg       rst=1'b0;
always @(posedge clk or posedge rst_async) begin
  if(rst_async) rst_sync <= 2'b11;
  else          rst_sync <= {rst_sync[0], 1'b0};
end
always @(posedge clk) rst <= rst_sync[1];

// processor
wire[16-1:0]  imem_addr;
wire          imem_oe;
wire[32-1:0]  imem_rdata;
reg           imem_valid=0;

wire[32-1:0]  mem_addr;
wire[ 4-1:0]  mem_oe;
wire[32-1:0]  mem_wdata;
wire[ 4-1:0]  mem_we;
reg [32-1:0]  mem_rdata=0;
reg           mem_valid=1'b0;
wire          mem_ready;

wire[32-1:0]  cycle;
PROCESSOR p (
  .clk(clk),
  .rst(rst),

  .imem_addr(imem_addr),
  .imem_oe(imem_oe),
  .imem_rdata(imem_rdata),
  .imem_valid(imem_valid),

  .mem_addr(mem_addr),
  .mem_oe(mem_oe),
  .mem_wdata(mem_wdata),
  .mem_we(mem_we),
  .mem_rdata(mem_rdata),
  .mem_valid(mem_valid),
  .mem_ready(mem_ready),

  .cycle(cycle)
);

reg [32-1:0]  prev_mem_addr;
reg           prev_mem_oe;
reg [32-1:0]  prev_mem_wdata;
reg [ 4-1:0]  prev_mem_we;
always @(posedge clk) prev_mem_addr  <= mem_addr;
always @(posedge clk) prev_mem_oe    <= mem_oe;
always @(posedge clk) prev_mem_wdata <= mem_wdata;
always @(posedge clk) prev_mem_we    <= mem_we;

// program loader
wire[32-1:0]  init_waddr, init_wdata;
wire          init_we,    init_done;
PLOADER pl (
  .CLK(clk),
  .RST_X(~rst),
  .RXD(uart_rxd),
  .ADDR(init_waddr),
  .DATA(init_wdata),
  .WE(init_we),
  .DONE(init_done)
);

// uart tx
localparam  BAUDRATE  = 1000000;
reg [ 8-1:0]  tx_wdata;
reg           tx_we;
wire          tx_ready;
UARTTX #(
  .SERIAL_WCNT(CPU_FREQ/BAUDRATE)
) ut (
  .CLK(clk),
  .RST_X(~rst),
  .DATA(tx_wdata),
  .WE(tx_we),
  .TXD(uart_txd),
  .READY(tx_ready)
);

// instruction memory
RAM #(.SCALE(16)) imem (
  .clk(clk),
  .rst(rst),

  .oe0(imem_oe | init_we),
  .addr0({init_done ? imem_addr[2+:14] : init_waddr[2+:14], 2'b00}),
  .rdata0(imem_rdata),
  .wdata0(init_wdata),
  .we0({4{init_we && init_waddr<32'h00010000}}),

  .oe1(1'b0),
  .addr1(16'h0),
  .rdata1(),
  .wdata1(32'h0),
  .we1(4'b0)
);
always @(posedge clk) imem_valid <= imem_oe;  // never misses

// memory mapped IO
wire          mmio_oe = mem_oe[0] && mem_addr[28+:4]==4'hf;
wire[ 4-1:0]  mmio_we = {4{mmio_oe}} & mem_we;
reg [32-1:0]  mmio_rdata = 0;
reg           mmio_valid = 1'b0;
always @(posedge clk) begin
  // write halt
  if(mmio_we[0] && mem_addr[0+:16]==16'h0000) begin /* to be implemented */ end
  // write to_host
  if(mmio_we[0] && mem_addr[0+:16]==16'h0100) begin
    tx_wdata  <= mem_wdata[0+:8];
    tx_we     <= 1'b1;
  end else begin
    tx_we     <= 1'b0;
  end
  // read
  if(mmio_oe && !mmio_we[0]) begin
    case (mem_addr[0+:16])
      // return non zero when TX is available
      16'h0100: begin mmio_valid <= 1'b1; mmio_rdata <= {31'h0, tx_ready}; end
      default : begin mmio_valid <= 1'b1; mmio_rdata <= 32'h0; end
    endcase
  end else begin
    mmio_valid  <= 1'b0;
  end
end

// data memory
wire[ 4-1:0]  dmem_oe = mem_addr<32'h08000000 ? mem_oe : 4'h0;
wire[ 4-1:0]  dmem_we = dmem_oe & mem_we;
reg [ 4-1:0]  prev_dmem_oe;
reg [ 4-1:0]  prev_dmem_we;
always @(posedge clk) prev_dmem_oe  <= dmem_oe;
always @(posedge clk) prev_dmem_we  <= dmem_we;

wire          dcache_hit;
wire          dcache_miss = prev_dmem_oe[0] && !dcache_hit;
wire[32-1:0]  dcache_rdata;
wire          dcache_busy = prev_dmem_oe[0];

wire          dram_oe     = init_we | prev_dmem_we[0] | dcache_miss;
wire[32-1:0]  dram_addr   = init_done ? prev_mem_addr  : init_waddr;
wire[32-1:0]  dram_wdata  = init_done ? prev_mem_wdata : init_wdata;
wire[ 4-1:0]  dram_we     = {4{init_we}} | prev_dmem_we;
wire[32-1:0]  dram_rdata;
wire          dram_valid;
wire          dram_busy;

// data cache
reg [32-1:0]  last_dram_addr=0;
reg [ 4-1:0]  last_dram_we  =4'h0;
always @(posedge clk) if(dram_oe) last_dram_addr <= dram_addr;
always @(posedge clk) if(dram_oe) last_dram_we   <= dram_we;
DCACHE #(
  .MEM_SCALE(27),
  .SCALE(10)
) dc (
  .clk(clk),
  .rst(rst),

  .oe(dmem_oe),
  .addr(mem_addr[0+:27]),
  .wdata(mem_wdata),
  .we(dmem_we),
  .rdata(dcache_rdata),
  .hit(dcache_hit),

  .load_oe(dram_valid),
  .load_addr(last_dram_addr[0+:27]),
  .load_wdata(dram_rdata),
  .load_we({4{dram_valid}} & last_dram_we)
);

// dram: read/write after 1 cycle from dmem_oe/dmem_we assertion
//  read *ONLY IF* dcache miss occured
//  write always
DRAM dram (
  .clk(clk),
  .rst_mig(rst),
  .clk_mig_200(clk_mig_200),

  .calib_done(calib_done),
  .locked_mig(locked_mig),

  .dram_oe(dram_oe),
  .dram_addr(dram_addr),
  .dram_wdata(dram_wdata),
  .dram_we(dram_we),
  .dram_rdata(dram_rdata),
  .dram_valid(dram_valid),
  .dram_busy(dram_busy),

  .ddr2_addr(ddr2_addr),
  .ddr2_ba(ddr2_ba),
  .ddr2_cas_n(ddr2_cas_n),
  .ddr2_ck_n(ddr2_ck_n),
  .ddr2_ck_p(ddr2_ck_p),
  .ddr2_cke(ddr2_cke),
  .ddr2_cs_n(ddr2_cs_n),
  .ddr2_dm(ddr2_dm),
  .ddr2_dq(ddr2_dq),
  .ddr2_dqs_n(ddr2_dqs_n),
  .ddr2_dqs_p(ddr2_dqs_p),
  .ddr2_odt(ddr2_odt),
  .ddr2_ras_n(ddr2_ras_n),
  .ddr2_we_n(ddr2_we_n)
);

always @(posedge clk) begin
  mem_valid <= mmio_valid | dcache_hit | dram_valid;
  mem_rdata <=
  mmio_valid  ? mmio_rdata    :
  dcache_hit  ? dcache_rdata  :
  dram_valid  ? dram_rdata    :
                32'hxxxxxxxx;
end
assign  mem_ready = ~dram_busy && ~dcache_busy && ~mem_oe[0];

// LEDs
wire[31:0] disp = (btn[UP]) ? cycle : mem_addr;
M_7SEGCON m_7seg(clk, disp, cs, an);

endmodule

`default_nettype wire
