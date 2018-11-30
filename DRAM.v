`default_nettype none
`timescale 1ns/100ps

module DRAM (
  input   wire          clk,
  input   wire          sys_rst,
  input   wire          aresetn,
  input   wire          clk_ref_200,

  output  wire          init_calib_complete,
  output  wire          mmcm_locked,

  input   wire          dram_oe,
  input   wire[32-1:0]  dram_addr,
  input   wire[32-1:0]  dram_wdata,
  input   wire[ 4-1:0]  dram_we,
  output  reg [32-1:0]  dram_rdata,
  output  wire          dram_valid,
  output  wire          dram_busy,

  output  wire[13-1:0]  ddr2_addr,
  output  wire[2:0]     ddr2_ba,
  output  wire          ddr2_cas_n,
  output  wire[0:0]     ddr2_ck_n,
  output  wire[0:0]     ddr2_ck_p,
  output  wire[0:0]     ddr2_cke,
  output  wire[0:0]     ddr2_cs_n,
  output  wire[1:0]     ddr2_dm,
  inout   wire[16-1:0]  ddr2_dq,
  inout   wire[1:0]     ddr2_dqs_n,
  inout   wire[1:0]     ddr2_dqs_p,
  output  wire[0:0]     ddr2_odt,
  output  wire          ddr2_ras_n,
  output  wire          ddr2_we_n
);

  reg         read_done=1'b0, write_done=1'b0;
  assign      dram_valid  = read_done;
  assign      dram_busy   = read_done || write_done;
  reg         reading=1'b0, writing=1'b0;

  // read address channel
  reg [31:0]  S_AXI_araddr;   // out
  reg         S_AXI_arvalid;  // out
  wire        S_AXI_arready;  // in
  // read data channel
  wire[127:0] S_AXI_rdata;    // in
  wire        S_AXI_rvalid;   // in
  wire        S_AXI_rready = 1'b1; // out

  // read
  always @(posedge clk) begin
    if(reading) begin
      reading       <= ~S_AXI_rvalid;
      read_done     <=  S_AXI_rvalid;
      S_AXI_arvalid <= S_AXI_arvalid & ~S_AXI_arready;
      if(S_AXI_rvalid) dram_rdata <= S_AXI_rdata[0+:32];
    end else if(!writing) begin // idle
      reading       <= dram_oe & ~dram_we[0];
      read_done     <= 1'b0;
      S_AXI_arvalid <= dram_oe & ~dram_we[0];
      if(dram_oe) S_AXI_araddr  <= dram_addr;
    end else begin  // writing
      reading       <= 1'b0;
      read_done     <= 1'b0;
      S_AXI_arvalid <= 1'b0;
    end
  end

  // write address channel
  reg [31:0]  S_AXI_awaddr;   // out
  reg         S_AXI_awvalid;  // out
  wire        S_AXI_awready;  // in
  // write data channel
  reg [127:0] S_AXI_wdata;    // out
  reg [15:0]  S_AXI_wstrb;    // out
  reg         S_AXI_wvalid;   // out
  wire        S_AXI_wready;   // in
  // write response channel
  wire        S_AXI_bvalid;

  // write
  always @(posedge clk) begin
    if(writing) begin
      writing       <= ~S_AXI_bvalid;
      write_done    <=  S_AXI_bvalid;
      S_AXI_awvalid <= S_AXI_awvalid & ~S_AXI_awready;
      S_AXI_wvalid  <= S_AXI_wvalid  & ~S_AXI_wready;
    end else if(!reading) begin // idle
      writing       <= dram_we[0];
      write_done    <= 1'b0;
      S_AXI_awvalid <= dram_we[0];
      S_AXI_wvalid  <= dram_we[0];
      if(dram_we[0]) S_AXI_awaddr       <= dram_addr;
      if(dram_we[0]) S_AXI_wdata[0+:32] <= dram_wdata;
      if(dram_we[0]) S_AXI_wstrb[0+:4]  <= dram_we;
    end else begin  // reading
      writing       <= 1'b0;
      write_done    <= 1'b0;
      S_AXI_awvalid <= 1'b0;
      S_AXI_wvalid  <= 1'b0;
    end
  end


  MIG_BLOCK mb (
    .sys_clk_i(clk),
    .sys_rst(sys_rst),
    .aresetn(aresetn),
    .clk_ref_i(clk_ref_200),
    .init_calib_complete(init_calib_complete),
    .mmcm_locked(mmcm_locked),
    // read address channel
    .S_AXI_araddr(S_AXI_araddr),
    .S_AXI_arburst(2'b00),
    .S_AXI_arcache(4'h0),
    .S_AXI_arid(1'b0),
    .S_AXI_arlen(8'h0),
    .S_AXI_arlock(1'b0),
    .S_AXI_arprot(3'b000),
    .S_AXI_arqos(4'h0),
    .S_AXI_arready(S_AXI_arready),
    .S_AXI_arsize(3'b111),
    .S_AXI_arvalid(S_AXI_arvalid),
    // write address channel
    .S_AXI_awaddr(S_AXI_awaddr),
    .S_AXI_awburst(2'b00),
    .S_AXI_awcache(4'h0),
    .S_AXI_awid(1'b0),
    .S_AXI_awlen(8'h0),
    .S_AXI_awlock(1'b0),
    .S_AXI_awprot(3'b000),
    .S_AXI_awqos(4'h0),
    .S_AXI_awready(S_AXI_awready),
    .S_AXI_awsize(3'b111),
    .S_AXI_awvalid(S_AXI_awvalid),
    // read data channel
    .S_AXI_rdata(S_AXI_rdata),
    .S_AXI_rid(),
    .S_AXI_rlast(),
    .S_AXI_rready(S_AXI_rready),
    .S_AXI_rresp(),
    .S_AXI_rvalid(S_AXI_rvalid),
    // write data channel
    .S_AXI_wdata(S_AXI_wdata),
    .S_AXI_wlast(1'b1),
    .S_AXI_wready(S_AXI_wready),
    .S_AXI_wstrb(S_AXI_wstrb),
    .S_AXI_wvalid(S_AXI_wvalid),
    // write response channel
    .S_AXI_bid(),
    .S_AXI_bready(1'b1),
    .S_AXI_bresp(),
    .S_AXI_bvalid(S_AXI_bvalid),
    // ddr2 I/F
    .ddr2_sdram_addr(ddr2_addr),
    .ddr2_sdram_ba(ddr2_ba),
    .ddr2_sdram_cas_n(ddr2_cas_n),
    .ddr2_sdram_ck_n(ddr2_ck_n),
    .ddr2_sdram_ck_p(ddr2_ck_p),
    .ddr2_sdram_cke(ddr2_cke),
    .ddr2_sdram_cs_n(ddr2_cs_n),
    .ddr2_sdram_dm(ddr2_dm),
    .ddr2_sdram_dq(ddr2_dq),
    .ddr2_sdram_dqs_n(ddr2_dqs_n),
    .ddr2_sdram_dqs_p(ddr2_dqs_p),
    .ddr2_sdram_odt(ddr2_odt),
    .ddr2_sdram_ras_n(ddr2_ras_n),
    .ddr2_sdram_we_n(ddr2_we_n)
  );
endmodule
