module adder(
	input logic [31:0] A,
	input logic [31:0] B,
	input logic Cin,
	output logic Cout,
	output logic [31:0] sum
);
 assign {Cout,sum} = A + B + Cin;
endmodule