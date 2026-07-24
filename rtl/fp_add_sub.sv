// IEEE-754 binary32 floating-point adder/subtractor.
// Rounding mode: round to nearest, ties to even (the IEEE-754 default).
// `subtract = 0`: result = a + b
// `subtract = 1`: result = a - b
module fp_add_sub (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic        subtract,
    output logic [31:0] result
);
    logic        sign_a, sign_b, sign_b_effective;
    logic [7:0]  exponent_a, exponent_b;
    logic [22:0] fraction_a, fraction_b;

    // Shifts an extended significand right, preserving every discarded bit
    // in bit zero (the sticky bit).
    function automatic logic [26:0] shift_right_sticky(
        input logic [26:0] value,
        input logic [7:0]  shift_amount
    );
        logic sticky;
        begin
            if (shift_amount == 0)
                shift_right_sticky = value;
            else if (shift_amount >= 27)
                shift_right_sticky = {{26{1'b0}}, |value};
            else begin
                sticky = |(value & ((27'b1 << shift_amount) - 1'b1));
                shift_right_sticky = value >> shift_amount;
                shift_right_sticky[0] = shift_right_sticky[0] | sticky;
            end
        end
    endfunction

    always_comb begin : add_subtract
        logic a_is_nan, b_is_nan, a_is_inf, b_is_inf;
        logic [7:0] effective_exponent_a, effective_exponent_b;
        logic [7:0] large_exponent, small_exponent, output_exponent;
        logic [23:0] significand_a, significand_b;
        logic [26:0] large_significand, small_significand;
        logic [27:0] arithmetic_significand;
        logic [24:0] rounded_significand;
        logic        large_sign, small_sign, output_sign;
        logic        guard_bit, round_bit, sticky_bit, round_up;
        logic [7:0] exponent_difference;

        sign_a     = a[31];
        sign_b     = b[31];
        sign_b_effective = sign_b ^ subtract;
        exponent_a = a[30:23];
        exponent_b = b[30:23];
        fraction_a = a[22:0];
        fraction_b = b[22:0];

        a_is_nan  = (exponent_a == 8'hff) && (fraction_a != 0);
        b_is_nan  = (exponent_b == 8'hff) && (fraction_b != 0);
        a_is_inf  = (exponent_a == 8'hff) && (fraction_a == 0);
        b_is_inf  = (exponent_b == 8'hff) && (fraction_b == 0);

        // Subnormals have effective exponent 1 and no implicit leading one.
        effective_exponent_a = (exponent_a == 0) ? 8'd1 : exponent_a;
        effective_exponent_b = (exponent_b == 0) ? 8'd1 : exponent_b;
        significand_a = {(exponent_a != 0), fraction_a};
        significand_b = {(exponent_b != 0), fraction_b};
        result = 32'h0000_0000;
        large_exponent = '0;
        small_exponent = '0;
        large_significand = '0;
        small_significand = '0;
        arithmetic_significand = '0;
        rounded_significand = '0;
        large_sign = 1'b0;
        small_sign = 1'b0;
        output_exponent = '0;
        output_sign = 1'b0;
        exponent_difference = '0;
        guard_bit = 1'b0;
        round_bit = 1'b0;
        sticky_bit = 1'b0;
        round_up = 1'b0;

        // Special values are handled before the ordinary sign/exponent/fraction path.
        if (a_is_nan || b_is_nan || (a_is_inf && b_is_inf &&
                                     (sign_a != sign_b_effective))) begin
            // Canonical quiet NaN (also for +infinity + -infinity).
            result = 32'h7fc0_0000;
        end else if (a_is_inf) begin
            result = {sign_a, 8'hff, 23'd0};
        end else if (b_is_inf) begin
            result = {sign_b_effective, 8'hff, 23'd0};
        end else begin
            // Put the operand with the greater magnitude on the left.  This makes
            // a subtraction non-negative at the significand level.
            if ((effective_exponent_a > effective_exponent_b) ||
                ((effective_exponent_a == effective_exponent_b) &&
                 (significand_a >= significand_b))) begin
                large_exponent    = effective_exponent_a;
                small_exponent    = effective_exponent_b;
                large_significand = {significand_a, 3'b000};
                small_significand = {significand_b, 3'b000};
                large_sign        = sign_a;
                small_sign        = sign_b_effective;
            end else begin
                large_exponent    = effective_exponent_b;
                small_exponent    = effective_exponent_a;
                large_significand = {significand_b, 3'b000};
                small_significand = {significand_a, 3'b000};
                large_sign        = sign_b_effective;
                small_sign        = sign_a;
            end

            exponent_difference = large_exponent - small_exponent;
            small_significand = shift_right_sticky(small_significand,
                                                    exponent_difference);
            output_exponent = large_exponent;
            output_sign = large_sign;

            if (large_sign == small_sign)
                arithmetic_significand = {1'b0, large_significand} +
                                         {1'b0, small_significand};
            else
                arithmetic_significand = {1'b0, large_significand} -
                                         {1'b0, small_significand};

            // Addition may create 10.x; shift it back to 1.x and retain sticky.
            if (arithmetic_significand[27]) begin
                arithmetic_significand = arithmetic_significand >> 1;
                arithmetic_significand[0] = arithmetic_significand[0] |
                                             arithmetic_significand[1];
                output_exponent = output_exponent + 1'b1;
            end else begin
                // After subtraction, restore the hidden-bit position.  Do not
                // shift below exponent 1: that encoding represents subnormals.
                while ((arithmetic_significand[26] == 0) &&
                       (arithmetic_significand != 0) &&
                       (output_exponent > 1)) begin
                    arithmetic_significand = arithmetic_significand << 1;
                    output_exponent = output_exponent - 1'b1;
                end
            end

            if (arithmetic_significand == 0) begin
                // Exact cancellation is +0 under round-to-nearest-even.
                result = 32'h0000_0000;
            end else if (output_exponent >= 8'hff) begin
                result = {output_sign, 8'hff, 23'd0};
            end else begin
                guard_bit  = arithmetic_significand[2];
                round_bit  = arithmetic_significand[1];
                sticky_bit = arithmetic_significand[0];
                round_up = guard_bit && (round_bit || sticky_bit ||
                                         arithmetic_significand[3]);
                rounded_significand = {1'b0, arithmetic_significand[26:3]} + round_up;

                // Rounding 1.111... upward produces 10.000... .
                if (rounded_significand[24]) begin
                    output_exponent = output_exponent + 1'b1;
                    if (output_exponent >= 8'hff)
                        result = {output_sign, 8'hff, 23'd0};
                    else
                        result = {output_sign, output_exponent, 23'd0};
                end else begin
                    // At effective exponent 1, a missing hidden bit is encoded
                    // as exponent field zero (a subnormal result).
                    result = {output_sign,
                              arithmetic_significand[26] ? output_exponent : 8'd0,
                              rounded_significand[22:0]};
                end
            end
        end
    end
endmodule
