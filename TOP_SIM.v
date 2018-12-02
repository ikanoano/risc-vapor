`default_nettype none
`timescale 1ns/100ps
`include "INST.v"

// Top module for simulation
module TOP_SIM ();
localparam  ISCALE  = 16-2;
localparam  DSCALE  = 27-2;
reg clk=0, rst=1;

// runtime parameter
integer         MAX_CYCLE;
integer         TRACE;
integer         DUMP;
reg [256*8-1:0] IMAGE;
initial begin
  if(!$value$plusargs("MAX_CYCLE=%d", MAX_CYCLE))     MAX_CYCLE=100000;
  if(!$value$plusargs("TRACE=%d", TRACE))             TRACE=0;
  if(!$value$plusargs("IMAGE=%s", IMAGE))             IMAGE="image";
  if(!$value$plusargs("DUMP=%d", DUMP))               DUMP=0;
  $display("MAX_CYCLE   = %0d", MAX_CYCLE);
  $display("TRACE       = %0d", TRACE);
  $display("DUMP        = %0d", DUMP);
  $display("IMAGE       = %0s", IMAGE);
end

// generate clock
initial begin
  clk = 0;
  #50
  forever #50 clk = ~clk;
end

// assert / deassert reset
initial begin
  $display("start");
  rst = 1;
  #520;
  $display("deassert reset");
  rst = 0;
end

// count cycle
integer cycle = 0;
always @(posedge clk) begin
  cycle <= cycle + 1;
  if(cycle>MAX_CYCLE) begin
    $display("");
    $display("Abort! Cycle limit %d exceeded.", MAX_CYCLE);
    $finish();
  end
end

// dump
initial begin
  #1
  if(DUMP) begin
    $dumpfile("/tmp/wave.vcd");
    $dumpvars(1);
    $dumpvars(1, p.pc[0], p.pc[1], p.pc[2], p.pc[3]);
    $dumpvars(1,          p.ir[1], p.ir[2], p.ir[3]);
    $dumpvars(1, p, p.gpr);
  end
end

// load image
integer       fd, dummy, i;
reg [32-1:0]  fdata;
initial begin
  #1
  $display("reading image: %0s", IMAGE);
  fd = $fopen(IMAGE, "rb");
  if(!fd) begin $display("failed to open image: %0s", IMAGE); $finish(); end

  for(i=0; i<2**ISCALE; i=i+1) begin
    dummy = $fread(fdata, fd);
    imem.rom.ram3[i]  = fdata[ 0+:8];
    imem.rom.ram2[i]  = fdata[ 8+:8];
    imem.rom.ram1[i]  = fdata[16+:8];
    imem.rom.ram0[i]  = fdata[24+:8];
  end

  dummy = $rewind(fd);

  for(i=0; i<2**DSCALE && !$feof(fd); i=i+1) begin
    dummy = $fread(fdata, fd);
    dmem.ram3[i]  = fdata[ 0+:8];
    dmem.ram2[i]  = fdata[ 8+:8];
    dmem.ram1[i]  = fdata[16+:8];
    dmem.ram0[i]  = fdata[24+:8];
  end

  //dummy = $fread(imem.rom.ram, fd); // simple but invalid indianness
  //dummy = $fread(dmem.ram, fd);     // simple but invalid indianness
  $display("done");
end

// cpu
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
  .mem_ready(1'b1),
  .cycle()
);

// MEMO: It is better to insert FIFO to store requests for memory read,
// because mem_oe and mem_addr are generally asserted one cycle per a request
// and can be lost while fetching a responce.
// RAM module always respond in one cycle, so there is no need in this case.

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
reg           mmio_ready = 1'b0;
always @(posedge clk) begin
  if(mmio_oe && mmio_we[0]) begin  // write
    case (mem_addr)
      32'hf0000000: begin $display("Halt: a0 was %x", p.gpr.r[10]); $finish(); end
      32'hf0000100: begin
        if(TRACE) $display("output: %s", mem_wdata[0+:8]);
        else      $write("%s", mem_wdata[0+:8]);
      end
      default : begin end
    endcase
  end
  if(mmio_oe && !mmio_we[0]) begin // read
    case (mem_addr)
      // return non zero when TX is available (always available in testbench)
      32'hf0000100: begin mmio_ready <= 1'b1; mmio_rdata <= 32'b1; end
      default     : begin mmio_ready <= 1'b1; mmio_rdata <= 32'h0; end
    endcase
  end else begin
    mmio_ready  <= 1'b0;
  end
end

// data memory
wire          dmem_oe = mem_oe && mem_addr<32'h08000000;
wire[ 4-1:0]  dmem_we = {4{dmem_oe}} & mem_we;
wire[32-1:0]  dmem_rdata;
reg           dmem_valid = 1'b0;
RAM #(.SCALE(27)) dmem (
  .clk(clk),
  .rst(rst),

  .oe0(dmem_oe),
  .addr0(mem_addr[0+:27]),
  .wdata0(mem_wdata),
  .we0(dmem_we),
  .rdata0(dmem_rdata),

  .oe1(1'b0),
  .addr1(27'h0),
  .wdata1(32'h0),
  .we1(4'b0),
  .rdata1()
);

reg           dmem_oe_r=1'b0;
reg [32-1:0]  dmem_rdata_hold;
always @(posedge clk) begin
  dmem_oe_r       <= dmem_oe;
  dmem_valid      <= dmem_oe_r;
  dmem_rdata_hold <= dmem_rdata;
  if(dmem_oe_r) #1 $display("miss");
end

assign  mem_valid = mmio_ready | dmem_valid;
assign  mem_rdata =
  mmio_ready  ? mmio_rdata  :
  dmem_valid  ? dmem_rdata_hold  :
                32'hxxxxxxxx;

always @(posedge clk) begin
  if(!rst && (imem_oe && |imem_addr[1:0])) begin
    $display("Error: read imem with non-aligned addr: %x", imem_addr);
    $finish();
  end
end



// trace output
localparam[8-1:0] SPACE = " ";
reg [  16-1:0]  pc;
reg [  32-1:0]  ir;
reg [   5-1:0]  opcode;
reg [   3-1:0]  funct3;
reg [   7-1:0]  funct7;
reg [  32-1:0]  imm;

reg [ 5*8-1:0]  opstr;
reg [ 4*8-1:0]  f3str;
reg [ 3*8-1:0]  rdstr;
reg [14*8-1:0]  rs1str;
reg [14*8-1:0]  rs2str;
reg [14*8-1:0]  immstr;
reg [32*8-1:0]  branchstr;
reg [32*8-1:0]  memstr;
reg [32*8-1:0]  stallstr;
reg [32*8-1:0]  ibstr;
reg [256*8-1:0] str_em="";
reg [32*8-1:0]  wbstr;
always @(posedge clk) if(TRACE && !rst) begin : trace
  if(|p.stall)    $sformat(stallstr, "s(b%b)", p.stall);
  else            stallstr = "";
  if(|p.insertb)  $sformat(ibstr, "b(b%b)", p.insertb);
  else            ibstr = "";
  $write("%8s %8s | ", stallstr, ibstr);
  if(p.stall[p.WB]) begin
    $display("");
    disable trace;  // early return
  end

  pc      = p.pc[p.EM][0+:16];
  ir      = p.ir[p.EM];
  opcode  = p.OPCODE(ir);
  funct3  = p.FUNCT3(ir);
  funct7  = p.FUNCT7(ir);
  imm     = p.IMM(ir);
  opstr =
    ir==`NOP          ? "nop"   :
    ir==`ECALL        ? "ecall" :
    ir==`MRET         ? "mret"  :
    opcode==`LOAD     ? "load"  :
    opcode==`STORE    ? "store" :
    opcode==`OPIMM    ? "opimm" :
    opcode==`OP       ? "op"    :
    opcode==`AUIPC    ? "auipc" :
    opcode==`LUI      ? "lui"   :
    opcode==`BRANCH   ? "brnch" :
    opcode==`JALR     ? "jalr"  :
    opcode==`JAL      ? "jal"   :
    opcode==`MISCMEM  ? "miscm" :
    opcode==`SYSTEM   ? "csr"   :
                        "unk";
  f3str =
    ir==`NOP          ? "-"     :
    ir==`ECALL        ? "-"     :
    ir==`MRET         ? "-"     :
    opcode==`BRANCH   ? (
      funct3==`BEQ      ? "beq"   :
      funct3==`BNE      ? "bne"   :
      funct3==`BLT      ? "blt"   :
      funct3==`BGE      ? "bge"   :
      funct3==`BLTU     ? "bltu"  :
      funct3==`BGEU     ? "bgeu"  :
                          "unk"):
    opcode==`LOAD     ? (
      funct3==`LB       ? "lb"    :
      funct3==`LH       ? "lh"    :
      funct3==`LW       ? "lw"    :
      funct3==`LBU      ? "lbu"   :
      funct3==`LHU      ? "lhu"   :
                          "unk"):
    opcode==`STORE    ? (
      funct3==`SB       ? "sb"    :
      funct3==`SH       ? "sh"    :
      funct3==`SW       ? "sw"    :
                          "unk"):
    opcode==`OPIMM || opcode==`OP ? (
      funct3==`ADD      ? (opcode[3]&&funct7[5] ? "sub" : "add"):
      funct3==`SLL      ? "sll"   :
      funct3==`SLT      ? "slt"   :
      funct3==`SLTU     ? "sltu"  :
      funct3==`XOR      ? "xor"   :
      funct3==`SRL      ? (funct7[5]==`SRL7 ? "srl" : "sra"):
      funct3==`OR       ? "or"    :
      funct3==`AND      ? "and"   :
                          "unk"):
    opcode==`MISCMEM  ? (
      funct3==`FENCE    ? "fnc"   :
      funct3==`FENCEI   ? "fnci"  :
                          "unk"):
    opcode==`SYSTEM   ? (
      funct3==`CSRRW    ? "rw"    :
      funct3==`CSRRS    ? "rs"    :
      funct3==`CSRRC    ? "rc"    :
      funct3==`CSRRWI   ? "rwi"   :
      funct3==`CSRRSI   ? "rsi"   :
      funct3==`CSRRCI   ? "rci"   :
                          "unk"):
                        "-";

  if(ir!=`NOP && p.USERD(ir))   $sformat(rdstr, "%s", REGNAME(p.RD(ir)));
  else                          rdstr = {3{SPACE}};
  if(ir!=`NOP && p.USERS1(ir))  $sformat(rs1str, "%s(h%x)", REGNAME(p.RS1(ir)), p.rrs1_fwd);
  else                          rs1str = {3+3+8{SPACE}};
  if(ir!=`NOP && p.USERS2(ir))  $sformat(rs2str, "%s(h%x)", REGNAME(p.RS2(ir)), p.rrs2_fwd);
  else                          rs2str = {3+3+8{SPACE}};
  if(ir!=`NOP && p.USEIMM(ir))  $sformat(immstr, "imm(h%x)", p.IMM(ir));
  else                          immstr = {3+3+8{SPACE}};
  if(opcode==`BRANCH || opcode==`JALR || opcode==`JAL || p.isecall || p.ismret)
    $sformat(branchstr, "branch(h%x, taken=%b, flush=%b)", p.btarget[0+:16+2], p.btaken, p.bflush);
  else
    branchstr = "";

  if(mem_oe && !mem_we)       $sformat(memstr, "dmem[h%x]",      mem_addr);
  else if(mem_oe &&  mem_we)  $sformat(memstr, "dmem[h%x] <- (h%x)", mem_addr, mem_wdata);
  else                        memstr = "";

  if(p.gpr.we)
    $sformat(wbstr, "(h%x) ->%s", p.gpr.rrd, REGNAME(p.gpr.rd));
  else
    wbstr = "";

  // display trace made with past WM stage info and current WB stage info
  $display("%0s%0s", str_em, wbstr);

  // save strings made with ExMa stage info
  $sformat(str_em, "h%x: h%x %s %s %s %s %s %s | %0s%0s",
    pc, ir, opstr, f3str,
    rdstr, rs1str, rs2str, immstr,
    branchstr, memstr);
end

function[24-1:0] REGNAME (input[5-1:0] r); REGNAME =
  //                      Saver   Description
  r===5'd00 ? "  0" : //          Hard-wired zero
  r===5'd01 ? " ra" : //  Caller  Return address
  r===5'd02 ? " sp" : //  Callee  Stack pointer
  r===5'd03 ? " gp" : //          Global pointer
  r===5'd04 ? " tp" : //          Thread pointer
  r===5'd05 ? " t0" : //  Caller  Temporaries
  r===5'd06 ? " t1" : //  Caller  "
  r===5'd07 ? " t2" : //  Caller  "
  r===5'd08 ? " s0" : //  Callee  Saved register / frame pointer
  r===5'd09 ? " s1" : //  Callee  Saved register
  r===5'd10 ? " a0" : //  Caller  Function arguments / return values
  r===5'd11 ? " a1" : //  Caller  "
  r===5'd12 ? " a2" : //  Caller  Function arguments
  r===5'd13 ? " a3" : //  Caller  "
  r===5'd14 ? " a4" : //  Caller  "
  r===5'd15 ? " a5" : //  Caller  "
  r===5'd16 ? " a6" : //  Caller  "
  r===5'd17 ? " a7" : //  Caller  "
  r===5'd18 ? " s2" : //  Callee  Saved registers
  r===5'd19 ? " s3" : //  Callee  "
  r===5'd20 ? " s4" : //  Callee  "
  r===5'd21 ? " s5" : //  Callee  "
  r===5'd22 ? " s6" : //  Callee  "
  r===5'd23 ? " s7" : //  Callee  "
  r===5'd24 ? " s8" : //  Callee  "
  r===5'd25 ? " s9" : //  Callee  "
  r===5'd26 ? "s10" : //  Callee  "
  r===5'd27 ? "s11" : //  Callee  "
  r===5'd28 ? " t3" : //  Caller  Temporaries
  r===5'd29 ? " t4" : //  Caller  "
  r===5'd30 ? " t5" : //  Caller  "
  r===5'd31 ? " t6" : //  Caller  "
              "???";
endfunction

endmodule

`default_nettype wire
