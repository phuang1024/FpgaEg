// UART receiver.
// Automatically divides clock, detects start bit, and syncs input.
// Output flag data_valid set to 1 for one clock cycle when done.

module uart_rx(
	input wire clk,
	input wire rst,
	input wire rx,
	output reg[7:0] data,
	output reg data_valid
);
	// 2FF synchronizer.
	reg rx_sync1, rx_sync2;

	always @(posedge clk) begin
		rx_sync1 <= rx;
		rx_sync2 <= rx_sync1;
	end


	// FSM states.
	// Idle.
	localparam S_IDLE = 2'd0;
	// Received start bit. This state persists for 1.5 UART cycles until first baud tick.
	localparam S_START = 2'd1;
	// Capturing data. Persists for the remaining 7 UART cycles.
	localparam S_DATA = 2'd2;
	// Done capturing. Wait until rx goes high.
	localparam S_STOP = 2'd3;

	reg[1:0] state;


	// UART clock divider and syncer.
	// 9600 baud = 5208 cycles per tick.
	reg baud_tick;
	reg[12:0] baud_clk_counter;

	always @(posedge clk) begin
		if (!rst) begin
			baud_tick <= 0;
			baud_clk_counter <= 0;

		end else begin
			baud_tick <= 0;

			// IDLE or STOP
			if (state == S_IDLE || state == S_STOP) begin
				baud_clk_counter <= 0;

			// else
			end else begin
				baud_clk_counter <= baud_clk_counter + 1;
				if ((state == S_START && baud_clk_counter >= 7812) ||
					 (state == S_DATA && baud_clk_counter >= 5208)) begin
					baud_tick <= 1;
					baud_clk_counter <= 0;
				end
			end
		end
	end


	// Data capturer.
	reg[2:0] bit_idx;

	always @(posedge clk) begin
		if (!rst) begin
			state <= S_IDLE;
			data_valid <= 0;
			bit_idx <= 0;

		end else begin
			data_valid <= 0;

			// IDLE
			if (state == S_IDLE) begin
				bit_idx <= 0;
				if (!rx_sync2)
					state <= S_START;

			// STOP
			end else if (state == S_STOP) begin
				if (rx_sync2)
					state <= S_IDLE;

			// else
			end else begin
				if (baud_tick) begin
					state <= S_DATA;

					data[bit_idx] <= rx_sync2;

					if (bit_idx == 7) begin
						state <= S_STOP;
						data_valid <= 1;
					end else begin
						bit_idx <= bit_idx + 1;
					end
				end
			end
		end
	end

endmodule