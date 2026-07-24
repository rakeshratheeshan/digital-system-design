module fp_add_sub_tb;
    logic [31:0] a, b;
    logic        subtract;
    logic [31:0] result;

    fp_add_sub dut (.a(a), .b(b), .subtract(subtract), .result(result));

    task automatic check(
        input logic [31:0] left,
        input logic [31:0] right,
        input logic        sub,
        input logic [31:0] expected
    );
        begin
            a = left; b = right; subtract = sub; #1;
            if (result !== expected)
                $fatal(1, "%h %s %h: expected %h, got %h", left,
                       sub ? "-" : "+", right, expected, result);
        end
    endtask

    initial begin
        check(32'h3fc0_0000, 32'h4010_0000, 1'b0, 32'h4070_0000); // 1.5 + 2.25 = 3.75
        check(32'h40b0_0000, 32'h3fc0_0000, 1'b1, 32'h4080_0000); // 5.5 - 1.5 = 4.0
        check(32'h3f80_0000, 32'h3f80_0000, 1'b1, 32'h0000_0000); // cancellation
        check(32'h7f7f_ffff, 32'h7f7f_ffff, 1'b0, 32'h7f80_0000); // overflow
        check(32'h0000_0001, 32'h0000_0001, 1'b0, 32'h0000_0002); // subnormal
        check(32'h7f80_0000, 32'hff80_0000, 1'b0, 32'h7fc0_0000); // invalid: inf + -inf
        $display("fp_add_sub tests passed");
        $finish;
    end
endmodule
