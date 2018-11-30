`default_nettype none
`timescale 1ns/100ps

module TOP_NEXYS4DDR (
  input   wire          clk100mhz,
  input   wire          cpu_resetn,
  input   wire[ 5-1:0]  btn,  // {down, right, left, up, center}
  input   wire[16-1:0]  sw,
  output  reg [16-1:0]  led,
  output  reg [6:0]     cs,   // 7-seg cathode segments
  output  reg [7:0]     an,   // 7-seg common anode
  input   wire          uart_rxd,
  output  reg           uart_txd,
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

// clocking
wire  clk, locked, locked_dram, dram_calib_comp;
GENCLK_CPU  genclkc (
  .clk_in(clk100mhz),
  .resetn(cpu_resetn),
  .clk_out(clk),
  .locked(locked)
);

// synchronize reset
wire      rst_async = ~locked | ~locked_dram | ~cpu_resetn | ~dram_calib_comp;
reg [1:0] rst_sync;
reg       rst;
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
wire          mem_oe;
wire[32-1:0]  mem_wdata;
wire[ 4-1:0]  mem_we;
wire[32-1:0]  mem_rdata;
wire          mem_valid;
wire          mem_ready;
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
  .mem_ready(mem_ready)
);

reg [32-1:0]  prev_mem_addr;
reg           prev_mem_oe;
reg [32-1:0]  prev_mem_wdata;
reg [ 4-1:0]  prev_mem_we;
reg [32-1:0]  prev_mem_rdata;
always @(posedge clk) prev_mem_addr  <= mem_addr;
always @(posedge clk) prev_mem_oe    <= mem_oe;
always @(posedge clk) prev_mem_wdata <= mem_wdata;
always @(posedge clk) prev_mem_we    <= mem_we;
always @(posedge clk) prev_mem_rdata <= mem_rdata;

// instruction memory
ROM #(.SCALE(16)) imem (
  .clk(clk),
  .rst(rst),

  .oe0(imem_oe),
  .addr0(imem_addr),
  .rdata0(imem_rdata),

  .oe1(1'b0),
  .addr1(16'h0),
  .rdata1()
);
always @(posedge clk) imem_valid <= imem_oe;  // never misses

// memory mapped IO
wire          mmio_oe = mem_oe && mem_addr[28+:4]==4'hf;
wire[ 4-1:0]  mmio_we = {4{mmio_oe}} & mem_we;
reg [32-1:0]  mmio_rdata = 0;
reg           mmio_valid = 1'b0;
always @(posedge clk) begin
  if(mmio_oe && mmio_we) begin  // write
    case (mem_addr)
      32'hf0000000: begin $display("Halt: a0 was %x", p.gpr.r[10]); $finish(); end
      32'hf0000100: begin
        if(TRACE) $display("output: %s", mem_wdata[0+:8]);
        else      $write("%s", mem_wdata[0+:8]);
      end
      default : begin end
    endcase
  end
  if(mmio_oe && !mmio_we) begin // read
    case (mem_addr)
      // return non zero when TX is available (always available in testbench)
      32'hf0000100: begin mmio_valid <= 1'b1; mmio_rdata <= 32'b1; end
      default     : begin mmio_valid <= 1'b1; mmio_rdata <= 32'h0; end
    endcase
  end else begin
    mmio_valid  <= 1'b0;
  end
end

// data memory
wire          dmem_oe = mem_oe && mem_addr<32'h08000000;
wire[ 4-1:0]  dmem_we = {4{dmem_oe}} & mem_we;

// data cache
// TO BE WRITTEN
reg           dcache_hit  = 1'b0;
reg           dcache_miss = 1'b0;
reg [32-1:0]  dcache_rdata;
always @(posedge clk) begin
  dcache_hit    <= 1'b0;
  dcache_miss   <= dmem_oe;
  if(dmem_oe) dcache_rdata  <= 32'hDEADDEAD;
end

// dram: read/write after 1 cycle from dmem_oe/dmem_we are asserted
//  read if dcache miss occured
//  write always
reg           dram_oe;
reg [32-1:0]  dram_addr;
reg [32-1:0]  dram_wdata;
reg [ 4-1:0]  dram_we;
wire[32-1:0]  dram_rdata;
wire          dram_valid;
wire          dram_busy;
always @(posedge clk) begin
  dram_oe     <= dcache_miss | prev_mem_we;
  dram_addr   <= prev_mem_addr;
  dram_wdata  <= prev_mem_wdata;
  dram_we     <= prev_mem_we;
end

DRAM dram (
  .clk(clk),
  .sys_rst(rst),
  .aresetn(1'b1),
  .clk_ref_200(clk_ref_200),

  .init_calib_complete(dram_calib_comp),
  .mmcm_locked(locked_dram),

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

assign  mem_valid = mmio_valid | dcache_hit | dram_valid;
assign  mem_rdata =
  mmio_valid  ? mmio_rdata    :
  dcache_hit  ? dcache_rdata  :
  dram_valid  ? dram_rdata    :
                32'hxxxxxxxx;
assign  mem_ready = ~dram_busy;

endmodule
/*

    wire           mig_clk, w_locked;
    wire           CLK, RST_X;
    wire [2:0]     CORE_STAT;
    wire [31:0]    MM_ADDR;
    wire [7:0]     MM_DATA;
    wire           MM_WE;
    wire [7:0]     MM_DOUT; 
    wire [31:0]    INIT_ADDR;
    wire [31:0]    INIT_DATA;
    wire           INIT_WE;
    wire           INIT_DONE;
    wire [31:0]    CORE_I_ADDR, CORE_D_ADDR;
    wire [31:0]    CORE_I_IN, CORE_D_IN, CORE_D_OUT;
    wire [3:0]     CORE_D_WE;
    wire           CORE_D_OE;

    clk_wiz_0 m_clkgen0 (.clk_in1(clk100mhz), .resetn(cpu_resetn), .clk_out1(mig_clk), .locked(w_locked));
    wire [31:0] mem_adr;        //
    wire        mem_we, mem_re; //
    wire [31:0] mem_wr_dat;     //
    wire [31:0] mem_rd_dat;     //
    wire        mem_busy;       //
    wire        calib_done;     //

    DRAM m_dram (
               // input clk, rst (active-low)
               .mig_clk(mig_clk),
               .mig_rst_x(w_locked), 
               // memory interface ports
               .ddr2_dq(ddr2_dq),
               .ddr2_dqs_n(ddr2_dqs_n),
               .ddr2_dqs_p(ddr2_dqs_p),
               .ddr2_addr(ddr2_addr),
               .ddr2_ba(ddr2_ba),
               .ddr2_ras_n(ddr2_ras_n),
               .ddr2_cas_n(ddr2_cas_n),
               .ddr2_we_n(ddr2_we_n),
               .ddr2_ck_p(ddr2_ck_p),
               .ddr2_ck_n(ddr2_ck_n),
               .ddr2_cke(ddr2_cke),
               .ddr2_cs_n(ddr2_cs_n),
               .ddr2_dm(ddr2_dm),
               .ddr2_odt(ddr2_odt),
               // output clk, rst (active-low)
               .o_clk(CLK),
               .o_rst_x(RST_X),
               // user interface ports
               .i_rd_en(mem_re),
               .i_wr_en(mem_we),
               .i_addr(mem_adr),
               .i_data(mem_wr_dat),
               .o_init_calib_complete(calib_done),
               .o_data(mem_rd_dat),
               .o_busy(mem_busy)
               );
    PLOADER m_loader(.CLK(CLK), .RST_X(RST_X), .uart_rxd(uart_rxd), .ADDR(INIT_ADDR), 
                     .DATA(INIT_DATA), .WE(INIT_WE), .DONE(INIT_DONE));
    wire        core_rst_x;
    wire [31:0] WORD_A, WORD_D;
    wire        WORD_W;

    assign core_rst_x = RST_X & INIT_DONE;
    reg [31:0] r_cnt  = 0;
    reg        r_halt = 0;
    always @(posedge CLK) r_halt <= (!RST_X) ? 0 : (CORE_D_WE & CORE_D_ADDR==4) ? 1 : r_halt;
    always @(posedge CLK) r_cnt <= (!core_rst_x) ? 0 : (!r_halt) ? r_cnt+1 : r_cnt;
    
    MIPSCORE m_core(.CLK(CLK), .RST_X(core_rst_x), .STALL(mem_busy), .STAT(CORE_STAT), .IO_IN(0), 
                    .I_ADDR(CORE_I_ADDR), .I_IN(CORE_I_IN), 
                    .D_ADDR(CORE_D_ADDR), .D_IN(CORE_D_IN), .D_OE(CORE_D_OE), 
                    .D_OUT(CORE_D_OUT), .D_WE(CORE_D_WE));

    IMEM m_imem(CLK, RST_X, INIT_ADDR, INIT_DATA, INIT_WE, CORE_I_ADDR, CORE_I_IN);

    wire load_hit;
    wire cache_valid;
    wire [31:0] cache_addr, cache_data;
    
    assign mem_adr    = (!INIT_DONE) ? {INIT_ADDR[31:2], 2'b00} : CORE_D_ADDR;
    assign mem_wr_dat = (!INIT_DONE) ? INIT_DATA : CORE_D_OUT;
    assign mem_we     = (!INIT_DONE) ? INIT_WE   : (load_hit) ? 0 : (CORE_D_WE!=0 && CORE_D_ADDR>32'hff);
    assign mem_re     =                            (load_hit) ? 0 : CORE_D_OE;
    assign CORE_D_IN  =                            (load_hit) ? cache_data : mem_rd_dat;
    reg [31:0] cache_hit   = 0;
    reg [31:0] cache_mis   = 0;
    reg [64:0] cache_line  = 0; // {1bit valid, 32bit address, 32bit data}

    reg r_mem_busy;
    always @(posedge CLK) r_mem_busy <= mem_busy;

    wire w_dat_rdy = r_mem_busy && !mem_busy;
    always @(posedge CLK) begin
        if (!core_rst_x) cache_line <= 0;
        else if (CORE_D_OE && !CORE_D_WE && w_dat_rdy) cache_line <= {1'b1, CORE_D_ADDR,  mem_rd_dat};
        else if (CORE_D_OE &&  CORE_D_WE && w_dat_rdy) cache_line <= {1'b1, CORE_D_ADDR,  CORE_D_OUT};
    end

    assign {cache_valid, cache_addr, cache_data} = cache_line;
    assign load_hit = (CORE_D_OE && !CORE_D_WE && cache_valid && cache_addr==CORE_D_ADDR);
        
    always @(posedge CLK) begin
      if(!core_rst_x) {cache_hit, cache_mis} <= 0;
      else begin
          if(CORE_D_OE && !CORE_D_WE && !mem_busy) begin
            if (load_hit) cache_hit <= cache_hit + 1;
            else          cache_mis <= cache_mis + 1;
          end
      end
    end
  
    reg [25:0] cnt_t; // just for uled
    always @(posedge CLK) cnt_t <= cnt_t + 1;
    
    always @(posedge CLK) uled[0] <= cnt_t[25];
    always @(posedge CLK) uled[1] <= r_halt;
    always @(posedge CLK) uled[2] <= CORE_STAT[0];       // Processor Decode Error
    always @(posedge CLK) uled[3] <= mem_busy;           // DRAM is working
    always @(posedge CLK) uled[4] <= ~txd;               // Uart txd
    always @(posedge CLK) uled[5] <= ~uart_rxd;               // Uart uart_rxd
    always @(posedge CLK) uled[6] <= ~calib_done;        // DRAM calibration done 
    always @(posedge CLK) uled[7] <= ~INIT_DONE;         // MEMORY IMAGE transfer is done
    wire tx_ready, txd_w;
    always @(posedge CLK) txd <= txd_w;
    UartTx m_send(CLK, RST_X, CORE_D_OUT[7:0], (CORE_D_WE & CORE_D_ADDR==0), txd_w, tx_ready); 

    wire [6:0] w_cs;
    wire [7:0] w_an;
    wire [31:0] w_7seg_data = (w_btnu) ? r_cnt: (w_btnd) ? cache_mis : cache_hit;
    m_7segcon m_7segcon(CLK, w_7seg_data, w_cs, w_an); 
    always @(posedge CLK) cs <= w_cs;
    always @(posedge CLK) an <= w_an;    
endmodule
*/
