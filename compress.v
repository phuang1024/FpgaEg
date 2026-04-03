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
	input wire[7:0] rmem_dout,
	input wire[15:0] rmem_len,

	output reg tmem_we,
	output reg[15:0] tmem_addr,
	output reg[7:0] tmem_din,

	// Length as output variable.
	output reg[15:0] len
);
	// Index i is num of bits of i.
	reg[3:0] size_lut[255:0];

	reg[15:0] in_ptr;
	reg[15:0] out_ptr;

	localparam S_IDLE = 2'd0;
	localparam S_COMP = 2'd1;
	reg[1:0] state;


	initial begin
		$readmemh("num_bits.hex", size_lut);
		state <= S_IDLE;
	end

	always @(posedge clk) begin
		done <= 0;
		tmem_we <= 0;

		if (state == S_IDLE) begin
			if (start) begin
				state <= S_COMP;
			end

			// Init vars.
			in_ptr <= 0;
			out_ptr <= 0;

		end else if (state == S_COMP) begin
			// TODO dummy copy
			// TODO not pipelined correctly
			if (in_ptr >= rmem_len) begin
				done <= 1;
				state <= S_IDLE;
				len <= out_ptr;
			end else begin
				rmem_addr <= in_ptr;
				tmem_we <= 1;
				tmem_addr <= out_ptr;
				tmem_din <= rmem_dout;

				in_ptr <= in_ptr + 1;
				out_ptr <= out_ptr + 1;
			end
		end
	end
endmodule
