`timescale 1ns/1ps

module tb_md_board_cart_vector;
  logic MCLK2;
  logic ext_reset;
  logic reset_button;
  logic ext_vres;
  logic ext_zres;

  wire [14:0] ram_68k_address;
  wire [1:0] ram_68k_byteena;
  wire [15:0] ram_68k_data;
  wire ram_68k_wren;
  logic [15:0] ram_68k_o;
  wire [12:0] ram_z80_address;
  wire [7:0] ram_z80_data;
  wire ram_z80_wren;
  logic [7:0] ram_z80_o;

  logic M3;
  logic [15:0] cart_data;
  logic cart_data_en;
  wire [22:0] cart_address;
  wire cart_cs;
  wire cart_oe;
  wire cart_lwr;
  wire cart_uwr;
  wire cart_time;
  wire cart_cas2;
  wire [15:0] cart_data_wr;
  wire cart_dma;
  logic cart_m3_pause;
  logic ext_dtack;
  logic pal;
  logic jap;

  logic tmss_enable;
  logic [15:0] tmss_data;
  wire [9:0] tmss_address;

  wire [7:0] V_R, V_G, V_B;
  wire V_HS, V_VS, V_CS;
  wire [15:0] A_L, A_R;
  wire [17:0] A_L_2612, A_R_2612;
  wire [8:0] MOL, MOR;
  wire [9:0] MOL_2612, MOR_2612;
  wire [15:0] PSG;
  wire [2:0] DAC_ch_index;
  wire fm_sel23;

  logic [6:0] PA_i;
  wire [6:0] PA_o;
  wire [6:0] PA_d;
  logic [6:0] PB_i;
  wire [6:0] PB_o;
  wire [6:0] PB_d;
  logic [6:0] PC_i;
  wire [6:0] PC_o;
  wire [6:0] PC_d;

  wire vdp_hclk1;
  wire vdp_intfield;
  wire vdp_de_h;
  wire vdp_de_v;
  wire vdp_m5;
  wire vdp_rs1;
  wire vdp_m2;
  wire vdp_lcb;
  wire vdp_psg_clk1;
  logic vdp_cramdot_dis;
  wire fm_clk1;
  wire vdp_hsync2;
  logic ym2612_status_enable;
  logic dma_68k_req;
  logic dma_z80_req;
  wire dma_z80_ack;
  wire res_z80;
  wire vdp_dma_oe_early;
  wire vdp_dma;

  md_board dut (
    .MCLK2(MCLK2), .ext_reset(ext_reset), .reset_button(reset_button), .ext_vres(ext_vres), .ext_zres(ext_zres),
    .ram_68k_address(ram_68k_address), .ram_68k_byteena(ram_68k_byteena), .ram_68k_data(ram_68k_data), .ram_68k_wren(ram_68k_wren),
    .ram_68k_o(ram_68k_o), .ram_z80_address(ram_z80_address), .ram_z80_data(ram_z80_data), .ram_z80_wren(ram_z80_wren), .ram_z80_o(ram_z80_o),
    .M3(M3), .cart_data(cart_data), .cart_data_en(cart_data_en), .cart_address(cart_address), .cart_cs(cart_cs), .cart_oe(cart_oe),
    .cart_lwr(cart_lwr), .cart_uwr(cart_uwr), .cart_time(cart_time), .cart_cas2(cart_cas2), .cart_data_wr(cart_data_wr), .cart_dma(cart_dma),
    .cart_m3_pause(cart_m3_pause), .ext_dtack(ext_dtack), .pal(pal), .jap(jap), .tmss_enable(tmss_enable), .tmss_data(tmss_data),
    .tmss_address(tmss_address), .V_R(V_R), .V_G(V_G), .V_B(V_B), .V_HS(V_HS), .V_VS(V_VS), .V_CS(V_CS), .A_L(A_L), .A_R(A_R),
    .A_L_2612(A_L_2612), .A_R_2612(A_R_2612), .MOL(MOL), .MOR(MOR), .MOL_2612(MOL_2612), .MOR_2612(MOR_2612), .PSG(PSG),
    .DAC_ch_index(DAC_ch_index), .fm_sel23(fm_sel23), .PA_i(PA_i), .PA_o(PA_o), .PA_d(PA_d), .PB_i(PB_i), .PB_o(PB_o), .PB_d(PB_d),
    .PC_i(PC_i), .PC_o(PC_o), .PC_d(PC_d), .vdp_hclk1(vdp_hclk1), .vdp_intfield(vdp_intfield), .vdp_de_h(vdp_de_h), .vdp_de_v(vdp_de_v),
    .vdp_m5(vdp_m5), .vdp_rs1(vdp_rs1), .vdp_m2(vdp_m2), .vdp_lcb(vdp_lcb), .vdp_psg_clk1(vdp_psg_clk1), .vdp_cramdot_dis(vdp_cramdot_dis),
    .fm_clk1(fm_clk1), .vdp_hsync2(vdp_hsync2), .ym2612_status_enable(ym2612_status_enable), .dma_68k_req(dma_68k_req),
    .dma_z80_req(dma_z80_req), .dma_z80_ack(dma_z80_ack), .res_z80(res_z80), .vdp_dma_oe_early(vdp_dma_oe_early), .vdp_dma(vdp_dma)
  );

  function automatic [63:0] mix64(input [63:0] acc, input [63:0] data_i);
    begin
      mix64 = (acc ^ (data_i + 64'h9e3779b97f4a7c15 + (acc << 6) + (acc >> 2)));
    end
  endfunction

  initial MCLK2 = 1'b0;
  always #1 MCLK2 = ~MCLK2;

  integer i;
  integer seed;
  reg [63:0] sig;

  initial begin
    seed = 32'h5eedbeef;
    ext_reset = 1'b1;
    reset_button = 1'b0;
    ext_vres = 1'b0;
    ext_zres = 1'b0;

    ram_68k_o = 16'h0000;
    ram_z80_o = 8'h00;

    M3 = 1'b1;
    cart_data = 16'h0000;
    cart_data_en = 1'b0;
    cart_m3_pause = 1'b0;
    ext_dtack = 1'b1;
    pal = 1'b0;
    jap = 1'b1;
    tmss_enable = 1'b1;
    tmss_data = 16'h0000;

    PA_i = 7'h00;
    PB_i = 7'h00;
    PC_i = 7'h00;
    vdp_cramdot_dis = 1'b0;
    ym2612_status_enable = 1'b0;
    dma_68k_req = 1'b0;
    dma_z80_req = 1'b0;

    sig = 64'h1f83d9abfb41bd6b;

    for (i = 0; i < 360; i = i + 1) begin
      if (i == 16) ext_reset = 1'b0;

      // Exercise cart and DTACK-related inputs.
      ext_dtack = $urandom(seed);
      cart_data_en = $urandom(seed);
      cart_data = $urandom(seed);
      cart_m3_pause = $urandom(seed);
      M3 = $urandom(seed);
      tmss_data = $urandom(seed);
      tmss_enable = $urandom(seed);

      // Other environment traffic.
      ram_68k_o = $urandom(seed);
      ram_z80_o = $urandom(seed);
      pal = $urandom(seed);
      jap = $urandom(seed);
      PA_i = $urandom(seed);
      PB_i = $urandom(seed);
      PC_i = $urandom(seed);
      vdp_cramdot_dis = $urandom(seed);
      ym2612_status_enable = $urandom(seed);
      dma_68k_req = $urandom(seed);
      dma_z80_req = $urandom(seed);

      #2;

      if (i > 40 && $isunknown({cart_address, cart_cs, cart_oe, cart_lwr, cart_uwr, cart_time, cart_cas2, cart_data_wr, cart_dma, tmss_address})) begin
        $fatal(1, "X/Z on md_board cart/tmss outputs at cycle %0d", i);
      end

      sig = mix64(sig, {18'h0, cart_address, cart_cs, cart_oe, cart_lwr, cart_uwr, cart_time, cart_cas2, cart_dma});
      sig = mix64(sig, {38'h0, cart_data_wr, tmss_address});
    end

    $display("SIGNATURE %016h", sig);
    $display("tb_md_board_cart_vector: PASS");
    $finish;
  end
endmodule
