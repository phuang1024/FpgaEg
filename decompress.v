// This module is similar to compress.

module decompress(
	input wire clk,

	input wire start,
	output reg done,

	output reg[15:0] rmem_addr,
	input wire[7:0] rmem_dout,
	input wire[15:0] rmem_len,

	output reg tmem_we,
	output reg[15:0] tmem_addr,
	output reg[15:0] tmem_din,

	// Length as output variable.
	output reg[15:0] len
);
endmodule
