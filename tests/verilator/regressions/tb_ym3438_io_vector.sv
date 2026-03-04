`timescale 1ns/1ps

module tb_ym3438_io_vector;
  localparam integer VEC_WIDTH = 58;
  localparam integer VEC_COUNT = 128;

  logic MCLK;
  logic c1;
  logic c2;
  logic [1:0] address;
  logic [7:0] data;
  logic CS;
  logic WR;
  logic RD;
  logic IC;
  logic timer_a;
  logic timer_b;
  logic [7:0] reg_21;
  logic [7:3] reg_2c;
  logic pg_dbg;
  logic eg_dbg;
  logic eg_dbg_inc;
  logic [13:0] op_dbg;
  logic [8:0] ch_dbg;
  logic ym2612_status_enable;

  wire write_addr_en;
  wire write_data_en;
  wire [7:0] data_bus;
  wire bank;
  wire [7:0] data_o;
  wire io_dir;
  wire irq;

  reg [VEC_WIDTH-1:0] vectors [0:VEC_COUNT-1];
  reg [63:0] sig;

  ym3438_io dut (
    .MCLK(MCLK),
    .c1(c1),
    .c2(c2),
    .address(address),
    .data(data),
    .CS(CS),
    .WR(WR),
    .RD(RD),
    .IC(IC),
    .timer_a(timer_a),
    .timer_b(timer_b),
    .reg_21(reg_21),
    .reg_2c(reg_2c),
    .pg_dbg(pg_dbg),
    .eg_dbg(eg_dbg),
    .eg_dbg_inc(eg_dbg_inc),
    .op_dbg(op_dbg),
    .ch_dbg(ch_dbg),
    .write_addr_en(write_addr_en),
    .write_data_en(write_data_en),
    .data_bus(data_bus),
    .bank(bank),
    .data_o(data_o),
    .io_dir(io_dir),
    .irq(irq),
    .ym2612_status_enable(ym2612_status_enable)
  );

  function automatic [63:0] mix64(input [63:0] acc, input [63:0] data_i);
    begin
      mix64 = (acc ^ (data_i + 64'h9e3779b97f4a7c15 + (acc << 6) + (acc >> 2)));
    end
  endfunction

  initial MCLK = 1'b0;
  always #1 MCLK = ~MCLK;

  integer i;
  reg [VEC_WIDTH-1:0] v;

  initial begin
    $readmemh("tests/verilator/regressions/vectors/ym3438_io_vectors.mem", vectors);

    c1 = 0;
    c2 = 0;
    address = 0;
    data = 0;
    CS = 1;
    WR = 1;
    RD = 1;
    IC = 0;
    timer_a = 0;
    timer_b = 0;
    reg_21 = 0;
    reg_2c = 0;
    pg_dbg = 0;
    eg_dbg = 0;
    eg_dbg_inc = 0;
    op_dbg = 0;
    ch_dbg = 0;
    ym2612_status_enable = 0;
    sig = 64'h6a09e667f3bcc909;

    #2;

    for (i = 0; i < VEC_COUNT; i = i + 1) begin
      v = vectors[i];
      {c1, c2, ym2612_status_enable, ch_dbg, op_dbg, eg_dbg_inc, eg_dbg, pg_dbg, reg_2c, reg_21,
       timer_b, timer_a, IC, RD, WR, CS, data, address} = v;

      #2;

      if (i > 6 && $isunknown({write_addr_en, write_data_en, data_bus, bank, data_o, io_dir, irq})) begin
        $fatal(1, "X/Z seen on ym3438_io outputs at vector %0d", i);
      end

      sig = mix64(sig, {43'h0, write_addr_en, write_data_en, data_bus, bank, data_o, io_dir, irq});
    end

    $display("SIGNATURE %016h", sig);
    $display("tb_ym3438_io_vector: PASS");
    $finish;
  end
endmodule
