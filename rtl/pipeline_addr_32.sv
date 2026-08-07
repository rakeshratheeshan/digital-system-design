module pipeline_addr_32(
    input CLK,
  input  logic [31:0] A, B,
  input  logic ci,
  output logic [31:0] S,
  output logic co
    );
  reg [23:0] Areg1, Breg1;
  reg [15:0] Areg2, Breg2;
  reg [7:0] Areg3, Breg3;

  reg [7:0] sum_reg1;
  reg [15:0] sum_reg2;
  reg [23:0] sum_reg3;

  reg c8_reg, c16_reg, c24_reg, c32_reg;

  wire c8, c16, c24, c32;
  wire [7:0] sum1, sum2, sum3, sum4;

    always_ff @(posedge CLK) begin
        Areg1 <= A[31:8];
        Breg1 <= B[31:8];

        Areg2 <= Areg1[23:8];
        Breg2 <= Breg1[23:8];


        Areg3 <= Areg2[15:8];
        Breg3 <= Breg2[15:8];
    end

    n_adder #(.N((8))) adder1 (.A(A[7:0]), .B(B[7:0]), .ci(ci), .S(sum1), .co(c8));

    always_ff @(posedge CLK) begin
        sum_reg1 <= sum1;
        c8_reg <= c8;   
    end

    n_adder #(.N((8))) adder2 (.A(Areg1[7:0]), .B(Breg1[7:0]), .ci(c8_reg), .S(sum2), .co(c16));

    always_ff @(posedge CLK) begin
        sum_reg2 <= {sum2,sum_reg1};
        c16_reg <= c16;   
    end
  
    n_adder #(.N((8))) adder3 (.A(Areg2[7:0]), .B(Breg2[7:0]), .ci(c16_reg), .S(sum3), .co(c24));

    always_ff @(posedge CLK) begin
        sum_reg3 <= {sum3,sum_reg2};
        c24_reg <= c24;   
    end


    n_adder #(.N((8))) adder4 (.A(Areg3[7:0]), .B(Breg3[7:0]), .ci(c24_reg), .S(sum4), .co(c32));

    always_ff @(posedge CLK) begin

        S <= {sum4,sum_reg3};
        co <= c32;   
    end
  endmodule 