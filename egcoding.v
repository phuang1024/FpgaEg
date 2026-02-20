module egcoding(
	input wire clk,
	input wire rst,
	input wire rx,
	input wire tx
);
	wire[7:0] rx_data;
	wire rx_data_valid;
	uart_rx rx_module(
		.clk(clk),
		.rst(rst),
		.rx(rx),
		.data(rx_data),
		.data_valid(rx_data_valid)
	);
endmodule