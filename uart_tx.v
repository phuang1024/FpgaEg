// UART module to transmit bytes to computer.
// Set data, and set start signal to high for one clock cycle.
// When done sending the byte, the "done" signal goes high for one cycle.

module uart_tx(
	input wire clk,
	input wire rst,

	input wire[7:0] data,
	input wire start,
	output reg tx,
	// Is true for a single clock cycle once finish transmitting byte.
	output reg done
);
	// FSM states.
	localparam S_IDLE = 1'd0;
	localparam S_DATA = 1'd1;

	reg state;


	// UART clock divider.
	reg baud_tick;
	reg[12:0] baud_clk_counter;
	
	always @(posedge clk) begin
		baud_tick <= 0;

		if (rst || state == S_IDLE) begin
			baud_clk_counter <= 0;

		end else begin
			baud_clk_counter <= baud_clk_counter + 1;
			if (baud_clk_counter == 5208) begin
				baud_tick <= 1;
				baud_clk_counter <= 0;
			end
		end
	end


	// FSM and data sender.
	// NOTE: bit_idx ranges 0 to 9 (inclusive). 0 is start bit, 9 is stop.
	reg[3:0] bit_idx;

	always @(posedge clk) begin
		if (rst) begin
			state <= S_IDLE;

		end else begin
			if (state == S_IDLE) begin
				bit_idx <= 0;
				done <= 0;
				tx <= 1;

				if (start) begin
					state <= S_DATA;
				end

			end else begin
				if (baud_tick) begin
					if (bit_idx == 0)
						tx <= 0;
					else if (bit_idx == 9)
						tx <= 1;
					else
						tx <= data[bit_idx - 1];

					if (bit_idx == 9) begin
						state <= S_IDLE;
						done <= 1;
					end else begin
						bit_idx <= bit_idx + 1;
					end
				end
			end
		end
	end
endmodule