// FSM to turn an active low button press into an active high pulse.

module btn_pulse(
	input wire clk,

	input wire in,
	output reg out
);
	// Idle: Button released. Pulse: One clock cycle after press. Pressed: Other clock cycles when pressed.
	localparam S_IDLE = 2'd0;
	localparam S_PULSE = 2'd1;
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