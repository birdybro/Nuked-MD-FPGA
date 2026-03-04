`timescale 1ns/1ps

module tb_tmss_bus_transaction;
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
    .MCLK(MCLK), .VD_i(VD_i), .test(test), .JAP(JAP), .AS(AS), .LDS(LDS), .UDS(UDS), .RW(RW),
    .VA(VA), .SRES(SRES), .CE0_i(CE0_i), .M3(M3), .CART(CART), .INTAK(INTAK), .VD_o(VD_o),
    .DTACK(DTACK), .RESET(RESET), .CE0_o(CE0_o), .test_0(test_0), .test_1(test_1), .test_2(test_2),
    .test_3(test_3), .test_4(test_4), .data_out_en(data_out_en), .tmss_enable(tmss_enable),
    .tmss_data(tmss_data), .tmss_address(tmss_address)
  );

  initial MCLK = 1'b0;
  always #1 MCLK = ~MCLK;

  task automatic idle_bus;
    begin
      AS = 1'b1;
      LDS = 1'b1;
      UDS = 1'b1;
      RW = 1'b1;
      VA = 23'h000000;
      VD_i = 16'h0000;
      #4;
    end
  endtask

  task automatic write_tmss_word(input [22:0] addr, input [15:0] data_w);
    begin
      VA = addr;
      VD_i = data_w;
      AS = 1'b0;
      LDS = 1'b0;
      UDS = 1'b0;
      RW = 1'b0;
      #4;
      idle_bus();
    end
  endtask

  initial begin
    VD_i = 16'h0000;
    test = 3'h7;     // Keeps test_4 deasserted.
    JAP = 1'b1;
    AS = 1'b1;
    LDS = 1'b1;
    UDS = 1'b1;
    RW = 1'b1;
    VA = 23'h0;
    SRES = 1'b0;
    CE0_i = 1'b0;
    M3 = 1'b1;
    CART = 1'b0;
    INTAK = 1'b1;
    tmss_enable = 1'b1;
    tmss_data = 16'hbeef;

    #8;
    SRES = 1'b1;
    #8;

    // Before CE control writes, with M3=1/CART=0/CE0_i=0, CE0_o should be open.
    if (CE0_o !== 1'b1) $fatal(1, "Expected CE0_o high before 0x50a080 control writes");

    // Control write at 0x50a080 with data bit0=1 should force CE0_o low.
    VA = 23'h50a080;
    VD_i = 16'h0001;
    AS = 1'b0;
    LDS = 1'b0;
    UDS = 1'b1;
    RW = 1'b0;
    #2;
    if (DTACK !== 1'b0) $fatal(1, "DTACK should assert during 0x50a080 access when INTAK=1");
    #2;
    idle_bus();
    #2;
    if (CE0_o !== 1'b0) $fatal(1, "Expected CE0_o low after writing bit0=1 to 0x50a080");

    // Write bit0=0 and verify CE0_o returns high.
    VA = 23'h50a080;
    VD_i = 16'h0000;
    AS = 1'b0;
    LDS = 1'b0;
    UDS = 1'b1;
    RW = 1'b0;
    #4;
    idle_bus();
    #2;
    if (CE0_o !== 1'b1) $fatal(1, "Expected CE0_o high after writing bit0=0 to 0x50a080");

    // Verify tmss_data mux path while CE0_o open.
    if (VD_o !== tmss_data) $fatal(1, "Expected tmss_data on VD_o when CE path is open");

    // Verify basic bus decode invariants stay stable/known.
    VA = 23'h50a123;
    #2;
    if (tmss_address !== 10'h123) $fatal(1, "tmss_address decode mismatch");
    if ($isunknown({VD_o, DTACK, RESET, CE0_o, data_out_en})) begin
      $fatal(1, "X/Z on tmss outputs after transaction");
    end

    $display("tb_tmss_bus_transaction: PASS");
    $finish;
  end
endmodule
