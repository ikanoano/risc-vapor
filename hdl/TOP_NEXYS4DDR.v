`default_nettype none
`timescale 1ns/100ps

module TOP_NEXYS4DDR (
  input   wire          clk100mhz,
  input   wire          cpu_resetn,
  input   wire[ 5-1:0]  btn,  // {down, right, left, up, center}
  input   wire[16-1:0]  sw,
  output  wire[16-1:0]  led,
  output  wire[3-1:0]   rgbled0,
  output  wire[3-1:0]   rgbled1,
  output  wire[7:0]     cs,   // 7-seg cathode segments
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
  localparam  integer MEM_SCALE       = 27;
  // Params for detemining frequency - Refer the summary tab in clocking wizard
  localparam  integer DIVIDE_COUNTER  = 1;  //5;
  localparam  real    MULT_COUNTER    = 10; //50.250;
  localparam  real    DEVIDER_VALUE1  = 10; //8.375;
  localparam  real    CPU_FREQ_F= 100000000.0/DIVIDE_COUNTER*MULT_COUNTER/DEVIDER_VALUE1;
  localparam  integer CPU_FREQ  = CPU_FREQ_F;

  localparam  DOWN=4, RIGHT=3, LEFT=2, UP=1, CENTER=0;

  // clocking
  wire  clk100mhz_buf;
  IBUF bufclk100 (.O (clk100mhz_buf), .I (clk100mhz));

  wire  clk, clk_mig_200, locked, locked_ref, locked_mig, calib_done;
  GENCLK_CPU #(
    .DIVIDE_COUNTER(DIVIDE_COUNTER),
    .MULT_COUNTER(MULT_COUNTER),
    .DEVIDER_VALUE1(DEVIDER_VALUE1)
  ) genclkc (
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

  reg [32-1:0]  clkcnt=32'b0;
  reg           clk1hz=1'b0;
  always @(posedge clk) clkcnt  <= clkcnt<CPU_FREQ-1 ? clkcnt+1 : 0;
  always @(posedge clk) clk1hz  <= clkcnt<CPU_FREQ/2;

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
  wire[32-1:0]  imem_addr;
  wire          imem_oe;
  wire[32-1:0]  imem_rdata;
  wire          imem_valid;

  wire[32-1:0]  mem_addr;
  wire[ 4-1:0]  mem_oe, mem_we;
  wire[32-1:0]  mem_wdata;
  reg [32-1:0]  mem_rdata=0;
  reg           mem_valid=1'b0;
  wire          dmem_busy;

  wire[32-1:0]  pc;
  wire[64-1:0]  cycle;
  wire          init_done;

  wire          halt;
  reg           rst_proc=1'b0;
  wire[32-1:0]  bp_cnt_hit, bp_cnt_pred;
  wire[32-1:0]  dc_cnt_hit, dc_cnt_access;
  wire[32-1:0]  ic_cnt_hit, ic_cnt_access;
  always @(posedge clk) rst_proc <= rst || !init_done;
  PROCESSOR p (
    .clk(clk),
    .rst(rst_proc),
    .halt(halt),

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
    .mem_ready(~dmem_busy),

    .cycle(cycle),
    .pc_disp(pc),
    .bp_cnt_hit(bp_cnt_hit),
    .bp_cnt_pred(bp_cnt_pred)
  );

  wire[32-1:0]  seg7;
  wire[ 8-1:0]  rx_rdata;
  wire          rx_valid;
  wire[32-1:0]  mmio_rdata;
  wire          mmio_valid;
  MMIO #(
    .MEM_SCALE(MEM_SCALE),
    .CPU_FREQ (CPU_FREQ),
    .BAUDRATE (1000000)
  ) mmio (
    .clk(clk),
    .rst(rst),

    .oe((mem_oe[0] && mem_addr[28+:4]==4'hf) ? 4'hF : 4'h0),
    .addr(mem_addr[0+:MEM_SCALE]),
    .wdata(mem_wdata),
    .we(mem_we),
    .rdata(mmio_rdata),
    .valid(mmio_valid),

    .uart_rxd(uart_rxd),
    .uart_txd(uart_txd),
    .btn(btn),  // {down, right, left, up, center}
    .sw(sw),
    .bp_cnt_hit(bp_cnt_hit),  .bp_cnt_pred  (bp_cnt_pred),
    .dc_cnt_hit(dc_cnt_hit),  .dc_cnt_access(dc_cnt_access),

    .halt(halt),
    .led(led),
    .seg7(seg7),

    .rx_rdata(rx_rdata),
    .rx_valid(rx_valid)
  );

  wire                ioe;
  wire[MEM_SCALE-1:0] iaddr;
  wire[       32-1:0] irdata;
  wire                ivalid;
  ICACHE #(
    .MEM_SCALE(MEM_SCALE),
    .SCALE    (10)
  ) ic (
    .clk(clk),
    .rst(rst),

    .oe(imem_oe),
    .addr(imem_addr[0+:MEM_SCALE]),
    .rdata(imem_rdata),
    .valid(imem_valid),

    .super_oe(ioe),
    .super_addr(iaddr),
    .super_rdata(irdata),
    .super_valid(ivalid),

    .clear(~init_done),
    .ic_cnt_hit(ic_cnt_hit),
    .ic_cnt_access(ic_cnt_access)
  );

  wire                doe;
  wire[MEM_SCALE-1:0] daddr;
  wire[       32-1:0] dwdata;
  wire[        4-1:0] dwe;
  wire[       32-1:0] drdata;
  wire                dvalid, dwritten;
  wire[       32-1:0] dmem_rdata;
  wire                dmem_valid;
  DCACHE #(
    .MEM_SCALE(MEM_SCALE),
    .SCALE    (10)
  ) dc (
    .clk(clk),
    .rst(rst),

    .oe(mem_addr<32'h08000000 ? mem_oe : 4'h0),
    .addr(mem_addr[0+:MEM_SCALE]),
    .wdata(mem_wdata),
    .we(mem_we),
    .rdata(dmem_rdata),
    .valid(dmem_valid),
    .busy(dmem_busy),

    .super_oe(doe),     // request to load 4byte / write
    .super_addr(daddr),
    .super_wdata(dwdata),
    .super_we(dwe),
    .super_rdata(drdata),
    .super_valid(dvalid),
    .super_written(dwritten),

    .clear(~init_done),
    .dc_cnt_hit   (dc_cnt_hit),
    .dc_cnt_access(dc_cnt_access)
  );

  wire          dram_oe;
  wire[32-1:0]  dram_addr;
  wire[32-1:0]  dram_wdata;
  wire[ 4-1:0]  dram_we;
  wire[32-1:0]  dram_rdata;
  wire          dram_valid, dram_written;
  DRAM_ARBITER #(
    .MEM_SCALE(MEM_SCALE)
  ) arbiter (
    .clk          (clk),
    .rst          (rst),
    // imem
    .ioe          (ioe),
    .iaddr        (iaddr),
    .irdata       (irdata),
    .ivalid       (ivalid),
    // dmem
    .doe          ({4{doe}}),
    .daddr        (daddr),
    .dwdata       (dwdata),
    .dwe          (dwe),
    .drdata       (drdata),
    .dvalid       (dvalid),
    .dwritten     (dwritten),
    // dram
    .dram_oe      (dram_oe),
    .dram_addr    (dram_addr[0+:MEM_SCALE]),
    .dram_wdata   (dram_wdata),
    .dram_we      (dram_we),
    .dram_rdata   (dram_rdata),
    .dram_valid   (init_done & dram_valid),
    .dram_written (init_done & dram_written)
  );

  // program loader
  wire[32-1:0]  init_waddr, init_wdata;
  wire          init_we;
  PLOADER pl (
    .CLK(clk),
    .RST_X(~rst),
    .ADDR(init_waddr),
    .INITDATA(init_wdata),
    .WE(init_we),
    .DONE(init_done),
    .RX_DATA(rx_rdata),
    .RX_VALID(rx_valid)
  );

  // dram: read/write after 1 cycle from dmem_oe/dmem_we assertion
  //  read ONLY IF cache miss occured
  //  write always
  DRAM dram (
    .clk          (clk),
    .rst          (rst),
    .clk_mig_200  (clk_mig_200),

    .calib_done   (calib_done),
    .locked_mig   (locked_mig),
    .locked_ref   (locked_ref),

    .dram_oe      (init_we | dram_oe),
    .dram_addr    (init_done ? dram_addr  : init_waddr),
    .dram_wdata   (init_done ? dram_wdata : init_wdata),
    .dram_we      ({4{init_we}} | dram_we),
    .dram_rdata   (dram_rdata),
    .dram_valid   (dram_valid),
    .dram_written (dram_written),

    .ddr2_addr    (ddr2_addr),
    .ddr2_ba      (ddr2_ba),
    .ddr2_cas_n   (ddr2_cas_n),
    .ddr2_ck_n    (ddr2_ck_n),
    .ddr2_ck_p    (ddr2_ck_p),
    .ddr2_cke     (ddr2_cke),
    .ddr2_cs_n    (ddr2_cs_n),
    .ddr2_dm      (ddr2_dm),
    .ddr2_dq      (ddr2_dq),
    .ddr2_dqs_n   (ddr2_dqs_n),
    .ddr2_dqs_p   (ddr2_dqs_p),
    .ddr2_odt     (ddr2_odt),
    .ddr2_ras_n   (ddr2_ras_n),
    .ddr2_we_n    (ddr2_we_n)
  );

  always @(posedge clk) begin
    mem_valid <= mmio_valid | dmem_valid;
    mem_rdata <=
      mmio_valid  ? mmio_rdata    :
      dmem_valid  ? dmem_rdata    :
                    32'hxxxxxxxx;
  end

  // LEDs
  reg [31:0] disp;
  always @(posedge clk) disp<=
    ~init_done              ? init_waddr      :
    (btn[LEFT]&&btn[RIGHT]) ? pc              :
                              seg7;
  M_7SEGCON m_7seg(clk, disp, cs, an);

  reg           ledmask=1'b0;
  always @(posedge clk) ledmask <= clkcnt[17+:2]==2'h0;

  reg           rgbledmask=1'b0;
  always @(posedge clk) rgbledmask <= clkcnt[13+:6]==6'h00;
  //                          RED           GREEN       BLUE
  assign  rgbled0 = rgbledmask ? {locked_mig,  calib_done, locked_ref} : 3'd0;
  assign  rgbled1 = rgbledmask ? {clk1hz,      rst,        init_done} : 3'd0;

endmodule

`default_nettype wire
