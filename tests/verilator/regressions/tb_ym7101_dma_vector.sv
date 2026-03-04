`timescale 1ns/1ps

module tb_ym7101_dma_vector;
  localparam integer VEC_WIDTH = 86;
  localparam integer VEC_COUNT = 1024;

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
  logic dma_hint;

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

  reg [VEC_WIDTH-1:0] vectors [0:VEC_COUNT-1];
  reg [63:0] sig;
  integer dma_seen_count;
  integer dma_early_seen_count;
  integer br_seen_count;

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

  function automatic [63:0] mix64(input [63:0] acc, input [63:0] data_i64);
    begin
      mix64 = (acc ^ (data_i64 + 64'h9e3779b97f4a7c15 + (acc << 6) + (acc >> 2)));
    end
  endfunction

  initial MCLK = 1'b0;
  initial CLK1_i = 1'b0;
  initial MCLK_e = 1'b0;
  initial EDCLK_i = 1'b0;
  always #1 MCLK = ~MCLK;
  always #2 CLK1_i = ~CLK1_i;
  always #3 MCLK_e = ~MCLK_e;
  always #5 EDCLK_i = ~EDCLK_i;

  integer i;
  reg [VEC_WIDTH-1:0] v;

  initial begin
    $readmemh("tests/verilator/regressions/vectors/ym7101_dma_vectors.mem", vectors);

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
    dma_hint = 1'b0;

    sig = 64'h510e527fade682d1;
    dma_seen_count = 0;
    dma_early_seen_count = 0;
    br_seen_count = 0;

    #20;
    RESET = 1'b1;
    #16;

    for (i = 0; i < VEC_COUNT; i = i + 1) begin
      v = vectors[i];
      {SD, RD_i, AD_i, SPA_B_i, CSYNC_i, HSYNC_i, HL, SEL0, PAL, RESET, CD_i, CA_i,
       BGACK_i, BG, MREQ, INTAK, IORQ, RD, WR, M1, AS, UDS, LDS, RW, DTACK_i, ext_test_2,
       vdp_cramdot_dis, dma_hint} = v;

      #2;

      if (i > 64 && $isunknown({SE1, SE0, SC, RAS1, CAS1, WE1, WE0, OE1, RD_o, RD_d, DAC_R, DAC_G, DAC_B,
                                 AD_o, AD_d, YS, SPA_B_pull, VSYNC, CSYNC_pull, HSYNC_pull, CLK1_o, SBCR, CLK0,
                                 EDCLK_o, EDCLK_d, CD_o, CD_d, CA_o, CA_d, SOUND, INT_pull, BR_pull, BGACK_pull,
                                 IPL1_pull, IPL2_pull, DTACK_pull, UWR, LWR, OE0, CAS0, RAS0, RA, vdp_hclk1,
                                 vdp_intfield, vdp_de_h, vdp_de_v, vdp_m5, vdp_rs1, vdp_m2, vdp_lcb, vdp_psg_clk1,
                                 vdp_hsync2, vdp_dma_oe_early, vdp_dma})) begin
        $fatal(1, "X/Z on ym7101 outputs at vector %0d", i);
      end

      if (vdp_dma)
        dma_seen_count = dma_seen_count + 1;
      if (vdp_dma_oe_early)
        dma_early_seen_count = dma_early_seen_count + 1;
      if (BR_pull)
        br_seen_count = br_seen_count + 1;

      sig = mix64(sig, {SE1, SE0, SC, RAS1, CAS1, WE1, WE0, OE1, RD_o, RD_d, DAC_R, DAC_G, DAC_B, AD_o, AD_d, YS, SPA_B_pull, VSYNC, CSYNC_pull, HSYNC_pull, CLK1_o, SBCR, CLK0, EDCLK_o, EDCLK_d});
      sig = mix64(sig, {25'h0, CD_o, CD_d, CA_o, CA_d, SOUND});
      sig = mix64(sig, {10'h0, INT_pull, BR_pull, BGACK_pull, IPL1_pull, IPL2_pull, DTACK_pull, UWR, LWR, OE0, CAS0, RAS0, RA, vdp_hclk1, vdp_intfield, vdp_de_h, vdp_de_v, vdp_m5, vdp_rs1, vdp_m2, vdp_lcb, vdp_psg_clk1, vdp_hsync2, vdp_dma_oe_early, vdp_dma});
      sig = mix64(sig, {42'h0, SD, RD_i, AD_i, dma_hint, ext_test_2, vdp_cramdot_dis});
    end

    // Ensure we exercised DMA/arbitration-visible behavior at least occasionally.
    if ((dma_seen_count + dma_early_seen_count + br_seen_count) < 8) begin
      $fatal(1, "Insufficient DMA/arbitration activity observed");
    end

    $display("SIGNATURE %016h", sig);
    $display("tb_ym7101_dma_vector: PASS");
    $finish;
  end
endmodule
