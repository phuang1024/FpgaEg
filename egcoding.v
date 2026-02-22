// EG coding module. Interface:
// Communication rx and tx is UART 8N1.
// Expects a single command byte from computer.
//		0: Read data.
//		1: Compress.
// 	2: Write result.

// Read data:
// 	Computer subsequently sends:
//		2 bytes little endian of data length (in bytes).
//		Data as byte array.

module egcoding(
	input wire clk,
	input wire rst,
	output reg clk_debug,

	input wire rx,
	output reg tx
);
	// Clock divider for debugging.
	//reg clk_debug;
	reg[10:0] clk_debug_counter;
	always @(posedge clk) begin
		clk_debug <= 0;
		if (clk_debug_counter == 0)
			clk_debug <= 1;
		clk_debug_counter <= clk_debug_counter + 1;
	end

	// Turn rst into a pulse.
	reg rst_pulse;
	btn_pulse rst_pulse_mod(clk, rst, rst_pulse);

	// Data array read from rx.
	reg[7:0] rx_mem[255:0];
	// Length of rx data array.
	reg[15:0] rx_mem_len;
	// Index of rx data array, used for r/w.
	reg[15:0] rx_mem_ptr;

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

	// Idle. Waiting for rx transmission to start.
	localparam S_IDLE = 2'd0;
	// Reading length bytes. Uses rx_mem_ptr= 0 or 1 as indicator.
	localparam S_READ_LEN = 2'd1;
	// Reading data bytes.
	localparam S_READ_DATA = 2'd2;

	reg[1:0] state;

	initial begin
		state <= S_IDLE;
	end

	always @(posedge clk) begin
		if (state == S_IDLE) begin
			// Recv command byte.
			if (rx_valid) begin
				if (rx_data == 0) begin
					state <= S_READ_LEN;
					rx_mem_len <= 0;
					rx_mem_ptr <= 0;
				end
			end

		end else if (state == S_READ_LEN) begin
			if (rx_valid) begin
				if (rx_mem_ptr == 0) begin
					rx_mem_len[7:0] = rx_data;
					rx_mem_ptr = 1;
				end else if (rx_mem_ptr == 1) begin
					rx_mem_len[15:8] = rx_data;
					state <= S_READ_DATA;
					rx_mem_ptr = 0;
				end
			end

		end else if (state == S_READ_DATA) begin
			if (rx_valid) begin
				rx_mem[rx_mem_ptr] <= rx_data;
				rx_mem_ptr <= rx_mem_ptr + 1;
			end
			if (rx_mem_ptr == rx_mem_len) begin
				state <= S_IDLE;
			end
		end
	end
endmodule