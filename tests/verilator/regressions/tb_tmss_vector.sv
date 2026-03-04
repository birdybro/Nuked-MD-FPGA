`timescale 1ns/1ps

module tb_tmss_vector;
  localparam integer VEC_WIDTH = 69;
  localparam integer VEC_COUNT = 256;

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

  reg [VEC_WIDTH-1:0] vectors [0:VEC_COUNT-1];
  reg [63:0] sig;

  tmss dut (
    .MCLK(MCLK), .VD_i(VD_i), .test(test), .JAP(JAP), .AS(AS), .LDS(LDS), .UDS(UDS), .RW(RW),
    .VA(VA), .SRES(SRES), .CE0_i(CE0_i), .M3(M3), .CART(CART), .INTAK(INTAK), .VD_o(VD_o),
    .DTACK(DTACK), .RESET(RESET), .CE0_o(CE0_o), .test_0(test_0), .test_1(test_1), .test_2(test_2),
    .test_3(test_3), .test_4(test_4), .data_out_en(data_out_en), .tmss_enable(tmss_enable),
    .tmss_data(tmss_data), .tmss_address(tmss_address)
  );

  function automatic [63:0] mix64(input [63:0] acc, input [63:0] data_i);
    begin
      mix64 = (acc ^ (data_i + 64'h9e3779b97f4a7c15 + (acc << 6) + (acc >> 2)));
    end
  endfunction

  task automatic idle_bus;
    begin
      AS = 1'b1;
      LDS = 1'b1;
      UDS = 1'b1;
      RW = 1'b1;
      #2;
    end
  endtask

  task automatic write_tmss_word(input [22:0] addr, input [15:0] data_w, input lds, input uds);
    begin
      VA = addr;
      VD_i = data_w;
      AS = 1'b0;
      LDS = lds;
      UDS = uds;
      RW = 1'b0;
      #2;
      idle_bus();
    end
  endtask

  initial MCLK = 1'b0;
  always #1 MCLK = ~MCLK;

  integer i;
  reg [VEC_WIDTH-1:0] v;

  initial begin
    $readmemh("tests/verilator/regressions/vectors/tmss_vectors.mem", vectors);

    VD_i = 16'h0;
    test = 3'h7;
    JAP = 1'b1;
    AS = 1'b1;
    LDS = 1'b1;
    UDS = 1'b1;
    RW = 1'b1;
    VA = 23'h0;
    SRES = 1'b0;
    CE0_i = 1'b1;
    M3 = 1'b1;
    CART = 1'b0;
    INTAK = 1'b1;
    tmss_enable = 1'b1;
    tmss_data = 16'hbabe;

    sig = 64'h243f6a8885a308d3;

    #4;
    SRES = 1'b1;
    #4;

    // Sweep test decode to hit test_0..test_4 logic.
    for (i = 0; i < 8; i = i + 1) begin
      test = i[2:0];
      #2;
      if ($isunknown({test_0, test_1, test_2, test_3, test_4})) $fatal(1, "X on TMSS test outputs");
      sig = mix64(sig, {56'h0, test_0, test_1, test_2, test_3, test_4, test});
    end

    // Directed writes to exercise w15/w23 paths and key latches.
    write_tmss_word(23'h50a000, 16'h5345, 1'b0, 1'b0);
    write_tmss_word(23'h50a001, 16'h4741, 1'b0, 1'b0);
    write_tmss_word(23'h50a080, 16'h0001, 1'b0, 1'b1);
    write_tmss_word(23'h50a080, 16'h0000, 1'b0, 1'b1);

    // Trigger w10 clock path.
    VA = 23'h600000;
    AS = 1'b0;
    LDS = 1'b1;
    UDS = 1'b1;
    RW = 1'b1;
    #2;
    idle_bus();

    for (i = 0; i < VEC_COUNT; i = i + 1) begin
      v = vectors[i];
      {VD_i, test, JAP, AS, LDS, UDS, RW, VA, SRES, CE0_i, M3, CART, INTAK, tmss_enable, tmss_data} = v;
      #2;

      if ($isunknown({VD_o, DTACK, RESET, CE0_o, test_0, test_1, test_2, test_3, test_4, data_out_en, tmss_address})) begin
        $fatal(1, "X/Z on TMSS outputs at vector %0d", i);
      end

      if (tmss_address !== VA[9:0]) begin
        $fatal(1, "tmss_address mismatch at vector %0d", i);
      end

      sig = mix64(sig, {38'h0, VD_o, DTACK, RESET, CE0_o, data_out_en, tmss_address});
      sig = mix64(sig, {56'h0, test_0, test_1, test_2, test_3, test_4, test});
    end

    $display("SIGNATURE %016h", sig);
    $display("tb_tmss_vector: PASS");
    $finish;
  end
endmodule
