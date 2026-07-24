module cascaded_addr_32(
  input  logic [31:0] A, B,
  input  logic ci,
  output logic [31:0] S,
  output logic co
);
logic [31:0] hold;
logic [3:0] C;

  n_adder #(.N(8)) adder (
    .A(A[7:0]),
    .B(B[7:0]),
    .ci(ci),
    .S(hold[7:0]),
    .co(C[0])
  );
  n_adder #(.N(8)) adder1 (
    .A(A[15:8]),
    .B(B[15:8]),
    .ci(C[0]),
    .S(hold[15:8]),
    .co(C[1])
  );
  n_adder #(.N(8)) adder2 (
    .A(A[23:16]),
    .B(B[23:16]),
    .ci(C[1]),
    .S(hold[23:16]),
    .co(C[2])
  );
  n_adder #(.N(8)) adder3 (
    .A(A[31:24]),
    .B(B[31:24]),
    .ci(C[2 ]),
    .S(hold[31:24]),
    .co(C[3])
  );

  assign S = hold;
    assign co = C[3];
endmodule