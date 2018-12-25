`default_nettype none
`timescale 1ps/1ps

module IBUF (
  output  wire  O,
  input   wire  I
);
  assign  O = I;
endmodule

module GENCLK_CPU (
  input   wire      clk_in,
  input   wire      reset,
  output  wire      clk_out,
  output  wire      locked
);
  assign  clk_out = clk_in;
  assign  locked  = ~reset;
endmodule

module GENCLK_REF (
  input   wire      clk_in,
  input   wire      reset,
  output  wire      clk_out,
  output  wire      locked
);
  assign  clk_out = clk_in;
  assign  locked  = ~reset;
endmodule

/*
module DRAM (
  input   wire          clk,
  input   wire          rst_mig,
  input   wire          clk_mig_200,

  output  wire          calib_done,
  output  wire          locked_mig,

  input   wire          dram_oe,
  input   wire[32-1:0]  dram_addr,
  input   wire[32-1:0]  dram_wdata,
  input   wire[ 4-1:0]  dram_we,
  output  reg [32-1:0]  dram_rdata,
  output  reg           dram_valid,
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
  assign  calib_done  = 1'b1;
  assign  locked_mig  = 1'b1;

  wire[32-1:0]  _dram_rdata;
  RAM #(.SCALE(27)) dram (
    .clk(clk),
    .rst(rst_mig),

    .oe0(dram_oe),
    .addr0(dram_addr[0+:27]),
    .wdata0(dram_wdata),
    .we0(dram_we),
    .rdata0(_dram_rdata),

    .oe1(1'b0),
    .addr1(27'h0),
    .wdata1(32'h0),
    .we1(4'b0),
    .rdata1()
  );
  reg           dram_reading=1'b0;
  reg           dram_writing=1'b0;
  reg [32-1:0]  dram_rdata_hold;
  always @(posedge clk) begin
    dram_writing    <= dram_we;
    dram_reading    <= dram_oe && !dram_we;
    dram_valid      <= dram_reading;
    dram_rdata      <= _dram_rdata;
  end
  assign  dram_busy = dram_reading | dram_writing;
endmodule
*/

module MIG_BLOCK (
  input   wire[31:0]  S_AXI_araddr,
  input   wire[1:0]   S_AXI_arburst,
  input   wire[3:0]   S_AXI_arcache,
  input   wire[0:0]   S_AXI_arid,
  input   wire[7:0]   S_AXI_arlen,
  input   wire[0:0]   S_AXI_arlock,
  input   wire[2:0]   S_AXI_arprot,
  input   wire[3:0]   S_AXI_arqos,
  output  wire        S_AXI_arready,
  input   wire[3:0]   S_AXI_arregion,
  input   wire[2:0]   S_AXI_arsize,
  input   wire        S_AXI_arvalid,
  input   wire[31:0]  S_AXI_awaddr,
  input   wire[1:0]   S_AXI_awburst,
  input   wire[3:0]   S_AXI_awcache,
  input   wire[0:0]   S_AXI_awid,
  input   wire[7:0]   S_AXI_awlen,
  input   wire[0:0]   S_AXI_awlock,
  input   wire[2:0]   S_AXI_awprot,
  input   wire[3:0]   S_AXI_awqos,
  output  wire        S_AXI_awready,
  input   wire[3:0]   S_AXI_awregion,
  input   wire[2:0]   S_AXI_awsize,
  input   wire        S_AXI_awvalid,
  output  wire[0:0]   S_AXI_bid,
  input   wire        S_AXI_bready,
  output  wire[1:0]   S_AXI_bresp,
  output  wire        S_AXI_bvalid,
  output  wire[127:0] S_AXI_rdata,
  output  wire[0:0]   S_AXI_rid,
  output  wire        S_AXI_rlast,
  input   wire        S_AXI_rready,
  output  wire[1:0]   S_AXI_rresp,
  output  wire        S_AXI_rvalid,
  input   wire[127:0] S_AXI_wdata,
  input   wire        S_AXI_wlast,
  output  wire        S_AXI_wready,
  input   wire[15:0]  S_AXI_wstrb,
  input   wire        S_AXI_wvalid,
  output  wire        calib_done,
  input   wire        clk_axi,
  input   wire        clk_mig,
  output  wire[12:0]  ddr2_addr,
  output  wire[2:0]   ddr2_ba,
  output  wire        ddr2_cas_n,
  output  wire[0:0]   ddr2_ck_n,
  output  wire[0:0]   ddr2_ck_p,
  output  wire[0:0]   ddr2_cke,
  output  wire[0:0]   ddr2_cs_n,
  output  wire[1:0]   ddr2_dm,
  inout   wire[15:0]  ddr2_dq,
  inout   wire[1:0]   ddr2_dqs_n,
  inout   wire[1:0]   ddr2_dqs_p,
  output  wire[0:0]   ddr2_odt,
  output  wire        ddr2_ras_n,
  output  wire        ddr2_we_n,
  output  wire        locked_mig,
  input   wire        rst_mig
);
  // Width of S_AXI data bus
  localparam  integer C_S_AXI_DATA_WIDTH  = 32;
  // Width of S_AXI address bus
  localparam  integer C_S_AXI_ADDR_WIDTH  = 27;

  assign  calib_done = 1'b1;
  assign  locked_mig = 1'b1;

  // AXI4LITE signals
  reg [C_S_AXI_ADDR_WIDTH-1 : 0]  axi_awaddr;
  reg   axi_awready;
  reg   axi_wready;
  reg [1 : 0]   axi_bresp;
  reg   axi_bvalid;
  reg [C_S_AXI_ADDR_WIDTH-1 : 0]  axi_araddr;
  reg   axi_arready;
  reg [C_S_AXI_DATA_WIDTH-1 : 0]  axi_rdata;
  reg [1 : 0]   axi_rresp;
  reg   axi_rvalid;

  // Example-specific design signals
  // local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
  // ADDR_LSB is used for addressing 32/64 bit registers/memories
  // ADDR_LSB = 2 for 32 bits (n downto 2)
  // ADDR_LSB = 3 for 64 bits (n downto 3)
  localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
  localparam integer OPT_MEM_ADDR_BITS = C_S_AXI_ADDR_WIDTH-ADDR_LSB; // honmaka
  //----------------------------------------------
  //-- Signals for user logic register space example
  //------------------------------------------------
  //-- Number of Slave Registers 2**27 byte (2**25 word)
  reg [C_S_AXI_DATA_WIDTH-1:0]  slv_reg[0:2**OPT_MEM_ADDR_BITS-1];
  wire   slv_reg_rden;
  wire   slv_reg_wren;
  wire[C_S_AXI_DATA_WIDTH-1:0]   reg_data_out;
  integer  byte_index;
  reg  aw_en;

  // I/O Connections assignments

  assign S_AXI_awready  = axi_awready;
  assign S_AXI_wready = axi_wready;
  assign S_AXI_bresp  = axi_bresp;
  assign S_AXI_bvalid = axi_bvalid;
  assign S_AXI_arready  = axi_arready;
  assign S_AXI_rdata  = axi_rdata;
  assign S_AXI_rresp  = axi_rresp;
  assign S_AXI_rvalid = axi_rvalid;
  // Implement axi_awready generation
  // axi_awready is asserted for one clk_axi clock cycle when both
  // S_AXI_awvalid and S_AXI_wvalid are asserted. axi_awready is
  // de-asserted when reset is low.

  always @( posedge clk_axi )
  begin
    if ( rst_mig )
      begin
        axi_awready <= 1'b0;
        aw_en <= 1'b1;
      end 
    else
      begin    
        if (~axi_awready && S_AXI_awvalid && S_AXI_wvalid && aw_en)
          begin
            // slave is ready to accept write address when 
            // there is a valid write address and write data
            // on the write address and data bus. This design 
            // expects no outstanding transactions. 
            axi_awready <= 1'b1;
            aw_en <= 1'b0;
          end
          else if (S_AXI_bready && axi_bvalid)
              begin
                aw_en <= 1'b1;
                axi_awready <= 1'b0;
              end
        else           
          begin
            axi_awready <= 1'b0;
          end
      end 
  end       

  // Implement axi_awaddr latching
  // This process is used to latch the address when both 
  // S_AXI_awvalid and S_AXI_wvalid are valid. 

  always @( posedge clk_axi )
  begin
    if ( rst_mig )
      begin
        axi_awaddr <= 0;
      end 
    else
      begin    
        if (~axi_awready && S_AXI_awvalid && S_AXI_wvalid && aw_en)
          begin
            // Write Address latching 
            axi_awaddr <= S_AXI_awaddr;
          end
      end 
  end       

  // Implement axi_wready generation
  // axi_wready is asserted for one clk_axi clock cycle when both
  // S_AXI_awvalid and S_AXI_wvalid are asserted. axi_wready is 
  // de-asserted when reset is low. 

  always @( posedge clk_axi )
  begin
    if ( rst_mig )
      begin
        axi_wready <= 1'b0;
      end 
    else
      begin    
        if (~axi_wready && S_AXI_wvalid && S_AXI_awvalid && aw_en )
          begin
            // slave is ready to accept write data when 
            // there is a valid write address and write data
            // on the write address and data bus. This design 
            // expects no outstanding transactions. 
            axi_wready <= 1'b1;
          end
        else
          begin
            axi_wready <= 1'b0;
          end
      end 
  end       

  // Implement memory mapped register select and write logic generation
  // The write data is accepted and written to memory mapped registers when
  // axi_awready, S_AXI_wvalid, axi_wready and S_AXI_wvalid are asserted. Write strobes are used to
  // select byte enables of slave registers while writing.
  // These registers are cleared when reset (active low) is applied.
  // Slave register write enable is asserted when valid address and data are available
  // and the slave is ready to accept the write address and write data.
  assign slv_reg_wren = axi_wready && S_AXI_wvalid && axi_awready && S_AXI_awvalid;

  integer i;
  always @( posedge clk_axi )
  begin
    if ( rst_mig )
      begin
        //for (i = 0; i < 2**OPT_MEM_ADDR_BITS; i = i + 1) begin
        //  slv_reg[i] <= 0;
        //end
      end 
    else begin
      if (slv_reg_wren)
        begin
          for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 ) begin
            if ( S_AXI_wstrb[byte_index] == 1 ) begin
              // Respective byte enables are asserted as per write strobes 
              slv_reg[axi_awaddr[ADDR_LSB+:OPT_MEM_ADDR_BITS]][(byte_index*8) +: 8] <=
                S_AXI_wdata[(byte_index*8) +: 8];
            end
          end
        end
    end
  end    

  // Implement write response logic generation
  // The write response and response valid signals are asserted by the slave 
  // when axi_wready, S_AXI_wvalid, axi_wready and S_AXI_wvalid are asserted.  
  // This marks the acceptance of address and indicates the status of 
  // write transaction.

  always @( posedge clk_axi )
  begin
    if ( rst_mig )
      begin
        axi_bvalid  <= 0;
        axi_bresp   <= 2'b0;
      end 
    else
      begin    
        if (axi_awready && S_AXI_awvalid && ~axi_bvalid && axi_wready && S_AXI_wvalid)
          begin
            // indicates a valid write response is available
            axi_bvalid <= 1'b1;
            axi_bresp  <= 2'b0; // 'OKAY' response 
          end                   // work error responses in future
        else
          begin
            if (S_AXI_bready && axi_bvalid) 
              //check if bready is asserted while bvalid is high) 
              //(there is a possibility that bready is always asserted high)   
              begin
                axi_bvalid <= 1'b0; 
              end  
          end
      end
  end   

  // Implement axi_arready generation
  // axi_arready is asserted for one clk_axi clock cycle when
  // S_AXI_arvalid is asserted. axi_awready is 
  // de-asserted when reset (active low) is asserted. 
  // The read address is also latched when S_AXI_arvalid is 
  // asserted. axi_araddr is reset to zero on reset assertion.

  always @( posedge clk_axi )
  begin
    if ( rst_mig )
      begin
        axi_arready <= 1'b0;
        axi_araddr  <= 32'b0;
      end 
    else
      begin    
        if (~axi_arready && S_AXI_arvalid)
          begin
            // indicates that the slave has acceped the valid read address
            axi_arready <= 1'b1;
            // Read address latching
            axi_araddr  <= S_AXI_araddr;
          end
        else
          begin
            axi_arready <= 1'b0;
          end
      end 
  end       

  // Implement axi_arvalid generation
  // axi_rvalid is asserted for one clk_axi clock cycle when both 
  // S_AXI_arvalid and axi_arready are asserted. The slave registers 
  // data are available on the axi_rdata bus at this instance. The 
  // assertion of axi_rvalid marks the validity of read data on the 
  // bus and axi_rresp indicates the status of read transaction.axi_rvalid 
  // is deasserted on reset (active low). axi_rresp and axi_rdata are 
  // cleared to zero on reset (active low).  
  always @( posedge clk_axi )
  begin
    if ( rst_mig )
      begin
        axi_rvalid <= 0;
        axi_rresp  <= 0;
      end 
    else
      begin    
        if (axi_arready && S_AXI_arvalid && ~axi_rvalid)
          begin
            // Valid read data is available at the read data bus
            axi_rvalid <= 1'b1;
            axi_rresp  <= 2'b0; // 'OKAY' response
          end   
        else if (axi_rvalid && S_AXI_rready)
          begin
            // Read data is accepted by the master
            axi_rvalid <= 1'b0;
          end                
      end
  end    

  // Implement memory mapped register select and read logic generation
  // Slave register read enable is asserted when valid address is available
  // and the slave is ready to accept the read address.
  assign slv_reg_rden = axi_arready & S_AXI_arvalid & ~axi_rvalid;
  // Address decoding for reading registers
  assign reg_data_out = slv_reg[axi_araddr[ADDR_LSB+:OPT_MEM_ADDR_BITS]];

  // Output register or memory read data
  always @( posedge clk_axi )
  begin
    if ( rst_mig )
      begin
        axi_rdata  <= 0;
      end 
    else
      begin    
        // When there is a valid read address (S_AXI_arvalid) with 
        // acceptance of read address by the slave (axi_arready), 
        // output the read dada 
        if (slv_reg_rden)
          begin
            axi_rdata <= reg_data_out;     // register read data
          end   
      end
  end    

  // Add user logic here

  // User logic ends

endmodule

`default_nettype wire
