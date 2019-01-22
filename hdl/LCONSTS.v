`include "INST.v"

// Stage number
localparam  IF = 0, ID = 1, EM = 2, WB = 3;

// Instrunction parsers
function[ 5-1:0]  OPCODE(input[32-1:0] inst); OPCODE  = inst[ 6: 2]; endfunction
function[ 5-1:0]  RD    (input[32-1:0] inst); RD      = inst[11: 7]; endfunction
function[ 5-1:0]  RS1   (input[32-1:0] inst); RS1     = inst[19:15]; endfunction
function[ 5-1:0]  RS2   (input[32-1:0] inst); RS2     = inst[24:20]; endfunction
function[ 3-1:0]  FUNCT3(input[32-1:0] inst); FUNCT3  = inst[14:12]; endfunction
function[ 7-1:0]  FUNCT7(input[32-1:0] inst); FUNCT7  = inst[31:25]; endfunction

function[32-1:0]  IIMM  (input[32-1:0] inst); IIMM    = {{21{inst[31]}},                           inst[30:25],inst[24:21],inst[20]}; endfunction
function[32-1:0]  SIMM  (input[32-1:0] inst); SIMM    = {{21{inst[31]}},                           inst[30:25],inst[11: 8],inst[ 7]}; endfunction
function[32-1:0]  BIMM  (input[32-1:0] inst); BIMM    = {{20{inst[31]}},                  inst[ 7],inst[30:25],inst[11: 8],    1'b0}; endfunction
function[32-1:0]  UIMM  (input[32-1:0] inst); UIMM    = {inst[31],inst[30:20],inst[19:12],                                    12'b0}; endfunction
function[32-1:0]  JIMM  (input[32-1:0] inst); JIMM    = {{12{inst[31]}},      inst[19:12],inst[20],inst[30:25],inst[24:21],    1'b0}; endfunction
function[32-1:0]  IMM   (input[32-1:0] inst); IMM     =
  OPCODE(inst)==`STORE  ? SIMM(inst)  :
  OPCODE(inst)==`BRANCH ? BIMM(inst)  :
  OPCODE(inst)==`AUIPC  ? UIMM(inst)  :
  OPCODE(inst)==`LUI    ? UIMM(inst)  :
  OPCODE(inst)==`JAL    ? JIMM(inst)  :
                          IIMM(inst);
endfunction

// Is this inst assert OE or WE?
function[   0:0]  GPRWE (input[32-1:0] inst); GPRWE  =  // gpr write enable
  RD(inst)!=5'd0 && OPCODE(inst)!=`STORE && OPCODE(inst)!=`BRANCH;
endfunction
function[ 4-1:0]  MEMOE (input[32-1:0] inst); MEMOE  =  // mem output enable
  OPCODE(inst)!=`LOAD   ? MEMWE(inst) : // not store
  FUNCT3(inst)==`LB     ? 4'b0001 :
  FUNCT3(inst)==`LH     ? 4'b0011 :
  FUNCT3(inst)==`LW     ? 4'b1111 :
  FUNCT3(inst)==`LBU    ? 4'b0001 :
  FUNCT3(inst)==`LHU    ? 4'b0011 :
                          4'bxxxx;
endfunction
function[ 4-1:0]  MEMWE (input[32-1:0] inst); MEMWE  =  // mem write enable
  OPCODE(inst)!=`STORE  ? 4'b0000 : // not store
  FUNCT3(inst)==`SB     ? 4'b0001 :
  FUNCT3(inst)==`SH     ? 4'b0011 :
  FUNCT3(inst)==`SW     ? 4'b1111 :
                          4'bxxxx;
endfunction

// Is this inst uses RD, RS1, RS2, or IMMEDIATE?
function[ 1-1:0]  USERD (input[32-1:0] inst); USERD  =
  OPCODE(inst)!=`STORE  &&
  OPCODE(inst)!=`BRANCH &&
  OPCODE(inst)!=`MISCMEM;
endfunction
function[ 1-1:0]  USERS1(input[32-1:0] inst); USERS1 =
  OPCODE(inst)!=`AUIPC  &&
  OPCODE(inst)!=`LUI    &&
  OPCODE(inst)!=`JAL    &&
  OPCODE(inst)!=`MISCMEM;
  //OPCODE(inst)==`SYSTEM && (...);  TUNE: some functs in SYSTEM don't use RS1
endfunction
function[ 1-1:0]  USERS2(input[32-1:0] inst); USERS2 =
  OPCODE(inst)==`STORE  ||
  OPCODE(inst)==`OP     ||
  OPCODE(inst)==`BRANCH;
endfunction
function[ 1-1:0]  USEIMM(input[32-1:0] inst); USEIMM =
  OPCODE(inst)!=`OP     &&
  OPCODE(inst)!=`MISCMEM;
endfunction

// Is this inst cause control transfer?
function[ 1-1:0]  CTRLXFER(input[32-1:0] inst); CTRLXFER =
  OPCODE(inst)==`JAL    ||
  OPCODE(inst)==`JALR   ||
  OPCODE(inst)==`BRANCH;
endfunction

// Extend a value loaded from the memory
function[32-1:0]  LOADEXT(input[32-1:0] inst, input[32-1:0] ledata);  LOADEXT =
  FUNCT3(inst)==`LB   ? {{24{ledata[ 7]}}, ledata[0+: 8]} :
  FUNCT3(inst)==`LH   ? {{16{ledata[15]}}, ledata[0+:16]} :
  FUNCT3(inst)==`LW   ?                    ledata[0+:32]  :
  FUNCT3(inst)==`LBU  ? {{24{      1'b0}}, ledata[0+: 8]} :
  FUNCT3(inst)==`LHU  ? {{16{      1'b0}}, ledata[0+:16]} :
                        32'hxxxxxxxx;
endfunction

// Return the name in string
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
function[40-1:0] OPNAME (input[32-1:0] inst); OPNAME =
  inst==`NOP              ? "nop"   :
  inst==`ECALL            ? "ecall" :
  inst==`MRET             ? "mret"  :
  OPCODE(inst)==`LOAD     ? "load"  :
  OPCODE(inst)==`STORE    ? "store" :
  OPCODE(inst)==`OPIMM    ? "opimm" :
  OPCODE(inst)==`OP       ? "op"    :
  OPCODE(inst)==`AUIPC    ? "auipc" :
  OPCODE(inst)==`LUI      ? "lui"   :
  OPCODE(inst)==`BRANCH   ? "brnch" :
  OPCODE(inst)==`JALR     ? "jalr"  :
  OPCODE(inst)==`JAL      ? "jal"   :
  OPCODE(inst)==`MISCMEM  ? "miscm" :
  OPCODE(inst)==`SYSTEM   ? "csr"   :
                            "unk";
endfunction
function[32-1:0] FUNCTNAME (input[32-1:0] inst);
  reg [5-1:0] opcode;
  reg [3-1:0] funct3;
  reg [7-1:0] funct7;
  begin
    opcode  = OPCODE(inst);
    funct3  = FUNCT3(inst);
    funct7  = FUNCT7(inst);
    FUNCTNAME  =
      inst==`NOP        ? "-"     :
      inst==`ECALL      ? "-"     :
      inst==`MRET       ? "-"     :
      opcode==`BRANCH   ? (
        funct3==`BEQ      ? "beq"   :
        funct3==`BNE      ? "bne"   :
        funct3==`BLT      ? "blt"   :
        funct3==`BGE      ? "bge"   :
        funct3==`BLTU     ? "bltu"  :
        funct3==`BGEU     ? "bgeu"  :
                            "unkb"):
      opcode==`LOAD     ? (
        funct3==`LB       ? "lb"    :
        funct3==`LH       ? "lh"    :
        funct3==`LW       ? "lw"    :
        funct3==`LBU      ? "lbu"   :
        funct3==`LHU      ? "lhu"   :
                            "unkl"):
      opcode==`STORE    ? (
        funct3==`SB       ? "sb"    :
        funct3==`SH       ? "sh"    :
        funct3==`SW       ? "sw"    :
                            "unks"):
      opcode==`OPIMM || opcode==`OP ? (
        funct3==`ADD      ? (opcode[3]&&funct7[5] ? "sub" : "add"):
        funct3==`SLL      ? "sll"   :
        funct3==`SLT      ? "slt"   :
        funct3==`SLTU     ? "sltu"  :
        funct3==`XOR      ? "xor"   :
        funct3==`SRL      ? (funct7[5]==`SRL7 ? "srl" : "sra"):
        funct3==`OR       ? "or"    :
        funct3==`AND      ? "and"   :
                            "unko"):
      opcode==`MISCMEM  ? (
        funct3==`FENCE    ? "fnc"   :
        funct3==`FENCEI   ? "fnci"  :
                            "unkm"):
      opcode==`SYSTEM   ? (
        funct3==`CSRRW    ? "rw"    :
        funct3==`CSRRS    ? "rs"    :
        funct3==`CSRRC    ? "rc"    :
        funct3==`CSRRWI   ? "rwi"   :
        funct3==`CSRRSI   ? "rsi"   :
        funct3==`CSRRCI   ? "rci"   :
                            "unks"):
                          "-";
  end
endfunction

