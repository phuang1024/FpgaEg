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
	reg[2:0] dout_ptr;
	// Number of zeros counted.
	reg[2:0] zero_count;

	// Mode: Whether we are reading zeros or data.
	// Does not necessarily correlate with clock cycle.
	localparam M_ZERO = 1'd0;
	localparam M_DATA = 1'd1;
	reg mode;

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

			rmem_addr <= 0;
			tmem_addr <= 0;

		end else if (state == S_RW) begin
			if (rmem_addr == rmem_len) begin
				state <= S_DONE;

			end else begin
				state <= S_DEC;
			end

		end else if (state == S_DEC) begin
			// TODO dummy copy
			tmem_din <= rmem_dout;
			tmem_we <= 1;
			rmem_addr <= rmem_addr + 1;
			// TODO incrementing this too soon.
			tmem_addr <= tmem_addr + 1;

			state <= S_RW;

		end else if (state == S_DONE) begin
			done <= 1;
			len <= tmem_addr;
			state <= S_IDLE;
		end
	end
endmodule
