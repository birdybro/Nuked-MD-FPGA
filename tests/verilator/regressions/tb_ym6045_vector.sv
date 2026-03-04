`timescale 1ns/1ps

module tb_ym6045_vector;
  localparam integer VEC_WIDTH = 52;
  localparam integer VEC_COUNT = 640;

  logic MCLK;
  logic MCLK_e;
  logic VCLK;
  logic ZCLK;
  logic VD8_i;
  logic [15:7] ZA_i;
  logic ZA0_i;
  logic [22:7] VA_i;
  logic ZRD_i;
  logic M1;
  logic ZWR_i;
  logic BGACK_i;
  logic BG;
  logic IORQ;
  logic RW_i;
  logic UDS_i;
  logic AS_i;
  logic DTACK_i;
  logic LDS_i;
  logic CAS0;
  logic M3;
  logic WRES;
  logic CART;
  logic OE0;
  logic WAIT_i;
  logic ZBAK;
  logic MREQ_i;
  logic FC0;
  logic FC1;
  logic SRES;
  logic test_mode_0;
  logic ZD0_i;
  logic HSYNC;

  wire VD8_o;
  wire ZA0_o;
  wire [15:8] ZA_o;
  wire [22:7] VA_o;
  wire ZRD_o;
  wire UDS_o;
  wire ZWR_o;
  wire BGACK_o;
  wire AS_o;
  wire RW_d;
  wire RW_o;
  wire LDS_o;
  wire strobe_dir;
  wire DTACK_o;
  wire BR;
  wire IA14;
  wire TIME;
  wire CE0;
  wire FDWR;
  wire FDC;
  wire ROM;
  wire ASEL;
  wire EOE;
  wire NOE;
  wire RAS2;
  wire CAS2;
  wire REF;
  wire ZRAM;
  wire WAIT_o;
  wire ZBR;
  wire NMI;
  wire ZRES;
  wire SOUND;
  wire VZ;
  wire MREQ_o;
  wire VRES;
  wire VPA;
  wire VDPM;
  wire IO;
  wire ZV;
  wire INTAK;
  wire EDCLK;
  wire vtoz;
  wire w12;
  wire w131;
  wire w142;
  wire w310;
  wire w353;

  reg [VEC_WIDTH-1:0] vectors [0:VEC_COUNT-1];
  reg [63:0] sig;

  ym6045 dut (
    .MCLK(MCLK), .MCLK_e(MCLK_e), .VCLK(VCLK), .ZCLK(ZCLK), .VD8_i(VD8_i), .ZA_i(ZA_i), .ZA0_i(ZA0_i), .VA_i(VA_i),
    .ZRD_i(ZRD_i), .M1(M1), .ZWR_i(ZWR_i), .BGACK_i(BGACK_i), .BG(BG), .IORQ(IORQ), .RW_i(RW_i), .UDS_i(UDS_i),
    .AS_i(AS_i), .DTACK_i(DTACK_i), .LDS_i(LDS_i), .CAS0(CAS0), .M3(M3), .WRES(WRES), .CART(CART), .OE0(OE0),
    .WAIT_i(WAIT_i), .ZBAK(ZBAK), .MREQ_i(MREQ_i), .FC0(FC0), .FC1(FC1), .SRES(SRES), .test_mode_0(test_mode_0),
    .ZD0_i(ZD0_i), .HSYNC(HSYNC), .VD8_o(VD8_o), .ZA0_o(ZA0_o), .ZA_o(ZA_o), .VA_o(VA_o), .ZRD_o(ZRD_o), .UDS_o(UDS_o),
    .ZWR_o(ZWR_o), .BGACK_o(BGACK_o), .AS_o(AS_o), .RW_d(RW_d), .RW_o(RW_o), .LDS_o(LDS_o), .strobe_dir(strobe_dir),
    .DTACK_o(DTACK_o), .BR(BR), .IA14(IA14), .TIME(TIME), .CE0(CE0), .FDWR(FDWR), .FDC(FDC), .ROM(ROM), .ASEL(ASEL),
    .EOE(EOE), .NOE(NOE), .RAS2(RAS2), .CAS2(CAS2), .REF(REF), .ZRAM(ZRAM), .WAIT_o(WAIT_o), .ZBR(ZBR), .NMI(NMI),
    .ZRES(ZRES), .SOUND(SOUND), .VZ(VZ), .MREQ_o(MREQ_o), .VRES(VRES), .VPA(VPA), .VDPM(VDPM), .IO(IO), .ZV(ZV),
    .INTAK(INTAK), .EDCLK(EDCLK), .vtoz(vtoz), .w12(w12), .w131(w131), .w142(w142), .w310(w310), .w353(w353)
  );

  function automatic [63:0] mix64(input [63:0] acc, input [63:0] data_i);
    begin
      mix64 = (acc ^ (data_i + 64'h9e3779b97f4a7c15 + (acc << 6) + (acc >> 2)));
    end
  endfunction

  initial MCLK = 1'b0;
  initial MCLK_e = 1'b0;
  initial VCLK = 1'b0;
  initial ZCLK = 1'b0;

  always #1 MCLK = ~MCLK;
  always #2 MCLK_e = ~MCLK_e;
  always #3 VCLK = ~VCLK;
  always #5 ZCLK = ~ZCLK;

  integer i;
  reg [VEC_WIDTH-1:0] v;

  initial begin
    $readmemh("tests/verilator/regressions/vectors/ym6045_vectors.mem", vectors);

    VD8_i = 0;
    ZA_i = 0;
    ZA0_i = 0;
    VA_i = 0;
    ZRD_i = 1;
    M1 = 1;
    ZWR_i = 1;
    BGACK_i = 1;
    BG = 1;
    IORQ = 1;
    RW_i = 1;
    UDS_i = 1;
    AS_i = 1;
    DTACK_i = 1;
    LDS_i = 1;
    CAS0 = 1;
    M3 = 1;
    WRES = 0;
    CART = 0;
    OE0 = 1;
    WAIT_i = 1;
    ZBAK = 1;
    MREQ_i = 1;
    FC0 = 0;
    FC1 = 0;
    SRES = 0;
    test_mode_0 = 0;
    ZD0_i = 0;
    HSYNC = 0;

    sig = 64'h13198a2e03707344;

    #8;
    SRES = 1;
    #8;

    for (i = 0; i < VEC_COUNT; i = i + 1) begin
      v = vectors[i];
      {VD8_i, ZA_i, ZA0_i, VA_i, ZRD_i, M1, ZWR_i, BGACK_i, BG, IORQ, RW_i, UDS_i, AS_i, DTACK_i,
       LDS_i, CAS0, M3, WRES, CART, OE0, WAIT_i, ZBAK, MREQ_i, FC0, FC1, SRES, test_mode_0, ZD0_i, HSYNC} = v;

      #2;

      if (i > 24 && $isunknown({VD8_o, ZA0_o, ZA_o, VA_o, ZRD_o, UDS_o, ZWR_o, BGACK_o, AS_o, RW_d, RW_o, LDS_o,
                                 strobe_dir, DTACK_o, BR, IA14, TIME, CE0, FDWR, FDC, ROM, ASEL, EOE, NOE, RAS2,
                                 CAS2, REF, ZRAM, WAIT_o, ZBR, NMI, ZRES, SOUND, VZ, MREQ_o, VRES, VPA, VDPM,
                                 IO, ZV, INTAK, EDCLK, vtoz, w12, w131, w142, w310, w353})) begin
        $fatal(1, "X/Z on ym6045 outputs at vector %0d", i);
      end

      sig = mix64(sig, {38'h0, VD8_o, ZA0_o, ZA_o, VA_o});
      sig = mix64(sig, {16'h0, ZRD_o, UDS_o, ZWR_o, BGACK_o, AS_o, RW_d, RW_o, LDS_o, strobe_dir, DTACK_o,
                        BR, IA14, TIME, CE0, FDWR, FDC, ROM, ASEL, EOE, NOE, RAS2, CAS2, REF, ZRAM, WAIT_o,
                        ZBR, NMI, ZRES, SOUND, VZ, MREQ_o, VRES, VPA, VDPM, IO, ZV, INTAK, EDCLK, vtoz,
                        w12, w131, w142, w310, w353});
    end

    $display("SIGNATURE %016h", sig);
    $display("tb_ym6045_vector: PASS");
    $finish;
  end
endmodule
