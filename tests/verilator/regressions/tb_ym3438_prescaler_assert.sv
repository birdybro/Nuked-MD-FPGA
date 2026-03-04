`timescale 1ns/1ps

module tb_ym3438_prescaler_assert;
  logic MCLK;
  logic PHI;
  logic IC;
  wire c1;
  wire c2;
  wire reset_fsm;

  ym3438_prescaler dut (
    .MCLK(MCLK),
    .PHI(PHI),
    .IC(IC),
    .c1(c1),
    .c2(c2),
    .reset_fsm(reset_fsm)
  );

  initial MCLK = 1'b0;
  initial PHI = 1'b0;
  always #1 MCLK = ~MCLK;
  always #2 PHI = ~PHI;

  integer i;
  integer high_seen;
  integer low_seen_after_release;

  initial begin
    IC = 1'b0;
    high_seen = 0;
    low_seen_after_release = 0;

    for (i = 0; i < 240; i = i + 1) begin
      if (i == 40) IC = 1'b1;
      #2;

      if (i > 8 && $isunknown({c1, c2, reset_fsm})) begin
        $fatal(1, "X/Z seen on prescaler outputs at cycle %0d", i);
      end

      if (!IC && reset_fsm) high_seen = 1;
      if (IC && i > 80 && !reset_fsm) low_seen_after_release = 1;
    end

    if (!high_seen) $fatal(1, "reset_fsm never asserted while IC was low");
    if (!low_seen_after_release) $fatal(1, "reset_fsm never deasserted after IC release");

    $display("tb_ym3438_prescaler_assert: PASS");
    $finish;
  end
endmodule
