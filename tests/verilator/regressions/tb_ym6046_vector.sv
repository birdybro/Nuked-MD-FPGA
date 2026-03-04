`timescale 1ns/1ps

module tb_ym6046_vector;
  localparam integer VEC_WIDTH = 73;
  localparam integer VEC_COUNT = 384;

  logic MCLK;
  logic [6:0] PORT_A_i;
  logic [6:0] PORT_B_i;
  logic [6:0] PORT_C_i;
  logic test;
  logic M3;
  logic IO;
  logic CAS0;
  logic SRES;
  logic VCLK;
  logic NTSC;
  logic DISK;
  logic JAP;
  logic [7:0] ZA_i;
  logic [7:0] ZD_i;
  logic [6:0] VA_i;
  logic [15:0] VD_i;
  logic LWR;
  logic t1;
  logic ZV;
  logic VZ;
  logic tmss_enable;

  wire [6:0] PORT_A_d;
  wire [6:0] PORT_B_d;
  wire [6:0] PORT_C_d;
  wire [6:0] PORT_A_o;
  wire [6:0] PORT_B_o;
  wire [6:0] PORT_C_o;
  wire HL;
  wire FRES;
  wire bc1;
  wire bc2;
  wire bc3;
  wire bc4;
  wire bc5;
  wire [7:0] vdata;
  wire reg_3e_q;
  wire [7:0] zdata;
  wire [6:0] ztov_address;

  reg [VEC_WIDTH-1:0] vectors [0:VEC_COUNT-1];
  reg [63:0] sig;

  ym6046 dut (
    .MCLK(MCLK), .PORT_A_i(PORT_A_i), .PORT_B_i(PORT_B_i), .PORT_C_i(PORT_C_i), .test(test), .M3(M3),
    .IO(IO), .CAS0(CAS0), .SRES(SRES), .VCLK(VCLK), .NTSC(NTSC), .DISK(DISK), .JAP(JAP), .ZA_i(ZA_i),
    .ZD_i(ZD_i), .VA_i(VA_i), .VD_i(VD_i), .LWR(LWR), .t1(t1), .ZV(ZV), .VZ(VZ), .PORT_A_d(PORT_A_d),
    .PORT_B_d(PORT_B_d), .PORT_C_d(PORT_C_d), .PORT_A_o(PORT_A_o), .PORT_B_o(PORT_B_o), .PORT_C_o(PORT_C_o),
    .HL(HL), .FRES(FRES), .bc1(bc1), .bc2(bc2), .bc3(bc3), .bc4(bc4), .bc5(bc5), .vdata(vdata),
    .reg_3e_q(reg_3e_q), .zdata(zdata), .ztov_address(ztov_address), .tmss_enable(tmss_enable)
  );

  function automatic [63:0] mix64(input [63:0] acc, input [63:0] data_i);
    begin
      mix64 = (acc ^ (data_i + 64'h9e3779b97f4a7c15 + (acc << 6) + (acc >> 2)));
    end
  endfunction

  initial MCLK = 1'b0;
  initial VCLK = 1'b0;
  always #1 MCLK = ~MCLK;
  always #2 VCLK = ~VCLK;

  integer i;
  reg [VEC_WIDTH-1:0] v;

  initial begin
    $readmemh("tests/verilator/regressions/vectors/ym6046_vectors.mem", vectors);

    PORT_A_i = 0;
    PORT_B_i = 0;
    PORT_C_i = 0;
    test = 0;
    M3 = 1;
    IO = 1;
    CAS0 = 1;
    SRES = 1;
    NTSC = 1;
    DISK = 0;
    JAP = 0;
    ZA_i = 0;
    ZD_i = 0;
    VA_i = 0;
    VD_i = 0;
    LWR = 1;
    t1 = 0;
    ZV = 0;
    VZ = 0;
    tmss_enable = 0;
    sig = 64'h510e527fade682d1;

    #6;

    for (i = 0; i < VEC_COUNT; i = i + 1) begin
      v = vectors[i];
      {PORT_A_i, PORT_B_i, PORT_C_i, test, M3, IO, CAS0, SRES, NTSC, DISK, JAP,
       ZA_i, ZD_i, VA_i, VD_i, LWR, t1, ZV, VZ, tmss_enable} = v;
      #2;

      if (i > 12 && $isunknown({PORT_A_d, PORT_B_d, PORT_C_d, PORT_A_o, PORT_B_o, PORT_C_o, HL, FRES, bc1, bc2, bc3, bc4, bc5, vdata, reg_3e_q, zdata, ztov_address})) begin
        $fatal(1, "X/Z on ym6046 outputs at vector %0d", i);
      end

      sig = mix64(sig, {23'h0, PORT_A_d, PORT_B_d, PORT_C_d, PORT_A_o, PORT_B_o, PORT_C_o});
      sig = mix64(sig, {33'h0, HL, FRES, bc1, bc2, bc3, bc4, bc5, vdata, reg_3e_q, zdata, ztov_address});
    end

    $display("SIGNATURE %016h", sig);
    $display("tb_ym6046_vector: PASS");
    $finish;
  end
endmodule
