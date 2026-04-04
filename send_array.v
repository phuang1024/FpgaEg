// Similar to recv_array, but sends data to computer.

module send_array(
	input wire clk,

	// Flag to begin reading array.
	input wire start,
	output reg done,

	// Wires from tx module.
	output reg tx_start,
	output reg[7:0] tx_data,
	input wire tx_done,

	// Wires to tmem.
	output reg[15:0] mem_addr,
	input wire[7:0] mem_data,

	// Length.
	input wire[15:0] len
);
	// Index of array.
	reg[15:0] ptr;

	// Misc counter for S_DATA waiting.
	reg[7:0] counter;

	localparam S_IDLE = 3'd0;
	// Sending 2 length bytes.
	localparam S_LEN = 3'd1;
	// Set addr and data. Wait a few cycles.
	localparam S_DATA = 3'd2;
	// Signal TX to start.
	localparam S_SEND = 3'd3;
	// Set done to 1 for a cycle.
	localparam S_DONE = 3'd4;
	// Wait for TX to finish, similar to main module.
	localparam S_TX_WAIT = 3'd5;

	reg[2:0] state;
	reg[2:0] state_ret;


	initial begin
		state <= S_IDLE;
	end

	always @(posedge clk) begin
		done <= 0;
		tx_start <= 0;

		if (state == S_IDLE) begin
			counter <= 0;
			ptr <= 0;
			if (start)
				state <= S_LEN;

		end else if (state == S_LEN) begin
			// Write length: ptr has value either 0 or 1 to keep track.
			if (ptr == 0) begin
				tx_data <= len[7:0];
				tx_start <= 1;
				ptr = 1;
				state <= S_TX_WAIT;
				state_ret <= S_LEN;
			end else if (ptr == 1) begin
				tx_data <= len[15:8];
				tx_start <= 1;
				ptr = 0;
				state <= S_TX_WAIT;
				state_ret <= S_DATA;
			end

		end else if (state == S_DATA) begin
			// Set tx_data = mem[ptr]
			mem_addr <= ptr;
			tx_data <= mem_data;

			counter <= counter + 1;
			if (counter == 10)
				state <= S_SEND;

		end else if (state == S_SEND) begin
			tx_start <= 1;
			ptr <= ptr + 1;

			counter <= 0;

			// Check if done.
			if (ptr == len - 1) begin
				state_ret <= S_DONE;
			end else begin
				state_ret <= S_DATA;
			end
			state <= S_TX_WAIT;

		end else if (state == S_DONE) begin
			done <= 1;
			state <= S_IDLE;

		end else if (state == S_TX_WAIT) begin
			if (tx_done) begin
				state <= state_ret;
			end
		end
	end
endmodule
