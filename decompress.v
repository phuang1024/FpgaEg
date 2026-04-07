// This module is similar to compress.

// For this module, we need a 16 bit multi-read register
// and a 8 bit multi write.

// Decoding a value takes at least two clock cycles.
// Each cycle, we process a single mode: Reading zeros, or reading data.
// If reading zeros, read until first one bit, keeping count.
// If reading data, read specified number, writing to output.

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
	// Bit pointer of rmem_dout.
	reg[3:0] in_ptr;
	// Bit pointer of tmem_din.
	reg[2:0] out_ptr;
	// Number of zeros counted.
	reg[2:0] zero_count;

	// Mode: Whether we are reading zeros or data.
	// Does not necessarily correlate with clock cycle.
	localparam M_ZERO = 1'd0;
	localparam M_DATA = 1'd1;
	reg mode;

	integer i;

	// FSM states.
	localparam S_IDLE = 2'd0;
	// Pause for a single cycle here to r/w.
	localparam S_RW = 2'd1;
	// Perform decode, and set memory signals to r/w.
	localparam S_DEC = 2'd2;
	localparam S_DONE = 2'd3;
	reg[1:0] state;


	initial begin
		state <= S_IDLE;
	end

	always @(posedge clk) begin
		done <= 0;
		tmem_we <= 0;

		if (state == S_IDLE) begin
			if (start) begin
				state <= S_RW;
			end

			mode <= M_ZERO;
			in_ptr <= 0;
			out_ptr <= 0;
			zero_count <= 0;

			rmem_addr <= 0;
			tmem_addr <= 0;

		end else if (state == S_RW) begin
			if (tmem_we) begin
				tmem_addr <= tmem_addr + 1;
				tmem_din <= 0;
				out_ptr <= 0;
			end

			if (rmem_addr == rmem_len) begin
				state <= S_DONE;
			end else begin
				state <= S_DEC;
			end

		end else if (state == S_DEC) begin
			// In a single iteration of this state, there are two disjoint responsibilities:
			// 1. If in_ptr < 8, read the bits of rmem_dout until end, or until mode violation.
			// 2. If in_ptr == 8, request next index of rmem and wait next iter.

			tmem_we <= 0;

			if (in_ptr >= 8) begin
				// Previous iter already consumed entire rmem_dout. Increment.
				rmem_addr <= rmem_addr + 1;
				in_ptr <= 0;
				
			end else begin
				if (mode == M_ZERO) begin
					// Default case: All zeros.
					in_ptr <= 8;
					zero_count <= zero_count + 8 - in_ptr;

					// Find the lowest nonzero index above ptr.
					for (i = 7; i >= 0; i = i - 1) begin
						if (i >= in_ptr && rmem_dout[i] != 0) begin
							in_ptr <= i;
							zero_count <= zero_count + i - in_ptr;
							mode <= M_DATA;
						end
					end

				end else begin
					// Write bits rmem_dout --> tmem_din
					// until either end of rmem_dout or hit zero_count + 1.
					for (i = 0; i < 8; i = i + 1) begin
						if (out_ptr + i <= zero_count && in_ptr + i < 8) begin
							tmem_din[zero_count - out_ptr - i] <= rmem_dout[in_ptr + i];
							out_ptr <= out_ptr + i + 1;
							in_ptr <= in_ptr + i + 1;

							if (out_ptr + i == zero_count) begin
								tmem_we <= 1;
								zero_count <= 0;
								mode <= M_ZERO;
							end
						end
					end
				end
			end

			state <= S_RW;

		end else if (state == S_DONE) begin
			// Write last byte.
			tmem_we <= 1;
			len <= tmem_addr + 1;

			done <= 1;
			state <= S_IDLE;
		end
	end
endmodule
