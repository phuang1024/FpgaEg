// FSM to turn an active low button press
// into an active high pulse that lasts 1 cycle.

module btn_pulse(
	input wire clk,

	input wire in,
	output reg out
);
	// Idle: Button released.
	localparam S_IDLE = 2'd0;
	// Pulse: One clock cycle after press. Output 1.
	localparam S_PULSE = 2'd1;
	// Pressed: Other clock cycles when pressed. Output 0.
	localparam S_PRESSED = 2'd2;

	reg[1:0] state;

	initial begin
		state <= S_IDLE;
	end

	always @(posedge clk) begin
		out <= 0;

		if (state == S_IDLE) begin
			if (!in)
				state <= S_PULSE;

		end else begin
			if (state == S_PULSE)
				out <= 1;

			if (!in)
				state <= S_PRESSED;
			else
				state <= S_IDLE;
		end
	end
endmodule