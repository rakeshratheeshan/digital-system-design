// tb_regfile.sv
// Verifies:
//   1. Reset clears every register to 0.
//   2. Writing to one register does not disturb any other register
//      (this is the critical "address decode actually isolates" check).
//   3. write_en=0 blocks the write even if write_addr/write_data change.
//   4. The read port correctly returns whichever register read_addr points to.

import cpu_pkg::*;

module tb_regfile;

  localparam int WIDTH = cpu_pkg::DATA_W;
  localparam int NUM_GPR = cpu_pkg::NUM_GPR;
  localparam int SEL_W = cpu_pkg::REG_SEL_W;

  int errors = 0;

  logic clk, rst_n;
  logic write_en;
  logic [SEL_W-1:0] write_addr;
  logic [WIDTH-1:0] write_data;
  logic [SEL_W-1:0] read_addr;
  logic [WIDTH-1:0] read_data;

  regfile dut (.*);

  initial clk = 0;
  always #5 clk = ~clk;

  task automatic check(string what, logic [WIDTH-1:0] got, logic [WIDTH-1:0] exp);
    if (got !== exp) begin
      $display("  FAIL: %s -- got=%0h expected=%0h", what, got, exp);
      errors++;
    end else begin
      $display("  PASS: %s -- %0h", what, got);
    end
  endtask

  // Convention used throughout: all synchronous stimulus (write_en,
  // write_addr, write_data) is only ever changed right after a NEGEDGE --
  // i.e. exactly half a period away from the posedge that the DUT's
  // always_ff blocks sample on. This guarantees the DUT always sees a
  // value that has been stable for a full half-cycle, with zero ambiguity
  // about scheduling order between the testbench and the DUT.
  initial begin
    rst_n = 0; write_en = 0; write_addr = 0; write_data = 0; read_addr = 0;
    @(negedge clk);
    rst_n = 1;

    // --- Test 1: reset clears all registers ---
    for (int i = 0; i < NUM_GPR; i++) begin
      read_addr = i[SEL_W-1:0];
      #1;
      check($sformatf("R%0d cleared after reset", i), read_data, 16'h0000);
    end

    // --- Test 2: write to R3, verify it lands, and R5 stays untouched ---
    @(negedge clk);
    write_en = 1; write_addr = 3'd3; write_data = 16'hBEEF;
    @(posedge clk); // DUT samples here, safely mid-cycle-stable
    @(negedge clk);
    write_en = 0;
    read_addr = 3'd3; #1;
    check("R3 == BEEF after write", read_data, 16'hBEEF);
    read_addr = 3'd5; #1;
    check("R5 untouched by R3 write", read_data, 16'h0000);

    // --- Test 3: write to R5 now, confirm R3 still holds BEEF (isolation) ---
    @(negedge clk);
    write_en = 1; write_addr = 3'd5; write_data = 16'h1234;
    @(posedge clk);
    @(negedge clk);
    write_en = 0;
    read_addr = 3'd5; #1;
    check("R5 == 1234 after its own write", read_data, 16'h1234);
    read_addr = 3'd3; #1;
    check("R3 still BEEF (isolation holds)", read_data, 16'hBEEF);

    // --- Test 4: write_en=0 must block the write even with valid addr/data ---
    @(negedge clk);
    write_en = 0; write_addr = 3'd3; write_data = 16'hFFFF;
    @(posedge clk);
    read_addr = 3'd3; #1;
    check("write_en=0 blocked the write, R3 still BEEF", read_data, 16'hBEEF);

    // --- Test 5: write all 8 registers with distinct values, read all back ---
    for (int i = 0; i < NUM_GPR; i++) begin
      @(negedge clk);
      write_en = 1; write_addr = i[SEL_W-1:0]; write_data = 16'hA000 + i;
      @(posedge clk); // sample happens here, stimulus has been stable a full half-cycle
    end
    @(negedge clk);
    write_en = 0;
    for (int i = 0; i < NUM_GPR; i++) begin
      read_addr = i[SEL_W-1:0]; #1;
      check($sformatf("R%0d == A00%0h after full sweep", i, i), read_data, 16'hA000 + i);
    end

    if (errors == 0)
      $display("\nALL TESTS PASSED for regfile");
    else
      $display("\n%0d TEST(S) FAILED for regfile", errors);

    $finish;
  end

endmodule : tb_regfile
