module egcoding(
	input wire clk,
	input wire rst,

	input wire rx,
	output wire tx,

	input wire test_in,
	output reg test_out
);
	reg rst_pulse;
	btn_pulse rst_pulse_mod(clk, rst, rst_pulse);

	wire[7:0] rx_data;
	wire rx_valid;
	uart_rx rx_module(
		.clk(clk),
		.rst(rst_pulse),
		.rx(rx),
		.data(rx_data),
		.data_valid(rx_valid)
	);

	/*
	uart_tx tx_module(
		.clk(clk),
		.rst(rst_pulse),
		.data(sw),
		.start(start_pulse),
		.tx(tx),
		.busy(tx_busy)
	);
	*/

endmodule