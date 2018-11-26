// opcode[6:2]
`define LOAD        5'b00000  // I-type
`define STORE       5'b01000  // S-type

`define OPIMM       5'b00100  // I-type
`define OP          5'b01100  // R-type

`define AUIPC       5'b00101  // U-type
`define LUI         5'b01101  // U-type

`define BRANCH      5'b11000  // B-type
`define JALR        5'b11001  // I-type
`define JAL         5'b11011  // J-type

`define MISCMEM     5'b00011  // NOP
`define SYSTEM      5'b11100  // I-type

// funct3 - branch
`define BEQ         3'b000
`define BNE         3'b001
`define BLT         3'b100
`define BGE         3'b101
`define BLTU        3'b110
`define BGEU        3'b111

// funct3 - load
`define LB          3'b000
`define LH          3'b001
`define LW          3'b010
`define LBU         3'b100
`define LHU         3'b101

// funct3 - store
`define SB          3'b000
`define SH          3'b001
`define SW          3'b010

// funct3 - opimm/op
`define ADD         3'b000
`define SUB         3'b000
`define SLL         3'b001
`define SLT         3'b010
`define SLTU        3'b011
`define XOR         3'b100
`define SRL         3'b101
`define SRA         3'b101
`define OR          3'b110
`define AND         3'b111

// funct3 - opimm/op
`define CSRRW       3'b001
`define CSRRS       3'b010
`define CSRRC       3'b011
`define CSRRWI      3'b101
`define CSRRSI      3'b110
`define CSRRCI      3'b111

// funct7[5:5] - opimm/op
`define ADD7        1'b0
`define SUB7        1'b1
`define SRL7        1'b0
`define SRA7        1'b1

// Whole instruction
`define NOP         {12'b0, 5'b0, `ADD, 5'b0, `OPIMM, 2'b0}

