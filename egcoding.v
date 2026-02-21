module egcoding(
	input wire clk,
	input wire rst,

	input wire rx,

	output wire tx,
	input wire btn_tx,
	output wire tx_busy,

	input wire[7:0] sw,
	output reg[7:0] led
);
	// Small FSM to turn btn_tx into a pulse.
	// 0: idle. 1: pulse on. 2: wait for release.
	reg[1:0] start_fsm;
	reg start_pulse;

	uart_tx tx_module(
		.clk(clk),
		.rst(rst),
		.data(sw),
		.start(start_pulse),
		.tx(tx),
		.busy(tx_busy)
	);

	initial begin
		start_fsm <= 0;
	end

	always @(posedge clk) begin
		start_pulse <= 1;
		if (start_fsm == 0) begin
			if (!btn_tx) begin
				start_fsm <= 1;
			end
		end else if (start_fsm == 1) begin
			start_pulse <= 0;
			start_fsm <= 2;
		end else begin
			if (btn_tx) begin
				start_fsm <= 0;
			end
		end
	end

	always @(posedge clk) begin
		led <= sw;
	end

	/*
	wire[7:0] rx_data;
	wire rx_data_valid;
	uart_rx rx_module(
		.clk(clk),
		.rst(rst),
		.rx(rx),
		.data(rx_data),
		.data_valid(rx_data_valid)
	);

	// Echo RX on LED.
	always @(posedge clk) begin
		if (!rst) begin
			led_out <= 0;

		end else begin
			if (rx_data_valid) begin
				led_out <= rx_data;
			end
		end
	end
	*/
endmodule