`timescale 1ns/1ps

module tb_m68k_irq_entry_assert;
  logic MCLK;
  logic CLK;
  logic VPA;
  logic BR;
  logic BGACK;
  logic DTACK;
  logic [2:0] IPL;
  logic BERR;
  logic RESET_i;
  logic HALT_i;
  logic [15:0] DATA_i;

  wire RESET_pull;
  wire HALT_pull;
  wire [15:0] DATA_o;
  wire DATA_z;
  wire E_CLK;
  wire BG;
  wire [2:0] FC;
  wire FC_z;
  wire RW;
  wire RW_z;
  wire [22:0] ADDRESS;
  wire ADDRESS_z;
  wire AS;
  wire LDS;
  wire UDS;
  wire strobe_z;

  m68kcpu dut (
    .MCLK(MCLK), .CLK(CLK), .VPA(VPA), .BR(BR), .BGACK(BGACK), .DTACK(DTACK),
    .IPL(IPL), .BERR(BERR), .RESET_i(RESET_i), .RESET_pull(RESET_pull), .HALT_i(HALT_i),
    .HALT_pull(HALT_pull), .DATA_i(DATA_i), .DATA_o(DATA_o), .DATA_z(DATA_z), .E_CLK(E_CLK),
    .BG(BG), .FC(FC), .FC_z(FC_z), .RW(RW), .RW_z(RW_z), .ADDRESS(ADDRESS), .ADDRESS_z(ADDRESS_z),
    .AS(AS), .LDS(LDS), .UDS(UDS), .strobe_z(strobe_z)
  );

  initial MCLK = 1'b0;
  initial CLK = 1'b0;
  always #1 MCLK = ~MCLK;
  always #2 CLK = ~CLK;

  integer i;
  integer seed;
  integer eclk_toggle_count;
  integer irq_window_count;
  integer ipl_change_count;
  integer fc_valid_count;
  reg prev_eclk;
  reg [2:0] prev_ipl;

  initial begin
    seed = 32'h13579bdf;
    VPA = 1'b1;
    BR = 1'b1;
    BGACK = 1'b1;
    DTACK = 1'b1;
    IPL = 3'b111;
    BERR = 1'b1;
    RESET_i = 1'b0;
    HALT_i = 1'b1;
    DATA_i = 16'h0000;

    eclk_toggle_count = 0;
    irq_window_count = 0;
    ipl_change_count = 0;
    fc_valid_count = 0;
    prev_eclk = 1'b0;
    prev_ipl = 3'b111;

    #16;
    RESET_i = 1'b1;

    for (i = 0; i < 2048; i = i + 1) begin
      // Periodic reset re-entry to revisit startup + vector fetch paths.
      if ((i % 431) == 0)
        RESET_i = 1'b0;
      else if ((i % 431) == 12)
        RESET_i = 1'b1;

      // Rotating interrupt pressure windows.
      case (i % 96)
        8, 9, 10, 11, 12, 13, 14: IPL = 3'b100;
        32, 33, 34, 35, 36, 37, 38: IPL = 3'b011;
        56, 57, 58, 59, 60, 61, 62: IPL = 3'b010;
        80, 81, 82, 83, 84, 85, 86: IPL = 3'b001;
        default: IPL = 3'b111;
      endcase

      DTACK = ((i % 9) == 0) ? 1'b0 : 1'b1;
      VPA = ((i % 37) == 5) ? 1'b0 : 1'b1;
      BR = ((i % 113) < 10) ? 1'b0 : 1'b1;
      BGACK = ((i % 113) >= 10 && (i % 113) < 18) ? 1'b0 : 1'b1;
      BERR = ((i % 257) == 127) ? 1'b0 : 1'b1;
      HALT_i = ((i % 211) == 103) ? 1'b0 : 1'b1;

      if ((ADDRESS_z == 1'b0) && !$isunknown(ADDRESS))
        DATA_i = {ADDRESS[7:0] ^ 8'h3c, ADDRESS[15:8] ^ 8'ha5};
      else
        DATA_i = $urandom(seed);

      #2;

      if (i > 40 && $isunknown({RESET_pull, HALT_pull, E_CLK, BG, FC, FC_z, RW, RW_z,
                                 ADDRESS, ADDRESS_z, AS, LDS, UDS, strobe_z, DATA_z})) begin
        $fatal(1, "X/Z on m68k control outputs at cycle %0d", i);
      end
      if (i > 40 && (DATA_z == 1'b0) && $isunknown(DATA_o)) begin
        $fatal(1, "X/Z on m68k data output while driven at cycle %0d", i);
      end

      if (i > 8 && E_CLK !== prev_eclk)
        eclk_toggle_count = eclk_toggle_count + 1;
      prev_eclk = E_CLK;

      if (IPL != 3'b111)
        irq_window_count = irq_window_count + 1;
      if (IPL != prev_ipl)
        ipl_change_count = ipl_change_count + 1;
      prev_ipl = IPL;
      if ((FC_z == 1'b0) && !$isunknown(FC))
        fc_valid_count = fc_valid_count + 1;
    end

    if (eclk_toggle_count < 96)
      $fatal(1, "Insufficient E_CLK activity (%0d)", eclk_toggle_count);
    if (irq_window_count < 32)
      $fatal(1, "Interrupt windows were not exercised enough (%0d)", irq_window_count);
    if (ipl_change_count < 16)
      $fatal(1, "Insufficient IPL transition activity (%0d)", ipl_change_count);
    if (fc_valid_count < 32)
      $fatal(1, "Insufficient FC valid activity (%0d)", fc_valid_count);

    $display("tb_m68k_irq_entry_assert: PASS");
    $finish;
  end
endmodule
