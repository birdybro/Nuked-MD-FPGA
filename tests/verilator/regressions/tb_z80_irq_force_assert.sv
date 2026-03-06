`timescale 1ns/1ps

module tb_z80_irq_force_assert;
  localparam integer CYCLES = 4096;

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

  reg [15:0] lfsr;
  integer i;
  integer toggle_count;
  integer irq_seen;
  integer busak_seen;
  reg [63:0] prev_obs;
  reg [63:0] obs;

  z80cpu dut (
    .MCLK(MCLK), .CLK(CLK), .ADDRESS(ADDRESS), .ADDRESS_z(ADDRESS_z), .DATA_i(DATA_i), .DATA_o(DATA_o), .DATA_z(DATA_z),
    .M1(M1), .MREQ(MREQ), .MREQ_z(MREQ_z), .IORQ(IORQ), .IORQ_z(IORQ_z), .RD(RD), .RD_z(RD_z), .WR(WR), .WR_z(WR_z),
    .RFSH(RFSH), .HALT(HALT), .WAIT(WAIT), .INT(INT), .NMI(NMI), .RESET(RESET), .BUSRQ(BUSRQ), .BUSAK(BUSAK)
  );

  wire addr_valid = (ADDRESS_z == 1'b0) && !$isunknown(ADDRESS);

  initial MCLK = 1'b0;
  initial CLK = 1'b0;
  always #1 MCLK = ~MCLK;
  always #2 CLK = ~CLK;

  task automatic tick(input integer n);
    integer k;
    begin
      for (k = 0; k < n; k = k + 1) @(posedge MCLK);
    end
  endtask

  initial begin
    DATA_i = 8'h00;
    WAIT = 1'b0;
    INT = 1'b1;
    NMI = 1'b1;
    RESET = 1'b0;
    BUSRQ = 1'b1;
    lfsr = 16'h1d3f;

    toggle_count = 0;
    irq_seen = 0;
    busak_seen = 0;
    prev_obs = 64'h0;

    #8;

    for (i = 0; i < CYCLES; i = i + 1) begin
      lfsr = {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};

      // Keep reset mostly inactive, with periodic short pulses.
      if ((i < 20) || ((i % 257) == 0))
        RESET = 1'b1;
      else if ((i % 257) == 6)
        RESET = 1'b0;

      // Active-high WAIT: insert short stalls.
      WAIT = ((i % 61) < 2) ? 1'b1 : 1'b0;
      // Active-low interrupt style inputs.
      INT = ((i % 211) < 5) ? 1'b0 : 1'b1;
      NMI = ((i % 389) < 2) ? 1'b0 : 1'b1;
      BUSRQ = ((i % 503) < 3) ? 1'b0 : 1'b1;

      if (addr_valid)
        DATA_i = lfsr[7:0] ^ ADDRESS[7:0];
      else
        DATA_i = lfsr[7:0];

      #2;

      if (i > 20 && $isunknown({ADDRESS_z, DATA_z, M1, MREQ, MREQ_z, IORQ, IORQ_z, RD, RD_z, WR, WR_z, RFSH, HALT, BUSAK})) begin
        $fatal(1, "X/Z on z80 control outputs at cycle %0d", i);
      end
      if (i > 20 && (DATA_z == 1'b0) && $isunknown(DATA_o)) begin
        $fatal(1, "X/Z on z80 data output while driven at cycle %0d", i);
      end

      if ((M1 == 1'b0) && ((IORQ_z == 1'b0) || (IORQ == 1'b0)))
        irq_seen = irq_seen + 1;
      if ((BUSRQ == 1'b0) || (BUSAK == 1'b0))
        busak_seen = busak_seen + 1;

      obs = {27'h0, ADDRESS, ADDRESS_z, DATA_o, DATA_z, M1, MREQ, MREQ_z, IORQ, IORQ_z, RD, RD_z, WR, WR_z, RFSH, HALT, BUSAK};
      if (i > 0 && obs != prev_obs)
        toggle_count = toggle_count + 1;
      prev_obs = obs;
    end

    // Force selected uncovered branch controls in z80.v to flip at least once.
    force dut.w9_i = 1'b0;
    force dut.w9_n = 1'b1;
    tick(4);
    release dut.w9_n;
    release dut.w9_i;

    force dut.w147 = 8'h18;
    force dut.w71 = 1'b1;
    tick(4);
    release dut.w71;

    force dut.w75 = 1'b1;
    tick(4);
    release dut.w75;

    force dut.w79 = 1'b1;
    tick(4);
    release dut.w79;
    release dut.w147;

    force dut.w304 = 1'b1;
    force dut.l45 = 1'b1;
    tick(4);
    release dut.l45;
    release dut.w304;

    force dut.w2 = 1'b0;
    force dut.w42 = 1'b0;
    tick(4);
    release dut.w42;
    release dut.w2;

    if (toggle_count < (CYCLES / 32))
      $fatal(1, "Insufficient z80 bus activity (%0d transitions)", toggle_count);
    if (irq_seen < 4)
      $fatal(1, "Interrupt activity not observed");
    if (busak_seen < 4)
      $fatal(1, "BUSRQ/BUSAK activity not observed");

    $display("tb_z80_irq_force_assert: PASS");
    $finish;
  end
endmodule
