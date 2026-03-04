`timescale 1ns/1ps

module tb_m68k_exceptions_vector;
  localparam integer VEC_WIDTH = 26;
  localparam integer VEC_COUNT = 1536;

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

  reg [VEC_WIDTH-1:0] vectors [0:VEC_COUNT-1];
  reg [63:0] sig;
  integer bus_toggle_count;
  integer low_as_seen;
  integer low_uds_seen;
  integer low_lds_seen;
  integer bg_seen;
  integer strobe_toggle_count;

  m68kcpu dut (
    .MCLK(MCLK), .CLK(CLK), .VPA(VPA), .BR(BR), .BGACK(BGACK), .DTACK(DTACK),
    .IPL(IPL), .BERR(BERR), .RESET_i(RESET_i), .RESET_pull(RESET_pull), .HALT_i(HALT_i),
    .HALT_pull(HALT_pull), .DATA_i(DATA_i), .DATA_o(DATA_o), .DATA_z(DATA_z), .E_CLK(E_CLK),
    .BG(BG), .FC(FC), .FC_z(FC_z), .RW(RW), .RW_z(RW_z), .ADDRESS(ADDRESS), .ADDRESS_z(ADDRESS_z),
    .AS(AS), .LDS(LDS), .UDS(UDS), .strobe_z(strobe_z)
  );

  function automatic [63:0] mix64(input [63:0] acc, input [63:0] data_i64);
    begin
      mix64 = (acc ^ (data_i64 + 64'h9e3779b97f4a7c15 + (acc << 6) + (acc >> 2)));
    end
  endfunction

  initial MCLK = 1'b0;
  initial CLK = 1'b0;
  always #1 MCLK = ~MCLK;
  always #2 CLK = ~CLK;

  integer i;
  reg [VEC_WIDTH-1:0] v;
  reg [63:0] obs0;
  reg [63:0] obs1;
  reg [63:0] prev_obs;
  reg [2:0] prev_strobes;

  initial begin
    $readmemh("tests/verilator/regressions/vectors/m68k_exceptions_vectors.mem", vectors);

    VPA = 1'b1;
    BR = 1'b1;
    BGACK = 1'b1;
    DTACK = 1'b1;
    IPL = 3'b111;
    BERR = 1'b1;
    RESET_i = 1'b0;
    HALT_i = 1'b1;
    DATA_i = 16'h0000;

    sig = 64'ha54ff53a5f1d36f1;
    prev_obs = 64'h0;
    bus_toggle_count = 0;
    low_as_seen = 0;
    low_uds_seen = 0;
    low_lds_seen = 0;
    bg_seen = 0;
    strobe_toggle_count = 0;
    prev_strobes = 3'b111;

    #16;

    for (i = 0; i < VEC_COUNT; i = i + 1) begin
      v = vectors[i];
      {VPA, BR, BGACK, DTACK, IPL, BERR, RESET_i, HALT_i, DATA_i} = v;
      #2;

      if (i > 40 && $isunknown({RESET_pull, HALT_pull, E_CLK, BG, FC, FC_z, RW, RW_z, ADDRESS, ADDRESS_z, AS, LDS, UDS, strobe_z, DATA_z})) begin
        $fatal(1, "X/Z on m68k control outputs at vector %0d", i);
      end
      if (i > 40 && (DATA_z == 1'b0) && $isunknown(DATA_o)) begin
        $fatal(1, "X/Z on m68k data output while driven at vector %0d", i);
      end

      if (AS == 1'b0) low_as_seen = low_as_seen + 1;
      if (UDS == 1'b0) low_uds_seen = low_uds_seen + 1;
      if (LDS == 1'b0) low_lds_seen = low_lds_seen + 1;
      if (BG == 1'b1) bg_seen = bg_seen + 1;
      if (i > 0 && ({AS, UDS, LDS} != prev_strobes))
        strobe_toggle_count = strobe_toggle_count + 1;
      prev_strobes = {AS, UDS, LDS};

      obs0 = {16'h0, RESET_pull, HALT_pull, E_CLK, BG, FC, FC_z, RW, RW_z, ADDRESS, ADDRESS_z, AS, LDS, UDS, strobe_z, DATA_z};
      obs1 = {48'h0, DATA_o};
      if (i > 0 && obs0 != prev_obs)
        bus_toggle_count = bus_toggle_count + 1;
      prev_obs = obs0;

      sig = mix64(sig, obs0);
      sig = mix64(sig, obs1);
      sig = mix64(sig, {35'h0, VPA, BR, BGACK, DTACK, IPL, BERR, RESET_i, HALT_i, DATA_i});
    end

    if (bus_toggle_count < (VEC_COUNT / 96)) begin
      $fatal(1, "Insufficient bus/control activity (%0d transitions)", bus_toggle_count);
    end
    if (bg_seen < 4) begin
      $fatal(1, "Insufficient bus arbitration activity");
    end

    $display("SIGNATURE %016h", sig);
    $display("tb_m68k_exceptions_vector: PASS");
    $finish;
  end
endmodule
