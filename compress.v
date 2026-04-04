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

// Pipelining latency:
//   Write memory when 1 <= index <= len.

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

	// Counter for compression. Is 1 index = 2 cycles ahead of out_ptr.
	reg[15:0] index;
	reg[15:0] out_ptr;

	localparam S_IDLE = 2'd0;
	// Perform the word compression alg.
	localparam S_COMP = 2'd1;
	// Wait one cycle for tmem to write.
	localparam S_WRITE = 2'd2;
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
			index <= 0;
			out_ptr <= 0;

		end else if (state == S_COMP) begin
			// In this cycle: Set raddr one index ahead.
			// Set we.

			rmem_addr <= index;
			tmem_addr <= out_ptr;
			tmem_din <= rmem_dout;

			// we lags behind by 1.
			if (index >= 1 && index < rmem_len + 1) begin
				tmem_we <= 1;
			end

			state <= S_WRITE;

		end else if (state == S_WRITE) begin
			// In this cycle: Increment in and out index.

			if (index >= rmem_len + 1) begin
				// Check if done.
				done <= 1;
				state <= S_IDLE;
				len <= out_ptr;

			end else begin
				// Begin incrementing out_ptr 1 index = 2 cycles behind.
				if (index >= 1 && index < rmem_len + 1) begin
					out_ptr <= out_ptr + 1;
				end
				index <= index + 1;

				state <= S_COMP;
			end
		end
	end
endmodule
