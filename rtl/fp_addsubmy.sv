module fp_addsubmy (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic        sub,
    output logic [31:0] result
);
    // Extraction of components
    logic       sign_a, sign_b;
    logic [7:0] exp_a, exp_b;
    logic [23:0] sig_a, sig_b; //with implicit leading 1 for normalized numbers

    //aligning exponents and significands
    logic [7:0] exp_diff;
    logic [7:0] exp_max;
    logic [23:0] sig_large, sig_small, sig_small_aligned;
    logic sign_large, sign_small;

    //ALU operation
    logic eff_sub;
    logic [24:0] alu_result; // one extra bit for carry

    // Normalization and rounding
    logic [4:0] lzc; // leading zero count
    logic [7:0] norm_exp;
    logic [24:0] norm_sig;
    logic final_sign;

    //Extracting the components of the floating point numbers
    always_comb begin
        sign_a = a[31];
        sign_b = b[31];
        exp_a  = a[30:23];
        exp_b  = b[30:23];
        sig_a  = (exp_a == 0) ? {1'b0, a[22:0]} : {1'b1, a[22:0]}; // Handle subnormals
        sig_b  = (exp_b == 0) ? {1'b0, b[22:0]} : {1'b1, b[22:0]}; // Handle subnormals
        // Adjust sign of b if subtracting
        if (sub) begin
            sign_b = ~sign_b;
        end
    end

    // Aligning the significands based on exponent difference
    always_comb begin 
        if(exp_a > exp_b || (exp_a == exp_b && sig_a >= sig_b)) begin
            exp_max = exp_a;
            exp_diff = exp_max - exp_b;
            sig_large = sig_a;
            sign_large = sign_a;
            sig_small = sig_b;
            sign_small = sign_b;
        end else begin
            exp_max = exp_b;
            exp_diff = exp_max - exp_a;
            sig_large = sig_b;
            sign_large = sign_b;
            sig_small = sig_a;
            sign_small = sign_a;
        end

        sig_small_aligned = (exp_diff > 24) ? 24'd0 : (sig_small >> exp_diff);
    end

    // ALU operation: addition or subtraction based on effective sign
    always_comb begin
        eff_sub = sign_large ^ sign_small;
        if(eff_sub) begin
            alu_result = {1'b0, sig_large} - {1'b0, sig_small_aligned};
        end else begin
            alu_result = {1'b0, sig_large} + {1'b0, sig_small_aligned};
        end
    end

    // Normalization and rounding
    always_comb begin
        lzc = 5'd0;
        norm_sig = alu_result;
        norm_exp = exp_max;
        final_sign = sign_large;

        if (!eff_sub && alu_result[24]) begin
            // Carry out occurred in addition
            norm_sig = alu_result >> 1;
            norm_exp = exp_max + 1'b1;
        end else if (eff_sub && alu_result != 0) begin
            // Leading zeros occurred in subtraction (simple priority encoder logic)
            if (alu_result[23])      lzc = 0;
            else if (alu_result[22]) lzc = 1;
            else if (alu_result[21]) lzc = 2;
            else if (alu_result[20]) lzc = 3;
            else if (alu_result[19]) lzc = 4;
            else if (alu_result[18]) lzc = 5;
            else if (alu_result[17]) lzc = 6;
            else if (alu_result[16]) lzc = 7;
            else if (alu_result[15]) lzc = 8;
            else if (alu_result[14]) lzc = 9;
            else if (alu_result[13]) lzc = 10;
            else if (alu_result[12]) lzc = 11;
            else if (alu_result[11]) lzc = 12;
            else if (alu_result[10]) lzc = 13;
            else if (alu_result[9])  lzc = 14;
            else if (alu_result[8])  lzc = 15;
            else if (alu_result[7])  lzc = 16;
            else if (alu_result[6])  lzc = 17;
            else if (alu_result[5])  lzc = 18;
            else if (alu_result[4])  lzc = 19;
            else if (alu_result[3])  lzc = 20;
            else if (alu_result[2])  lzc = 21;
            else if (alu_result[1])  lzc = 22;
            else if (alu_result[0])  lzc = 23;
            else lzc = 24;

            norm_sig = alu_result << lzc;
            norm_exp = exp_max - lzc;
        end
        
        // Handle complete cancellation (Zero result)
        if (alu_result == 0) begin
            norm_exp = 0;
            final_sign = 0;
        end
    end

    // 6. Pack Result
    always_comb begin
        // The 23-bit mantissa drops the explicit leading 1 (which is at index 23 of norm_sig)
        result = {final_sign, norm_exp, norm_sig[22:0]};
    end
    


endmodule