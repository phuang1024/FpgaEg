// EG compress module.

// Compression algorithm:
// For max efficiency, we have two buffers:
//   A small buffer where all bits can be simultaneously written to;
//   and the output memory (tmem), only one write per cycle.
// When compressing a single uint8, the code word will not exceed 15 bits.
//   Therefore, we define the word size of the output memory (tmem) to be 16 bits,
//   so each value encoded will correspond to at most one word written.
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

	// 2 word circular buffer.
	reg[31:0] buffer;
	// Index pointer (bit) for buffer.
	reg[4:0] buf_ptr;
	// Flag to indicate which half of buffer is ready to write:
	// 0 = none, 1 = buffer[15:0], 2 = buffer[31:16]
	reg[1:0] buf_ready;

	// Size in bits of current value to compress.
	reg[7:0] curr_size;

	// Counter for compression. Is 1 index = 2 cycles ahead of out_ptr.
	reg[15:0] index;
	reg[15:0] out_ptr;

	localparam S_IDLE = 2'd0;
	// Perform the word compression alg.
	localparam S_COMP = 2'd1;
	// Wait one cycle for tmem to write.
	localparam S_WRITE = 2'd2;
	reg[1:0] state;

	integer i;


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
			buf_ptr <= 0;

		end else if (state == S_COMP) begin
			// In this cycle:
			// Perform the EG compression; write to circular buffer.
			// Set raddr one index ahead.

			if (index >= 1 && index <= rmem_len) begin
				// Currently, rmem data is M[index - 1].
				// Write zeros and data, accounting for index wrap.
				for (i = 0; i < 8; i = i + 1) begin
					if (i < curr_size - 1) begin
						buffer[buf_ptr + i] <= 0;
					end
					if (i < curr_size) begin
						buffer[buf_ptr + curr_size - 1 + i] <= rmem_dout[curr_size - i - 1];
					end
				end

				// Check if word filled up.
				buf_ready <= 0;
				if (buf_ptr < 16 && buf_ptr + curr_size >= 16) begin
					buf_ready <= 1;
				end else if (buf_ptr >= 16 && buf_ptr + curr_size >= 32) begin
					buf_ready <= 2;
				end

				// Increment buf_ptr, automatic wrapping.
				buf_ptr <= buf_ptr + curr_size;
			end

			// Increment rmem's addr.
			rmem_addr <= index;

			state <= S_WRITE;

		end else if (state == S_WRITE) begin
			// In this cycle:
			// If circular buffer word full, copy to tmem's data; and set we.
			// Increment both indices.
			// Set curr_size.

			// Check if done.
			if (index >= rmem_len + 1) begin
				done <= 1;
				state <= S_IDLE;
				len <= out_ptr;

			end else begin
				if (index >= 1 && index <= rmem_len) begin
					// Same as above, corresponds to M[index - 1].
					if (buf_ready == 1)
						tmem_din <= buffer[15:0];
					else
						tmem_din <= buffer[31:16];

					if (buf_ready != 0) begin
						tmem_we <= 1;
						tmem_addr <= out_ptr;
						out_ptr <= out_ptr + 1;
					end
				end

				index <= index + 1;

				curr_size <= size_lut[rmem_dout];

				state <= S_COMP;
			end
		end
	end
endmodule
