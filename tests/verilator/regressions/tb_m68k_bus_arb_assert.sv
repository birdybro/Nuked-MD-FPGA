`timescale 1ns/1ps

module tb_m68k_bus_arb_assert;
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
  integer bg_toggle_count;
  integer eclk_toggle_count;
  reg prev_bg;
  reg prev_eclk;

  initial begin
    seed = 32'h6d2b79f5;
    VPA = 1'b1;
    BR = 1'b1;
    BGACK = 1'b1;
    DTACK = 1'b1;
    IPL = 3'b111;
    BERR = 1'b1;
    RESET_i = 1'b0;
    HALT_i = 1'b1;
    DATA_i = 16'h0000;

    bg_toggle_count = 0;
    eclk_toggle_count = 0;
    prev_bg = 1'b0;
    prev_eclk = 1'b0;

    #16;
    RESET_i = 1'b1;

    for (i = 0; i < 1536; i = i + 1) begin
      // Re-enter startup and arbitration paths periodically.
      if ((i % 383) == 0)
        RESET_i = 1'b0;
      else if ((i % 383) == 10)
        RESET_i = 1'b1;

      BR = ((i % 97) < 14) ? 1'b0 : 1'b1;
      BGACK = ((i % 97) >= 14 && (i % 97) < 26) ? 1'b0 : 1'b1;
      DTACK = ((i % 7) == 0) ? 1'b0 : 1'b1;
      VPA = ((i % 19) < 3) ? 1'b0 : 1'b1;
      BERR = ((i % 211) == 23) ? 1'b0 : 1'b1;
      HALT_i = ((i % 173) == 67) ? 1'b0 : 1'b1;

      case (i % 41)
        0: IPL = 3'b000;
        1, 2, 3: IPL = 3'b001;
        4, 5, 6: IPL = 3'b010;
        7, 8, 9: IPL = 3'b011;
        10, 11: IPL = 3'b100;
        12, 13: IPL = 3'b101;
        default: IPL = 3'b111;
      endcase

      if ((ADDRESS_z == 1'b0) && !$isunknown(ADDRESS))
        DATA_i = {ADDRESS[7:0] ^ 8'ha5, ADDRESS[15:8] ^ 8'h3c};
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

      if (i > 8 && BG !== prev_bg)
        bg_toggle_count = bg_toggle_count + 1;
      prev_bg = BG;

      if (i > 8 && E_CLK !== prev_eclk)
        eclk_toggle_count = eclk_toggle_count + 1;
      prev_eclk = E_CLK;

    end

    if (bg_toggle_count < 8)
      $fatal(1, "Insufficient BG arbitration activity (%0d)", bg_toggle_count);
    if (eclk_toggle_count < 64)
      $fatal(1, "Insufficient E_CLK activity (%0d)", eclk_toggle_count);

    $display("tb_m68k_bus_arb_assert: PASS");
    $finish;
  end
endmodule
