`timescale 1ns/1ps

module tb_z80_bus_vector;
  localparam integer VEC_WIDTH = 13;
  localparam integer VEC_COUNT = 1024;

  logic MCLK;
  logic CLK;
  wire [15:0] ADDRESS;
  wire ADDRESS_z;
  logic [7:0] DATA_i;
  wire [7:0] DATA_o;
  wire DATA_z;
  wire M1;
  wire MREQ;
  wire MREQ_z;
  wire IORQ;
  wire IORQ_z;
  wire RD;
  wire RD_z;
  wire WR;
  wire WR_z;
  wire RFSH;
  wire HALT;
  logic WAIT;
  logic INT;
  logic NMI;
  logic RESET;
  logic BUSRQ;
  wire BUSAK;

  reg [VEC_WIDTH-1:0] vectors [0:VEC_COUNT-1];
  reg [63:0] sig;
  integer toggle_count;

  z80cpu dut (
    .MCLK(MCLK), .CLK(CLK), .ADDRESS(ADDRESS), .ADDRESS_z(ADDRESS_z), .DATA_i(DATA_i), .DATA_o(DATA_o), .DATA_z(DATA_z),
    .M1(M1), .MREQ(MREQ), .MREQ_z(MREQ_z), .IORQ(IORQ), .IORQ_z(IORQ_z), .RD(RD), .RD_z(RD_z), .WR(WR), .WR_z(WR_z),
    .RFSH(RFSH), .HALT(HALT), .WAIT(WAIT), .INT(INT), .NMI(NMI), .RESET(RESET), .BUSRQ(BUSRQ), .BUSAK(BUSAK)
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
  reg [63:0] prev_obs;
  reg [63:0] obs;

  initial begin
    $readmemh("tests/verilator/regressions/vectors/z80_bus_vectors.mem", vectors);

    DATA_i = 8'h00;
    WAIT = 1'b1;
    INT = 1'b1;
    NMI = 1'b1;
    RESET = 1'b0;
    BUSRQ = 1'b1;

    sig = 64'ha4093822299f31d0;
    toggle_count = 0;
    prev_obs = 64'h0;

    #8;

    for (i = 0; i < VEC_COUNT; i = i + 1) begin
      v = vectors[i];
      {DATA_i, WAIT, INT, NMI, RESET, BUSRQ} = v;
      #2;

      if (i > 12 && $isunknown({ADDRESS, ADDRESS_z, DATA_o, DATA_z, M1, MREQ, MREQ_z, IORQ, IORQ_z, RD, RD_z, WR, WR_z, RFSH, HALT, BUSAK})) begin
        $fatal(1, "X/Z on z80 outputs at vector %0d", i);
      end

      obs = {26'h0, ADDRESS, ADDRESS_z, DATA_o, DATA_z, M1, MREQ, MREQ_z, IORQ, IORQ_z, RD, RD_z, WR, WR_z, RFSH, HALT, BUSAK};
      if (i > 0 && obs != prev_obs)
        toggle_count = toggle_count + 1;
      prev_obs = obs;

      sig = mix64(sig, obs);
    end

    if (toggle_count < (VEC_COUNT / 128)) begin
      $fatal(1, "Insufficient observable bus activity (%0d transitions)", toggle_count);
    end

    $display("SIGNATURE %016h", sig);
    $display("tb_z80_bus_vector: PASS");
    $finish;
  end
endmodule
