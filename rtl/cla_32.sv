module lcu_4bit(
    input [3:0] p,
    input [3:0] g,
    input cin,
    output [3:1] c,
    output p_out,
    output g_out
);
    assign c[1] = g[0] | (p[0] & cin);
    assign c[2] = g[1] | (p[1] & g[0]) | (p[1] & p[0] & cin);
    assign c[3] = g[2] | (p[2] & g[1]) | (p[2] & p[1] & g[0]) | (p[2] & p[1] & p[0] & cin);
    
    assign p_out = p[3] & p[2] & p[1] & p[0];
    assign g_out = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1]) | (p[3] & p[2] & p[1] & g[0]);
endmodule

module cla_32 (
  input  logic [31:0] A, B,
  input  logic ci,
  output logic [31:0] S,
  output logic co
);
wire [3:0] P, G;
wire [3:1] C;
 cla_8 cla0(.A(A[7:0]), .B(B[7:0]), .ci(ci), .S(S[7:0]), .pout(P[0]), .gout(G[0]), .co());
 cla_8 cla1(.A(A[15:8]), .B(B[15:8]), .ci(C[1]), .S(S[15:8]), .pout(P[1]), .gout(G[1]), .co());
 cla_8 cla2(.A(A[23:16]), .B(B[23:16]), .ci(C[2]), .S(S[23:16]), .pout(P[2]), .gout(G[2]), .co());
 cla_8 cla3(.A(A[31:24]), .B(B[31:24]), .ci(C[3]), .S(S[31:24]), .pout(P[3]), .gout(G[3]), .co());

 lcu_4bit lcu(.p(P), .g(G), .cin(ci), .c(C), .p_out(), .g_out());

 assign co = G[3] | (P[3] & C[3]);
 
endmodule