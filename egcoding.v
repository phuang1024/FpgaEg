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

// Compress:
//		FPGA begins compressing.
//		When done, returns a single byte:
//			0 if success, 1 if error.

// Write result:
// 	FPGA sends:
//		2 bytes little endian of data length.
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


	// Input data array.
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


	// Output data array.
	reg[7:0] tx_mem[255:0];
	reg[15:0] tx_mem_len;
	reg[15:0] tx_mem_ptr;

	reg[7:0] tx_data;
	reg tx_start;
	wire tx_done;
	uart_tx tx_module(
		.clk(clk),
		.rst(rst_pulse),
		.data(tx_data),
		.start(tx_start),
		.tx(tx),
		.done(tx_done)
	);


	// Idle. Waiting for rx transmission to start.
	localparam S_IDLE = 4'd0;
	// Reading length bytes. Uses rx_mem_ptr= 0 or 1 as indicator.
	localparam S_READ_LEN = 4'd1;
	// Reading data bytes.
	localparam S_READ_DATA = 4'd2;

	// Doing EG compression.
	localparam S_COMPRESS = 4'd3;
	// Done with compression, waiting for TX status byte.
	localparam S_COMPRESS_DONE = 4'd4;

	// TX states are more numerous because need to wait for tx module each byte.
	// Write two length bytes.
	localparam S_WRITE_LEN1 = 4'd5;
	localparam S_WRITE_LEN1D = 4'd6;
	localparam S_WRITE_LEN2 = 4'd7;
	localparam S_WRITE_LEN2D = 4'd8;
	// Writing data bytes.
	localparam S_WRITE_DATA = 4'd9;
	localparam S_WRITE_DATAD = 4'd10;

	reg[3:0] state;

	initial begin
		state <= S_IDLE;
	end

	// Main FSM.
	always @(posedge clk) begin
		if (state == S_IDLE) begin
			// Recv command byte.
			if (rx_valid) begin
				if (rx_data == 0) begin
					state <= S_READ_LEN;
					rx_mem_len <= 0;
					rx_mem_ptr <= 0;
				end else if (rx_data == 1) begin
					state <= S_COMPRESS;
					rx_mem_ptr <= 0;
					tx_mem_ptr <= 0;
				end else if (rx_data == 2) begin
					state <= S_WRITE_LEN1;
					// TODO more
				end
			end

		// Read data.
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

		// Compression.
		end else if (state == S_COMPRESS) begin
			if (rx_mem_ptr == rx_mem_len) begin
				// Finished. Send a 0 byte next cycle.
				tx_data <= 0;
				tx_start <= 1;
				state <= S_COMPRESS_DONE;
			end else begin
				// TODO dummy copy
				tx_mem[tx_mem_ptr] <= rx_mem[rx_mem_ptr];
				rx_mem_ptr <= rx_mem_ptr + 1;
				tx_mem_ptr <= tx_mem_ptr + 1;
			end
		end else if (state == S_COMPRESS_DONE) begin
			tx_mem_len <= tx_mem_ptr;
	
			// Done sending 0 byte.
			tx_start <= 0;
			if (tx_done)
				state <= S_IDLE;

		// Write result.
		end else if (state == S_WRITE_LEN1) begin
			tx_data <= tx_mem_len[7:0];
			tx_start <= 1;
			state <= S_WRITE_LEN1D;
		end else if (state == S_WRITE_LEN1D) begin
			tx_start <= 0;
			if (tx_done)
				state <= S_WRITE_LEN2;
		end else if (state == S_WRITE_LEN2) begin
			tx_data <= tx_mem_len[15:8];
			tx_start <= 1;
			state <= S_WRITE_LEN2D;
		end else if (state == S_WRITE_LEN2D) begin
			tx_start <= 0;
			tx_mem_ptr <= 0;
			if (tx_done)
				state <= S_WRITE_DATA;

		end else if (state == S_WRITE_DATA) begin
			tx_data <= tx_mem[tx_mem_ptr];
			tx_mem_ptr <= tx_mem_ptr + 1;
			tx_start <= 1;
			state <= S_WRITE_DATAD;
		end else if (state == S_WRITE_DATAD) begin
			tx_start <= 0;
			if (tx_done) begin
				if (tx_mem_ptr == tx_mem_len)
					state <= S_IDLE;
				else
					state <= S_WRITE_DATA;
			end
		end
	end
endmodule