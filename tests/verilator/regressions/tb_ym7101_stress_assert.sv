`timescale 1ns/1ps

module tb_ym7101_stress_assert;
  logic MCLK;
  logic [7:0] SD;
  logic [7:0] RD_i;
  logic [7:0] AD_i;
  logic SPA_B_i;
  logic CSYNC_i;
  logic HSYNC_i;
  logic HL;
  logic SEL0;
  logic PAL;
  logic RESET;
  logic CLK1_i;
  logic MCLK_e;
  logic EDCLK_i;
  logic [15:0] CD_i;
  logic [22:0] CA_i;
  logic BGACK_i;
  logic BG;
  logic MREQ;
  logic INTAK;
  logic IORQ;
  logic RD;
  logic WR;
  logic M1;
  logic AS;
  logic UDS;
  logic LDS;
  logic RW;
  logic DTACK_i;
  logic ext_test_2;
  logic vdp_cramdot_dis;

  wire SE1;
  wire SE0;
  wire SC;
  wire RAS1;
  wire CAS1;
  wire WE1;
  wire WE0;
  wire OE1;
  wire [7:0] RD_o;
  wire RD_d;
  wire [7:0] DAC_R;
  wire [7:0] DAC_G;
  wire [7:0] DAC_B;
  wire [7:0] AD_o;
  wire AD_d;
  wire YS;
  wire SPA_B_pull;
  wire VSYNC;
  wire CSYNC_pull;
  wire HSYNC_pull;
  wire CLK1_o;
  wire SBCR;
  wire CLK0;
  wire EDCLK_o;
  wire EDCLK_d;
  wire [15:0] CD_o;
  wire CD_d;
  wire [22:0] CA_o;
  wire CA_d;
  wire [15:0] SOUND;
  wire INT_pull;
  wire BR_pull;
  wire BGACK_pull;
  wire IPL1_pull;
  wire IPL2_pull;
  wire DTACK_pull;
  wire UWR;
  wire LWR;
  wire OE0;
  wire CAS0;
  wire RAS0;
  wire [7:0] RA;
  wire vdp_hclk1;
  wire vdp_intfield;
  wire vdp_de_h;
  wire vdp_de_v;
  wire vdp_m5;
  wire vdp_rs1;
  wire vdp_m2;
  wire vdp_lcb;
  wire vdp_psg_clk1;
  wire vdp_hsync2;
  wire vdp_dma_oe_early;
  wire vdp_dma;

  ym7101 dut (
    .MCLK(MCLK), .SD(SD), .SE1(SE1), .SE0(SE0), .SC(SC), .RAS1(RAS1), .CAS1(CAS1), .WE1(WE1), .WE0(WE0),
    .OE1(OE1), .RD_i(RD_i), .RD_o(RD_o), .RD_d(RD_d), .DAC_R(DAC_R), .DAC_G(DAC_G), .DAC_B(DAC_B), .AD_i(AD_i),
    .AD_o(AD_o), .AD_d(AD_d), .YS(YS), .SPA_B_i(SPA_B_i), .SPA_B_pull(SPA_B_pull), .VSYNC(VSYNC), .CSYNC_i(CSYNC_i),
    .CSYNC_pull(CSYNC_pull), .HSYNC_i(HSYNC_i), .HSYNC_pull(HSYNC_pull), .HL(HL), .SEL0(SEL0), .PAL(PAL), .RESET(RESET),
    .CLK1_i(CLK1_i), .CLK1_o(CLK1_o), .SBCR(SBCR), .CLK0(CLK0), .MCLK_e(MCLK_e), .EDCLK_i(EDCLK_i), .EDCLK_o(EDCLK_o),
    .EDCLK_d(EDCLK_d), .CD_i(CD_i), .CD_o(CD_o), .CD_d(CD_d), .CA_i(CA_i), .CA_o(CA_o), .CA_d(CA_d), .SOUND(SOUND),
    .INT_pull(INT_pull), .BR_pull(BR_pull), .BGACK_i(BGACK_i), .BGACK_pull(BGACK_pull), .BG(BG), .MREQ(MREQ), .INTAK(INTAK),
    .IPL1_pull(IPL1_pull), .IPL2_pull(IPL2_pull), .IORQ(IORQ), .RD(RD), .WR(WR), .M1(M1), .AS(AS), .UDS(UDS), .LDS(LDS),
    .RW(RW), .DTACK_i(DTACK_i), .DTACK_pull(DTACK_pull), .UWR(UWR), .LWR(LWR), .OE0(OE0), .CAS0(CAS0), .RAS0(RAS0), .RA(RA),
    .ext_test_2(ext_test_2), .vdp_hclk1(vdp_hclk1), .vdp_intfield(vdp_intfield), .vdp_de_h(vdp_de_h), .vdp_de_v(vdp_de_v),
    .vdp_m5(vdp_m5), .vdp_rs1(vdp_rs1), .vdp_m2(vdp_m2), .vdp_lcb(vdp_lcb), .vdp_psg_clk1(vdp_psg_clk1), .vdp_hsync2(vdp_hsync2),
    .vdp_cramdot_dis(vdp_cramdot_dis), .vdp_dma_oe_early(vdp_dma_oe_early), .vdp_dma(vdp_dma)
  );

  initial MCLK = 1'b0;
  initial CLK1_i = 1'b0;
  initial MCLK_e = 1'b0;
  initial EDCLK_i = 1'b0;
  always #1 MCLK = ~MCLK;
  always #2 CLK1_i = ~CLK1_i;
  always #3 MCLK_e = ~MCLK_e;
  always #5 EDCLK_i = ~EDCLK_i;

  integer i;
  integer seed;
  integer clk0_toggle_count;
  integer logic_toggle_count;
  reg prev_clk0;
  reg [4:0] prev_logic_obs;
  reg [4:0] logic_obs;

  initial begin
    seed = 32'h27182818;
    SD = 8'h00;
    RD_i = 8'h00;
    AD_i = 8'h00;
    SPA_B_i = 1'b1;
    CSYNC_i = 1'b1;
    HSYNC_i = 1'b1;
    HL = 1'b0;
    SEL0 = 1'b0;
    PAL = 1'b0;
    RESET = 1'b0;
    CD_i = 16'h0000;
    CA_i = 23'h0;
    BGACK_i = 1'b1;
    BG = 1'b1;
    MREQ = 1'b1;
    INTAK = 1'b1;
    IORQ = 1'b1;
    RD = 1'b1;
    WR = 1'b1;
    M1 = 1'b1;
    AS = 1'b1;
    UDS = 1'b1;
    LDS = 1'b1;
    RW = 1'b1;
    DTACK_i = 1'b1;
    ext_test_2 = 1'b0;
    vdp_cramdot_dis = 1'b0;

    clk0_toggle_count = 0;
    logic_toggle_count = 0;
    prev_clk0 = 1'b0;
    prev_logic_obs = 5'h0;

    #20;
    RESET = 1'b1;

    for (i = 0; i < 768; i = i + 1) begin
      if ((i % 211) == 0)
        RESET = 1'b0;
      else if ((i % 211) == 8)
        RESET = 1'b1;

      SD = $urandom(seed);
      RD_i = $urandom(seed);
      AD_i = $urandom(seed);
      SPA_B_i = $urandom(seed);
      HL = $urandom(seed);
      SEL0 = $urandom(seed);
      PAL = $urandom(seed);
      CD_i = $urandom(seed);
      CA_i = $urandom(seed);
      BGACK_i = $urandom(seed);
      BG = $urandom(seed);
      MREQ = $urandom(seed);
      INTAK = $urandom(seed);
      IORQ = $urandom(seed);
      RD = $urandom(seed);
      WR = $urandom(seed);
      M1 = $urandom(seed);
      AS = $urandom(seed);
      UDS = $urandom(seed);
      LDS = $urandom(seed);
      RW = $urandom(seed);
      DTACK_i = $urandom(seed);
      ext_test_2 = $urandom(seed);
      vdp_cramdot_dis = $urandom(seed);

      // Keep sync-style inputs active with a deterministic cadence.
      CSYNC_i = ((i % 24) < 12);
      HSYNC_i = ((i % 16) < 8);

      #2;

      if (i > 48 && $isunknown({SE1, SE0, SC, RAS1, CAS1, WE1, WE0, OE1, RD_o, RD_d, DAC_R, DAC_G, DAC_B,
                                 AD_o, AD_d, YS, SPA_B_pull, VSYNC, CSYNC_pull, HSYNC_pull, CLK1_o, SBCR, CLK0,
                                 EDCLK_o, EDCLK_d, CD_o, CD_d, CA_o, CA_d, SOUND, INT_pull, BR_pull, BGACK_pull,
                                 IPL1_pull, IPL2_pull, DTACK_pull, UWR, LWR, OE0, CAS0, RAS0, RA, vdp_hclk1,
                                 vdp_intfield, vdp_de_h, vdp_de_v, vdp_m5, vdp_rs1, vdp_m2, vdp_lcb, vdp_psg_clk1,
                                 vdp_hsync2, vdp_dma_oe_early, vdp_dma})) begin
        $fatal(1, "X/Z on ym7101 outputs at cycle %0d", i);
      end

      if (i > 8 && CLK0 !== prev_clk0)
        clk0_toggle_count = clk0_toggle_count + 1;
      prev_clk0 = CLK0;

      logic_obs = {CLK1_o, EDCLK_o, vdp_hclk1, vdp_psg_clk1, CLK0};
      if (i > 8 && logic_obs !== prev_logic_obs)
        logic_toggle_count = logic_toggle_count + 1;
      prev_logic_obs = logic_obs;
    end

    if (clk0_toggle_count < 24)
      $fatal(1, "CLK0 did not toggle enough (%0d)", clk0_toggle_count);

    if (logic_toggle_count < 24)
      $fatal(1, "Insufficient ym7101 logic activity (%0d)", logic_toggle_count);

    $display("tb_ym7101_stress_assert: PASS");
    $finish;
  end
endmodule
