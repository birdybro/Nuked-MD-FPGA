`timescale 1ns/1ps

module tb_z80_instr_vector;
  localparam integer VEC_WIDTH = 6;
  localparam integer VEC_COUNT = 2048;

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
  integer bus_toggle_count;
  integer low_read_cycles;
  integer low_write_cycles;
  integer low_m1_cycles;
  integer low_iorq_cycles;
  integer high_read_cycles;
  integer high_write_cycles;
  integer high_m1_cycles;
  integer high_iorq_cycles;

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

  function automatic [7:0] stream_byte(input [15:0] addr, input [1:0] phase);
    reg [5:0] idx;
    begin
      idx = addr[5:0] ^ {4'h0, phase};
      case (idx)
        6'h00: stream_byte = 8'h31; // ld sp,nn
        6'h01: stream_byte = 8'h00;
        6'h02: stream_byte = 8'hf0;
        6'h03: stream_byte = 8'h21; // ld hl,nn
        6'h04: stream_byte = 8'h00;
        6'h05: stream_byte = 8'h40;
        6'h06: stream_byte = 8'h11; // ld de,nn
        6'h07: stream_byte = 8'h00;
        6'h08: stream_byte = 8'h20;
        6'h09: stream_byte = 8'h01; // ld bc,nn
        6'h0a: stream_byte = 8'h00;
        6'h0b: stream_byte = 8'h10;
        6'h0c: stream_byte = 8'h3e; // ld a,n
        6'h0d: stream_byte = 8'ha5;
        6'h0e: stream_byte = 8'h06; // ld b,n
        6'h0f: stream_byte = 8'h5a;
        6'h10: stream_byte = 8'h0e; // ld c,n
        6'h11: stream_byte = 8'h33;
        6'h12: stream_byte = 8'h16; // ld d,n
        6'h13: stream_byte = 8'h66;
        6'h14: stream_byte = 8'h1e; // ld e,n
        6'h15: stream_byte = 8'h99;
        6'h16: stream_byte = 8'h26; // ld h,n
        6'h17: stream_byte = 8'h12;
        6'h18: stream_byte = 8'h2e; // ld l,n
        6'h19: stream_byte = 8'h34;
        6'h1a: stream_byte = 8'h09; // add hl,bc
        6'h1b: stream_byte = 8'h19; // add hl,de
        6'h1c: stream_byte = 8'h29; // add hl,hl
        6'h1d: stream_byte = 8'h39; // add hl,sp
        6'h1e: stream_byte = 8'h80; // add a,b
        6'h1f: stream_byte = 8'h88; // adc a,b
        6'h20: stream_byte = 8'h90; // sub b
        6'h21: stream_byte = 8'ha0; // and b
        6'h22: stream_byte = 8'ha8; // xor b
        6'h23: stream_byte = 8'hb0; // or b
        6'h24: stream_byte = 8'hfe; // cp n
        6'h25: stream_byte = 8'h80;
        6'h26: stream_byte = 8'h32; // ld (nn),a
        6'h27: stream_byte = 8'h20;
        6'h28: stream_byte = 8'h40;
        6'h29: stream_byte = 8'h3a; // ld a,(nn)
        6'h2a: stream_byte = 8'h20;
        6'h2b: stream_byte = 8'h40;
        6'h2c: stream_byte = 8'hed; // ed-prefixed op
        6'h2d: stream_byte = 8'h44; // neg
        6'h2e: stream_byte = 8'hcb; // cb-prefixed op
        6'h2f: stream_byte = 8'h11; // rl c
        6'h30: stream_byte = 8'hd3; // out (n),a
        6'h31: stream_byte = 8'h7f;
        6'h32: stream_byte = 8'hdb; // in a,(n)
        6'h33: stream_byte = 8'h7f;
        6'h34: stream_byte = 8'h18; // jr e
        6'h35: stream_byte = 8'h02;
        6'h36: stream_byte = 8'h00; // nop
        6'h37: stream_byte = 8'h00; // nop
        6'h38: stream_byte = 8'h20; // jr nz,e
        6'h39: stream_byte = 8'h02;
        6'h3a: stream_byte = 8'h28; // jr z,e
        6'h3b: stream_byte = 8'h02;
        6'h3c: stream_byte = 8'h10; // djnz e
        6'h3d: stream_byte = 8'hfe; // tight loop
        6'h3e: stream_byte = 8'hc3; // jp nn
        6'h3f: stream_byte = (phase == 2'b00) ? 8'h00 : ((phase == 2'b01) ? 8'h20 : ((phase == 2'b10) ? 8'h40 : 8'h60));
        default: stream_byte = 8'h00;
      endcase
    end
  endfunction

  initial MCLK = 1'b0;
  initial CLK = 1'b0;
  always #1 MCLK = ~MCLK;
  always #2 CLK = ~CLK;

  integer i;
  reg [VEC_WIDTH-1:0] v;
  reg [1:0] phase;
  reg [63:0] prev_obs;
  reg [63:0] obs;
  wire addr_valid = (ADDRESS_z == 1'b0) && !$isunknown(ADDRESS);

  initial begin
    $readmemh("tests/verilator/regressions/vectors/z80_instr_vectors.mem", vectors);

    DATA_i = 8'h00;
    WAIT = 1'b1;
    INT = 1'b1;
    NMI = 1'b1;
    RESET = 1'b0;
    BUSRQ = 1'b1;

    sig = 64'h3c6ef372fe94f82b;
    prev_obs = 64'h0;
    bus_toggle_count = 0;
    low_read_cycles = 0;
    low_write_cycles = 0;
    low_m1_cycles = 0;
    low_iorq_cycles = 0;
    high_read_cycles = 0;
    high_write_cycles = 0;
    high_m1_cycles = 0;
    high_iorq_cycles = 0;

    #12;

    for (i = 0; i < VEC_COUNT; i = i + 1) begin
      v = vectors[i];
      phase = v[5:4];
      WAIT = v[3];
      INT = v[2];
      NMI = v[1];
      BUSRQ = v[0];

      // Structured reset windows to revisit entry paths without keeping CPU stuck.
      if (i < 24)
        RESET = 1'b1;
      else if ((i % 257) == 0)
        RESET = 1'b1;
      else if ((i % 257) == 8)
        RESET = 1'b0;

      // Feed address-dependent instruction/data stream whenever address bus is valid.
      if (addr_valid)
        DATA_i = stream_byte(ADDRESS, phase);
      else
        DATA_i = {phase, v[3:0], 2'b01};

      #2;

      if (i > 24 && $isunknown({ADDRESS_z, DATA_z, M1, MREQ, MREQ_z, IORQ, IORQ_z, RD, RD_z, WR, WR_z, RFSH, HALT, BUSAK})) begin
        $fatal(1, "X/Z on z80 control outputs at vector %0d", i);
      end
      if (i > 24 && (DATA_z == 1'b0) && $isunknown(DATA_o)) begin
        $fatal(1, "X/Z on z80 data output while driven at vector %0d", i);
      end

      // Count both active-low and active-high interpretations so this remains robust to polarity modeling.
      if ((MREQ_z == 1'b0) && (RD_z == 1'b0) && (MREQ == 1'b0) && (RD == 1'b0)) low_read_cycles = low_read_cycles + 1;
      if ((MREQ_z == 1'b0) && (WR_z == 1'b0) && (MREQ == 1'b0) && (WR == 1'b0)) low_write_cycles = low_write_cycles + 1;
      if ((MREQ_z == 1'b0) && (M1 == 1'b0) && (MREQ == 1'b0)) low_m1_cycles = low_m1_cycles + 1;
      if ((IORQ_z == 1'b0) && (IORQ == 1'b0)) low_iorq_cycles = low_iorq_cycles + 1;

      if ((MREQ_z == 1'b0) && (RD_z == 1'b0) && (MREQ == 1'b1) && (RD == 1'b1)) high_read_cycles = high_read_cycles + 1;
      if ((MREQ_z == 1'b0) && (WR_z == 1'b0) && (MREQ == 1'b1) && (WR == 1'b1)) high_write_cycles = high_write_cycles + 1;
      if ((MREQ_z == 1'b0) && (M1 == 1'b1) && (MREQ == 1'b1)) high_m1_cycles = high_m1_cycles + 1;
      if ((IORQ_z == 1'b0) && (IORQ == 1'b1)) high_iorq_cycles = high_iorq_cycles + 1;

      obs = {27'h0, ADDRESS, ADDRESS_z, DATA_o, DATA_z, M1, MREQ, MREQ_z, IORQ, IORQ_z, RD, RD_z, WR, WR_z, RFSH, HALT, BUSAK};
      if (i > 0 && obs != prev_obs)
        bus_toggle_count = bus_toggle_count + 1;
      prev_obs = obs;

      sig = mix64(sig, obs);
      sig = mix64(sig, {50'h0, DATA_i, phase, WAIT, INT, NMI, RESET, BUSRQ});
    end

    if (bus_toggle_count < (VEC_COUNT / 96)) begin
      $fatal(1, "Insufficient bus activity (%0d transitions)", bus_toggle_count);
    end

    if (((low_read_cycles + low_write_cycles + low_m1_cycles + low_iorq_cycles) < 8) &&
        ((high_read_cycles + high_write_cycles + high_m1_cycles + high_iorq_cycles) < 8)) begin
      $fatal(1, "No convincing bus cycle activity observed");
    end

    $display("SIGNATURE %016h", sig);
    $display("tb_z80_instr_vector: PASS");
    $finish;
  end
endmodule
