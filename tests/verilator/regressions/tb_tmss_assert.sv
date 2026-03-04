`timescale 1ns/1ps

module tb_tmss_assert;
  logic MCLK;
  logic [15:0] VD_i;
  logic [2:0] test;
  logic JAP;
  logic AS;
  logic LDS;
  logic UDS;
  logic RW;
  logic [22:0] VA;
  logic SRES;
  logic CE0_i;
  logic M3;
  logic CART;
  logic INTAK;
  logic tmss_enable;
  logic [15:0] tmss_data;

  wire [15:0] VD_o;
  wire DTACK;
  wire RESET;
  wire CE0_o;
  wire test_0;
  wire test_1;
  wire test_2;
  wire test_3;
  wire test_4;
  wire data_out_en;
  wire [9:0] tmss_address;

  tmss dut (
    .MCLK(MCLK),
    .VD_i(VD_i),
    .test(test),
    .JAP(JAP),
    .AS(AS),
    .LDS(LDS),
    .UDS(UDS),
    .RW(RW),
    .VA(VA),
    .SRES(SRES),
    .CE0_i(CE0_i),
    .M3(M3),
    .CART(CART),
    .INTAK(INTAK),
    .VD_o(VD_o),
    .DTACK(DTACK),
    .RESET(RESET),
    .CE0_o(CE0_o),
    .test_0(test_0),
    .test_1(test_1),
    .test_2(test_2),
    .test_3(test_3),
    .test_4(test_4),
    .data_out_en(data_out_en),
    .tmss_enable(tmss_enable),
    .tmss_data(tmss_data),
    .tmss_address(tmss_address)
  );

  initial MCLK = 1'b0;
  always #1 MCLK = ~MCLK;

  integer i;
  integer seed;
  initial begin
    seed = 32'h00c0ffee;
    VD_i = '0;
    test = '0;
    JAP = 1'b0;
    AS = 1'b1;
    LDS = 1'b1;
    UDS = 1'b1;
    RW = 1'b1;
    VA = '0;
    SRES = 1'b1;
    CE0_i = 1'b1;
    M3 = 1'b0;
    CART = 1'b0;
    INTAK = 1'b1;
    tmss_enable = 1'b0;
    tmss_data = 16'h1234;

    for (i = 0; i < 200; i = i + 1) begin
      if (i == 6) SRES = 1'b0;
      if (i == 80) tmss_enable = 1'b1;

      VD_i = $urandom(seed);
      test = $urandom(seed);
      JAP = $urandom(seed);
      AS = $urandom(seed);
      LDS = $urandom(seed);
      UDS = $urandom(seed);
      RW = $urandom(seed);
      VA = $urandom(seed);
      CE0_i = $urandom(seed);
      M3 = $urandom(seed);
      CART = $urandom(seed);
      INTAK = $urandom(seed);
      tmss_data = $urandom(seed);

      #2;

      if (i > 10 && $isunknown({VD_o, DTACK, RESET, CE0_o, data_out_en, tmss_address})) begin
        $fatal(1, "X/Z seen on TMSS outputs at cycle %0d", i);
      end

      if (!tmss_enable) begin
        if (RESET !== 1'b1) $fatal(1, "RESET must be high when tmss_enable=0");
        if (DTACK !== 1'b1) $fatal(1, "DTACK must be high when tmss_enable=0");
        if (CE0_o !== CE0_i) $fatal(1, "CE0_o must pass through CE0_i when tmss_enable=0");
        if (data_out_en !== 1'b1) $fatal(1, "data_out_en must be high when tmss_enable=0");
        if (VD_o !== 16'h0000) $fatal(1, "VD_o must be 0 when tmss_enable=0");
      end

      if (tmss_address !== VA[9:0]) begin
        $fatal(1, "tmss_address mismatch at cycle %0d", i);
      end
    end

    $display("tb_tmss_assert: PASS");
    $finish;
  end
endmodule
