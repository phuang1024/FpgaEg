// EG compress module.

// Compression algorithm:
// For max efficiency, we have two buffers:
//   A small buffer where all bits can be simultaneously written to;
//   and the output memory (tmem), only one write per cycle.
// When compressing a single uint8, the code word will not exceed 15 bits.
//   Therefore, we define the word size of the output memory (tmem) to be 16 bits,
//   so each input value will correspond to at most one word written.
// We define the small buffer as a 2 word (32 bit) circular buffer.
//   The EG code word for each input will not necessarily line up byte-wise.
//   However, when either the first or second word is filled up, we write that to tmem.
//   I.e. write bits [0:15] or [16:31] once the pointer advances past that index.

module compress(
	input wire clk,

	input wire start,
	output reg done,

	output reg[15:0] rmem_addr,
	input wire[7:0] rmem_data,

	output reg tmem_we,
	output reg[15:0] tmem_addr,
	output reg[7:0] tmem_data
);
	// Index i is num of bits of i.
	reg[3:0] size_lut[255:0];

	localparam S_IDLE = 2'd0;
	reg[1:0] state;


	initial begin
		$readmemh("num_bits.hex", size_lut);
		state <= S_IDLE;
	end

	always @(posedge clk) begin
		done <= 0;
		tmem_we <= 0;

		if (state == S_IDLE) begin
		end
	end
endmodule
