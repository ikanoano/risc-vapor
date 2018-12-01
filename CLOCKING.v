`default_nettype none
`timescale 1ps/1ps

module GENCLK_CPU (
  input   wire      clk_in,
  input   wire      reset,
  output  wire      clk_out,
  output  wire      locked
);
wire        clk_out1;
wire        clkfbout;
wire        clkfbout_buf;

  MMCME2_ADV #(
    .BANDWIDTH            ("OPTIMIZED"),
    .CLKOUT4_CASCADE      ("FALSE"),
    .COMPENSATION         ("ZHOLD"),
    .STARTUP_WAIT         ("FALSE"),
    .DIVCLK_DIVIDE        (5),        // Devide Counter
    .CLKFBOUT_MULT_F      (50.250),   // Mult Counter
    .CLKFBOUT_PHASE       (0.000),
    .CLKFBOUT_USE_FINE_PS ("FALSE"),
    .CLKOUT0_DIVIDE_F     (8.375),    // Devider Value of clk_out1
    .CLKOUT0_PHASE        (0.000),
    .CLKOUT0_DUTY_CYCLE   (0.500),
    .CLKOUT0_USE_FINE_PS  ("FALSE"),
    .CLKIN1_PERIOD        (10.000)
  ) mmcm_adv_inst (
    .CLKFBOUT            (clkfbout),
    .CLKFBOUTB           (),
    .CLKOUT0             (clk_out1),
    .CLKOUT0B            (),
    .CLKOUT1             (),
    .CLKOUT1B            (),
    .CLKOUT2             (),
    .CLKOUT2B            (),
    .CLKOUT3             (),
    .CLKOUT3B            (),
    .CLKOUT4             (),
    .CLKOUT5             (),
    .CLKOUT6             (),
    // Input clock control
    .CLKFBIN             (clkfbout_buf),
    .CLKIN1              (clk_in),
    .CLKIN2              (1'b0),
    // Tied to always select the primary input clock
    .CLKINSEL            (1'b1),
    // Ports for dynamic reconfiguration
    .DADDR               (7'h0),
    .DCLK                (1'b0),
    .DEN                 (1'b0),
    .DI                  (16'h0),
    .DO                  (),
    .DRDY                (),
    .DWE                 (1'b0),
    // Ports for dynamic phase shift
    .PSCLK               (1'b0),
    .PSEN                (1'b0),
    .PSINCDEC            (1'b0),
    .PSDONE              (),
    // Other control and status signals
    .LOCKED              (locked),
    .CLKINSTOPPED        (),
    .CLKFBSTOPPED        (),
    .PWRDWN              (1'b0),
    .RST                 (reset)
  );

  BUFG clkf_buf (.O(clkfbout_buf), .I (clkfbout));
  BUFG clkout_buf (.O(clk_out), .I(clk_out1));

endmodule

module GENCLK_REF (
  input   wire      clk_in,
  input   wire      reset,
  output  wire      clk_out,
  output  wire      locked
);
  wire        clk_out1;
  wire        clkfbout;
  wire        clkfbout_buf;

  PLLE2_ADV #(
    .BANDWIDTH            ("OPTIMIZED"),
    .COMPENSATION         ("ZHOLD"),
    .STARTUP_WAIT         ("FALSE"),
    .DIVCLK_DIVIDE        (1),
    .CLKFBOUT_MULT        (10),
    .CLKFBOUT_PHASE       (0.000),
    .CLKOUT0_DIVIDE       (5),
    .CLKOUT0_PHASE        (0.000),
    .CLKOUT0_DUTY_CYCLE   (0.500),
    .CLKIN1_PERIOD        (10.000)
  ) plle2_adv_inst (
    .CLKFBOUT            (clkfbout),
    .CLKOUT0             (clk_out1),
    .CLKOUT1             (),
    .CLKOUT2             (),
    .CLKOUT3             (),
    .CLKOUT4             (),
    .CLKOUT5             (),
    // Input clock control
    .CLKFBIN             (clkfbout_buf),
    .CLKIN1              (clk_in),
    .CLKIN2              (1'b0),
    // Tied to always select the primary input clock
    .CLKINSEL            (1'b1),
    // Ports for dynamic reconfiguration
    .DADDR               (7'h0),
    .DCLK                (1'b0),
    .DEN                 (1'b0),
    .DI                  (16'h0),
    .DO                  (),
    .DRDY                (),
    .DWE                 (1'b0),
    // Other control and status signals
    .LOCKED              (locked),
    .PWRDWN              (1'b0),
    .RST                 (reset)
  );
  BUFG clkf_buf(.O (clkfbout_buf), .I (clkfbout));
  BUFG clkout1_buf (.O(clk_out), .I(clk_out1));
endmodule

`default_nettype wire
