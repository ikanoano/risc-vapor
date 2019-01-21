`default_nettype none
`timescale 1ns/100ps
`include "INST.v"

// Top module for simulation
module TOP_SIM ();
localparam  ISCALE  = 16-2; // 64KB  (16K word)
localparam  DSCALE  = 27-2; // 128MB (32M word)
localparam  IMAGESCALE  = (9+10)-2; // 512KB (128K word)
reg clk=0, rst=0;

// runtime parameter
integer         MAX_CYCLE;
integer         TRACE;
integer         DUMP;
integer         TIME;
integer         PLOAD;
reg [256*8-1:0] IMAGE;
initial begin
  if(!$value$plusargs("MAX_CYCLE=%d", MAX_CYCLE))     MAX_CYCLE=100000;
  if(!$value$plusargs("TRACE=%d", TRACE))             TRACE=0;
  if(!$value$plusargs("IMAGE=%s", IMAGE))             IMAGE="image";
  if(!$value$plusargs("DUMP=%d", DUMP))               DUMP=0;
  if(!$value$plusargs("TIME=%d", TIME))               TIME=0;
  if(!$value$plusargs("PLOAD=%d", PLOAD))             PLOAD=0;
  $display("MAX_CYCLE   = %0d", MAX_CYCLE);
  $display("TRACE       = %0d", TRACE);
  $display("DUMP        = %0d", DUMP);
  $display("IMAGE       = %0s", IMAGE);
  $display("TIME        = %0d", TIME);
  $display("PLOAD       = %0d", PLOAD);
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
  #10
  rst = 1;
  #520;
  $display("deassert reset");
  rst = 0;
end

// cycle
wire[64-1:0]  cycle = {n4.p.csr.mcycleh, n4.p.csr.mcycle};
always @(posedge clk) begin
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
`ifdef IVERILOG
    $dumpvars(1, n4.p.pc[0], n4.p.pc[1], n4.p.pc[2], n4.p.pc[3]);
    $dumpvars(1,             n4.p.ir[1], n4.p.ir[2], n4.p.ir[3]);
    $dumpvars(1, n4.p, n4.p.gpr, n4.p.bp);
    $dumpvars(1, n4.dc);
    $display("iverilog");
`endif
    $dumpvars(1, n4);
  end
end

// load image
integer       fd, dummy, i;
reg [32-1:0]  fdata;
wire          prog_ready;
reg           prog_we=0;
reg [ 8-1:0]  prog_data=0;
initial begin
  #1
  fd = $fopen(IMAGE, "rb");
  if(!fd) begin $display("failed to open image: %0s", IMAGE); $finish(); end
  if(PLOAD) begin
    // simulate program loading using uart
    $display("load program using uart: %0s", IMAGE);
    while(!rst) @(posedge clk);
    while(rst)  @(posedge clk);
    repeat(16)  @(posedge clk);
    prog_we   = 1'b1;
    for(i=0; i<2**IMAGESCALE; i=i+1) begin
      if(!i[0+:10]) begin
        $write(" %3dk(h%6x,%b)", i>>10, n4.pl.waddr, n4.pl.DONE);
        $fflush();
      end
      dummy = $fread(fdata, fd);
      prog_data = fdata[24+:8]; @(posedge prog_ready); @(posedge clk);
      prog_data = fdata[16+:8]; @(posedge prog_ready); @(posedge clk);
      prog_data = fdata[ 8+:8]; @(posedge prog_ready); @(posedge clk);
      prog_data = fdata[ 0+:8]; @(posedge prog_ready); @(posedge clk);
    end
    prog_we   = 1'b0;
    while(!n4.pl.DONE) begin
      @(posedge clk) $write("(%6x, %b)", n4.pl.waddr, n4.pl.DONE);
    end
    $display("");
  end else begin
    // load program directly from an image file
    $display("load program directly: %0s", IMAGE);

    for(i=0; i<2**ISCALE; i=i+1) begin
      dummy = $fread(fdata, fd);
      n4.imem.ram[i] = {fdata[0+:8], fdata[8+:8],  fdata[16+:8], fdata[24+:8]};
    end

    dummy = $rewind(fd);

    for(i=0; i<2**IMAGESCALE && !$feof(fd); i=i+1) begin
      dummy = $fread(fdata, fd);
      n4.dram.mb.slv_reg[i] = {fdata[0+:8], fdata[8+:8],  fdata[16+:8], fdata[24+:8]};
    end

    force n4.pl.DONE = 1;
  end
  $display("done");
end

localparam SERIAL_WCNT = 2;
wire  prog_txd;
UARTTX #(.SERIAL_WCNT(SERIAL_WCNT)) sender (
  .CLK(clk),
  .RST_X(~rst),
  .WE(prog_we),
  .DATA(prog_data),
  .TXD(prog_txd),
  .READY(prog_ready)
);
defparam  n4.ut.SERIAL_WCNT = SERIAL_WCNT;
defparam  n4.pl.serc.SERIAL_WCNT = SERIAL_WCNT;


// cpu on nexys4 ddr
TOP_NEXYS4DDR n4 (
  .clk100mhz(clk),
  .cpu_resetn(~rst),
  .btn(5'h0),
  .sw(16'h0),
  .uart_rxd(prog_txd)
);

// peep the memory mapped IO
wire          mmio_oe = n4.mmio_oe;
wire[ 4-1:0]  mmio_we = n4.mmio_we;
real          stat_tmp;
always @(posedge clk) begin
  if(mmio_oe && mmio_we[0]) begin  // write
    case (n4.mem_addr)
      32'hf0000000: begin
        $display("Halt!");
        $display("a0 was %x", n4.p.gpr.r[10]);
        stat_tmp = $bitstoreal(LONG(n4.bp_cnt_hit))/$bitstoreal(LONG(n4.bp_cnt_pred));
        $display("branch predictor hit/pred   = %10d/%10d = %7.3f",
          n4.bp_cnt_hit, n4.bp_cnt_pred, stat_tmp);
        stat_tmp = $bitstoreal(LONG(n4.dc_cnt_hit))/$bitstoreal(LONG(n4.dc_cnt_access));
        $display("daca cache       hit/access = %10d/%10d = %7.3f",
          n4.dc_cnt_hit, n4.dc_cnt_access, stat_tmp);
        $finish();
      end
      32'hf0000100: begin
        if(TRACE) begin $display("output: %s", n4.mem_wdata[0+:8]); $fflush(); end
        else      begin $write("%s", n4.mem_wdata[0+:8]); $fflush(); end
      end
      default : begin end
    endcase
  end
  if(mmio_oe && !mmio_we[0]) begin // read
    case (n4.mem_addr)
      // return non zero when TX is available (always available in testbench)
      32'hf0000100: begin  end
      default     : begin  end
    endcase
  end
end

function[64-1:0]  LONG(input[32-1:0] short);
  LONG = {32'h0, short};
endfunction

// assertion
always @(posedge clk) begin
  if(!rst && (n4.imem_oe && |n4.imem_addr[1:0])) begin
    $display("Error: read imem with non-aligned addr: %x", n4.imem_addr);
    $finish();
  end

  if(!rst && ^{n4.p.stall, n4.p.insertb}===1'bx) begin
    $display("Error: contains X or Z in stall(b%b) or insertb(b%b)",
      n4.p.stall, n4.p.insertb);
  end
end

// trace output
localparam[8-1:0] SPACE = " ";
reg [     3:0] stall;
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
reg [32*8-1:0]  storestr;
reg [32*8-1:0]  loadstr;
reg [32*8-1:0]  stallstr;
reg [128*8-1:0] str_em="";
reg [32*8-1:0]  wbstr;
always @(posedge clk) if(TRACE && !rst) begin : trace
  stall   = n4.p.stall;
  if(|stall)      $sformat(stallstr, "s(b%b)", stall);
  else            stallstr = "";
  //if(|n4.p.insertb)  $sformat(ibstr, "b(b%b)", n4.p.insertb);
  //else            ibstr = "";
  if(TIME) $write("%8d ", $time);
  $write("%8s | ", stallstr);
  if(TRACE && n4.dram.reading) $write("reading dram");
  if(stall[n4.p.WB]) begin
    $display("");
    disable trace;  // early return
  end

  pc      = n4.p.pc[n4.p.EM][0+:16];
  ir      = n4.p.ir[n4.p.EM];
  opcode  = n4.p.OPCODE(ir);
  funct3  = n4.p.FUNCT3(ir);
  funct7  = n4.p.FUNCT7(ir);
  imm     = n4.p.IMM(ir);
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

  if(ir!=`NOP && n4.p.USERD(ir))  $sformat(rdstr, "%s", REGNAME(n4.p.RD(ir)));
  else                            rdstr = {3{SPACE}};
  if(ir!=`NOP && n4.p.USERS1(ir)) $sformat(rs1str, "%s(h%x)", REGNAME(n4.p.RS1(ir)), n4.p.rrs1_fwd);
  else                            rs1str = {3+3+8{SPACE}};
  if(ir!=`NOP && n4.p.USERS2(ir)) $sformat(rs2str, "%s(h%x)", REGNAME(n4.p.RS2(ir)), n4.p.rrs2_fwd);
  else                            rs2str = {3+3+8{SPACE}};
  if(ir!=`NOP && n4.p.USEIMM(ir)) $sformat(immstr, "imm(h%x)", n4.p.IMM(ir));
  else                            immstr = {3+3+8{SPACE}};
  if(opcode==`BRANCH || opcode==`JALR || opcode==`JAL || n4.p.isecall || n4.p.ismret)
    $sformat(branchstr, "branch(h%x, taken=%b, flush=%b)", n4.p.btarget[0+:16+2], n4.p.btaken, n4.p.bflush);
  else
    branchstr = "";

  if(n4.p.pre_mem_we[0]) begin
    $sformat(storestr, "dmem[h%x] <- (h%x)", n4.p.pre_mem_addr, n4.p.pre_mem_wdata);
  end else begin
    storestr = "";
  end

  if(n4.p.pre_mem_oe[0] && !n4.p.pre_mem_we[0]) begin
    $sformat(loadstr, "dmem[h%x]", n4.p.pre_mem_addr);
  end else begin
    loadstr = "";
  end

  if(!n4.p.prev_insertb[n4.p.EM]) begin  // skip if instruction in WB is bubble
    if(n4.p.gpr.we)
      $sformat(wbstr, "(h%x) ->%s", n4.p.gpr.rrd, REGNAME(n4.p.gpr.rd));
    else
      wbstr = "";

    // display trace made with past WM stage info and current WB stage info
    $display("%0s%0s", str_em, wbstr);
  end else begin
    $display("bubble");
  end

  // save strings made with ExMa stage info
  $sformat(str_em, "h%x: h%x %s %s %s %s %s %s | %0s%0s%0s",
    pc, ir, opstr, f3str,
    rdstr, rs1str, rs2str, immstr,
    branchstr, storestr, loadstr);
end

function[24-1:0] REGNAME (input[5-1:0] r); REGNAME =
  //                      Saver   | Description
  r===5'd00 ? "  0" : //          | Hard-wired zero
  r===5'd01 ? " ra" : //  Caller  | Return address
  r===5'd02 ? " sp" : //  Callee  | Stack pointer
  r===5'd03 ? " gp" : //          | Global pointer
  r===5'd04 ? " tp" : //          | Thread pointer
  r===5'd05 ? " t0" : //  Caller  | Temporaries
  r===5'd06 ? " t1" : //  Caller  | "
  r===5'd07 ? " t2" : //  Caller  | "
  r===5'd08 ? " s0" : //  Callee  | Saved register / frame pointer
  r===5'd09 ? " s1" : //  Callee  | Saved register
  r===5'd10 ? " a0" : //  Caller  | Function arguments / return values
  r===5'd11 ? " a1" : //  Caller  | "
  r===5'd12 ? " a2" : //  Caller  | Function arguments
  r===5'd13 ? " a3" : //  Caller  | "
  r===5'd14 ? " a4" : //  Caller  | "
  r===5'd15 ? " a5" : //  Caller  | "
  r===5'd16 ? " a6" : //  Caller  | "
  r===5'd17 ? " a7" : //  Caller  | "
  r===5'd18 ? " s2" : //  Callee  | Saved registers
  r===5'd19 ? " s3" : //  Callee  | "
  r===5'd20 ? " s4" : //  Callee  | "
  r===5'd21 ? " s5" : //  Callee  | "
  r===5'd22 ? " s6" : //  Callee  | "
  r===5'd23 ? " s7" : //  Callee  | "
  r===5'd24 ? " s8" : //  Callee  | "
  r===5'd25 ? " s9" : //  Callee  | "
  r===5'd26 ? "s10" : //  Callee  | "
  r===5'd27 ? "s11" : //  Callee  | "
  r===5'd28 ? " t3" : //  Caller  | Temporaries
  r===5'd29 ? " t4" : //  Caller  | "
  r===5'd30 ? " t5" : //  Caller  | "
  r===5'd31 ? " t6" : //  Caller  | "
              "zzz";
endfunction

endmodule

`default_nettype wire
