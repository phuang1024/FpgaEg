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
	reg rx_sync1, rx_sync2

	always @(posedge clk) begin
		rx_sync1 <= rx;
		rx_sync2 <= rx_sync1;
	end


	// FSM states.
	// Idle.
	localparam S_IDLE = 2'd0;
	// Received start bit. This state persists for the first half UART cycle to sync.
	localparam S_START = 2'd1;
	// Capturing data. Persists for 8 UART cycles.
	localparam S_DATA = 2'd2;
	
	reg[2:0] state;


	// UART clock divider and syncer.
	// Resp. for switching START -> DATA.
	// 9600 baud = 5208 cycles per tick.
	reg baud_tick;
	reg[12:0] baud_clk_counter;

	always @(posedge clk) begin
		baud_tick <= 0;

		case (state)
		S_IDLE: begin
			baud_clk_counter <= 0;
		end

		S_START: begin
			if (baud_clk_counter >= 2604) begin
				state <= S_DATA;
				baud_clk_counter <= 0;
			end
		end

		S_DATA: begin
			if (baud_clk_counter == 5208) begin
				baud_tick <= 1;
				baud_clk_counter <= 0;
			end
			baud_clk_counter <= baud_clk_counter + 1;
		end
		endcase
	end

endmodule