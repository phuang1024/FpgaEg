// FSM module to receive uint8 array from computer
// and write to main module's memory.

// Two things are read:
// The length of the array as a 16 bit int,
//   which is stored in the "len" output;
// and the contents of the array,
//   which is stored in RAM via control signals.

module recv_array(
	input wire clk,

	// Flag to begin reading array.
	input wire start,
	output reg done,

	// Wires from rx module.
	input wire rx_valid,
	input wire[7:0] rx_data,

	// Wires to RAM.
	output reg mem_we,
	output reg[15:0] mem_addr,
	output reg[7:0] mem_data,

	// Length as output variable.
	output reg[15:0] len
);
	// Index of array.
	reg[15:0] ptr;

	// LEN: Reading 2 length bytes. DATA: Reading data bytes.
	localparam S_IDLE = 2'd0;
	localparam S_LEN = 2'd1;
	localparam S_DATA = 2'd2;

	reg[1:0] state;


	initial begin
		state <= S_IDLE;
	end

	always @(posedge clk) begin
		done <= 0;
		mem_we <= 0;

		if (state == S_IDLE) begin
			ptr <= 0;
			if (start)
				state <= S_LEN;

		end else if (state == S_LEN) begin
			// Read length: ptr has value either 0 or 1 to keep track.
			if (rx_valid) begin
				if (ptr == 0) begin
					len[7:0] <= rx_data;
					ptr = 1;
				end else if (ptr == 1) begin
					len[15:8] <= rx_data;
					state <= S_DATA;
					ptr = 0;
				end
			end

		end else if (state == S_DATA) begin
			if (rx_valid) begin
				mem_we <= 1;
				mem_addr <= ptr;
				mem_data <= rx_data;
				ptr <= ptr + 1;
			end
			// Done reading.
			if (ptr == len) begin
				done <= 1;
				state <= S_IDLE;
			end
		end
	end
endmodule
