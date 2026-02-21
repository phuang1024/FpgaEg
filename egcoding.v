module egcoding(
	input wire clk,
	input wire rst,
	input wire rx,
	input wire tx,
	output reg[7:0] led_out
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

	always @(posedge clk) begin
		if (!rst) begin
			led_out <= 0;

		end else begin
			if (rx_data_valid) begin
				led_out <= rx_data;
			end
		end
	end
endmodule