`default_nettype none
`timescale 1ns/100ps
`include "INST.v"

// Top module for simulation
module TOP #(
  parameter MAX_CYCLE = 50000000,
  parameter TRACE     = 1
) ();
localparam  ISCALE  = 16-2;
localparam  DSCALE  = 27-2;
reg clk=0, rst=1;

initial begin
  clk = 0;
  #50
  forever #50 clk = ~clk;
end

integer cycle;
initial begin
  $display("start");
  rst = 1;
  #520;
  $display("deassert reset");
  rst = 0;
  cycle = 0;
end
always @(posedge clk) begin
  cycle <= cycle + 1;
  if(cycle>MAX_CYCLE) begin
    $display("");
    $display("Abort! Cycle limit exceeded.");
    $finish();
  end
end

initial begin
  $dumpfile("/tmp/wave.vcd");
  $dumpvars(1);
  $dumpvars(1, p, p.gpr);
end

wire[16-1:0]  imem_addr;
wire          imem_oe;
wire[32-1:0]  imem_rdata;
reg           imem_ready;

wire[32-1:0]  mem_addr;
wire          mem_oe;
wire[32-1:0]  mem_wdata;
wire[ 4-1:0]  mem_we;
wire[32-1:0]  mem_rdata;
wire          mem_ready;

integer       fd, dummy, i;
reg [32-1:0]  fdata;
initial begin
  $display("reading image");
  fd = $fopen("image", "rb");
  if(!fd) begin $display("failed to open image"); $finish(); end

  for(i=0; i<2**ISCALE; i=i+1) begin
    dummy = $fread(fdata, fd);
    imem.rom.ram[i] = {fdata[0+:8], fdata[8+:8], fdata[16+:8], fdata[24+:8]};
  end

  dummy = $rewind(fd);

  for(i=0; i<2**DSCALE && !$feof(fd); i=i+1) begin
    dummy = $fread(fdata, fd);
    dmem.ram[i] = {fdata[0+:8], fdata[8+:8], fdata[16+:8], fdata[24+:8]};
  end

  //dummy = $fread(imem.rom.ram, fd); // simple but invalid indianness
  //dummy = $fread(dmem.ram, fd);     // simple but invalid indianness
  $display("done");
end

// trace output
generate if(TRACE) begin
  reg [5*8-1:0] opstr;
  reg [4*8-1:0] f3str;
  reg [ 32-1:0] ir;
  reg [  5-1:0] opcode;
  reg [  3-1:0] funct3;
  reg [  7-1:0] funct7;
  reg [ 32-1:0] imm;
  always @(posedge clk) begin
    ir      = p.ir[p.EM];
    opcode  = p.OPCODE(ir);
    funct3  = p.FUNCT3(ir);
    funct7  = p.FUNCT7(ir);
    imm     = p.IMM(ir);
    opstr =
      ir==`NOP        ? "NOP"   :
      opcode==`LOAD   ? "LOAD"  :
      opcode==`STORE  ? "STORE" :
      opcode==`OPIMM  ? "OPIMM" :
      opcode==`OP     ? "OP"    :
      opcode==`AUIPC  ? "AUIPC" :
      opcode==`LUI    ? "LUI"   :
      opcode==`BRANCH ? "BRNCH" :
      opcode==`JALR   ? "JALR"  :
      opcode==`JAL    ? "JAL"   :
                        "UNK";
    f3str =
      ir==`NOP        ? "-"   :
      opcode==`BRANCH ? (
        funct3==`BEQ    ? "BEQ"   :
        funct3==`BNE    ? "BNE"   :
        funct3==`BLT    ? "BLT"   :
        funct3==`BGE    ? "BGE"   :
        funct3==`BLTU   ? "BLTU"  :
        funct3==`BGEU   ? "BGEU"  :
                          "UNK")    :
      opcode==`LOAD   ? (
        funct3==`LB     ? "LB"    :
        funct3==`LH     ? "LH"    :
        funct3==`LW     ? "LW"    :
        funct3==`LBU    ? "LBU"   :
        funct3==`LHU    ? "LHU"   :
                          "UNK")    :
      opcode==`STORE  ? (
        funct3==`SB     ? "SB"    :
        funct3==`SH     ? "SH"    :
        funct3==`SW     ? "SW"    :
                          "UNK")    :
      opcode==`OPIMM || opcode==`OP ? (
        funct3==`ADD    ? (funct7[5]==`ADD7 ? "ADD" : "SUB"):
        funct3==`SLL    ? "SLL"   :
        funct3==`SLT    ? "SLT"   :
        funct3==`SLTU   ? "SLTU"  :
        funct3==`XOR    ? "XOR"   :
        funct3==`SRL    ? (funct7[5]==`SRL7 ? "SRL" : "SRA"):
        funct3==`OR     ? "OR"    :
        funct3==`AND    ? "AND"   :
                          "UNK")    :
                        "-";

    $write(
      "h%x h%x : %s %s x%02d x%02d(h%x) x%02d(h%x) imm=h%x s=%b",
      p.pc[p.EM][0+:16+2], ir, opstr, f3str,
      p.RD(ir), p.RS1(ir), p.rrs1, p.RS2(ir), p.rrs2,
      p.IMM(ir), p.prev_stall);
    if(opcode==`BRANCH || opcode==`JALR || opcode==`JAL)
      $write(" b(h%x, taken=%b, flush=%b)", p.btarget[0+:16+2], p.btaken, p.bflush);
    if(mem_oe && !mem_we) $write(" dmem[h%x]",      mem_addr);
    if(mem_oe &&  mem_we) $write(" dmem[h%x]<-h%x", mem_addr, mem_wdata);
    $display("");
  end
end endgenerate

PROCESSOR p (
  .clk(clk),
  .rst(rst),

  .imem_addr(imem_addr),
  .imem_oe(imem_oe),
  .imem_rdata(imem_rdata),
  .imem_ready(imem_ready),

  .mem_addr(mem_addr),
  .mem_oe(mem_oe),
  .mem_wdata(mem_wdata),
  .mem_we(mem_we),
  .mem_rdata(mem_rdata),
  .mem_ready(mem_ready)
);

// MEMO: It is better to insert FIFO to store requests for memory read,
// because mem_oe and mem_addr are generally asserted one cycle per a request
// and can be lost while fetching a responce.
// RAM module always respond in one cycle, so there is no need in this case.

// instruction memory
ROM #(.SCALE(16-2)) imem (
  .clk(clk),
  .rst(rst),

  .oe0(imem_oe),
  .addr0(imem_addr[2+:14]),
  .rdata0(imem_rdata),

  .oe1(1'b0),
  .addr1(14'h0),
  .rdata1()
);
always @(posedge clk) imem_ready <= imem_oe;  // never misses

// memory mapped IO
wire          mmio_oe = mem_oe && mem_addr[28+:4]==4'hf;
wire[ 4-1:0]  mmio_we = mmio_oe && mem_we;
reg [32-1:0]  mmio_rdata = 0;
reg           mmio_ready = 1'b0;
always @(posedge clk) begin
  if(mmio_oe && mmio_we) begin  // write
    case (mem_addr)
      32'hf0000000: begin $display("Halt!"); $finish(); end
      32'hf0000004: begin
        if(TRACE) $display("output: %s", mem_wdata[0+:8]);
        else      $write("%s", mem_wdata[0+:8]);
      end
      default : begin end
    endcase
  end
  if(mmio_oe && !mmio_we) begin // read
    case (mem_addr)
      // return non zero when TX is available (always available in testbench)
      32'hf0000004: begin mmio_ready <= 1'b1; mmio_rdata <= 32'b1; end
      default     : begin mmio_ready <= 1'b1; mmio_rdata <= 32'hxxxxxxxx; end
    endcase
  end else begin
    mmio_ready  <= 1'b0;
  end
end

// data memory
wire          dmem_oe = mem_oe && mem_addr<32'h08000000;
wire[ 4-1:0]  dmem_we = dmem_oe && mem_we;
wire[32-1:0]  dmem_rdata;
reg           dmem_ready = 1'b0;
RAM #(.SCALE(27-2)) dmem (
  .clk(clk),
  .rst(rst),

  .oe0(dmem_oe),
  .addr0(mem_addr[2+:25]),
  .wdata0(mem_wdata),
  .we0(dmem_we),
  .rdata0(dmem_rdata),

  .oe1(1'b0),
  .addr1(25'h0),
  .wdata1(),
  .we1(4'b0),
  .rdata1()
);
always @(posedge clk) dmem_ready <= dmem_oe;  // never misses

assign  mem_ready = mmio_ready | dmem_ready;
assign  mem_rdata =
  mmio_ready  ? mmio_rdata  :
  dmem_ready  ? dmem_rdata  :
                32'hxxxxxxxx;

always @(posedge clk) begin
  if(!rst && ((imem_oe && |imem_addr[1:0]) || (mem_oe && |mem_addr[1:0]))) begin
    $display("Not implemented: r/w to non-aligned addr %x %x", imem_addr, mem_addr);
    $finish();
  end
end

endmodule

