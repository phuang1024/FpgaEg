// Main EG coding module.
// This is a big FSM that has three modes of operation (below).
// Communication rx and tx is UART 8N1.

// Steps of EG coding:
// 1. Add one to value.
// 2. Write N-1 zero bits, where N is the length of the new value in bits.
// 3. Write the value, MSB of the value first, MSB of the result byte first.

// Expects a single command byte from computer.
//		0: Read data.
//		1: Compress.
// 	2: Write result.

// Read data:
// 	Computer subsequently sends:
//		2 bytes little endian: Data length (in bytes).
//		Data as byte array.
//		Step 1 of EG coding is done here; add 1 to all data values.

// Compress:
//		FPGA begins compressing.
//		When done, returns a single byte:
//			0 if success, 1 if error.
// 	Steps 2 and 3 are done here.

// Write result:
// 	FPGA sends:
//		2 bytes little endian: Data length.
//		Data as byte array.

// The module keeps two buffers: Input and output buffer.
// "Read data": Data is read into input buffer.
// "Compress": Generate EG compressed data in output buffer.
// "Write result": Transmits data in output buffer.

// Buffers implemented as byte register array length 255.

module egcoding(
	input wire clk,
	input wire rst,
	// Misc debug trigger signals.
	output reg clk_debug,
	output reg flag_debug,

	input wire rx,
	output reg tx
);
	// Clock divider for debugging.
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


	// RX module.
	wire[7:0] rx_data;
	wire rx_valid;
	uart_rx rx_module(
		.clk(clk),
		.rst(rst_pulse),
		.rx(rx),
		.data(rx_data),
		.data_valid(rx_valid)
	);

	// Recv memory.
	reg rx_we;
	reg[15:0] rx_addr;
	reg[7:0] rx_din;
	wire[7:0] rx_dout;
	memory rx_mem(
		.clk(clk),
		.we(rx_we),
		.addr(rx_addr),
		.din(rx_din),
		.dout(rx_dout)
	);

	// Recv array FSM module.
	wire rmod_we;
	wire[15:0] rmod_addr;
	wire[7:0] rmod_din;
	wire[15:0] rx_len;
	recv_array recv_mod(
		.clk(clk),
		.start(recv_start),
		.rx_valid(rx_valid),
		.rx_data(rx_data),
		.mem_we(rmod_we),
		.mem_addr(rmod_addr),
		.mem_data(rmod_din),
		.len(rx_len)
	);


	
	
	
	///////////////////////TODO!!!!!

	// Output data as bit array.
	// Data is written from index 0 up; MSB of encoded data written first.
	reg tx_mem[255:0];
	reg[15:0] tx_mem_len;
	reg[15:0] tx_mem_ptr;
	// Write port.
	reg tx_mem_we;
	reg[15:0] tx_mem_addr;
	reg[15:0] tx_mem_data;

	// TX module.
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


	// Index i is num of bits of i.
	reg[3:0] size_lut[255:0];
	// Current value to compress.
	reg[7:0] curr_value;
	// Number of bits in current value to compress.
	reg[3:0] curr_size;
	// Misc iteration variable.
	integer i;


	// Idle. Waiting for rx transmission to start.
	localparam S_IDLE = 4'd0;

	// Reading length bytes. Uses rx_mem_ptr= 0 or 1 as indicator.
	localparam S_READ_LEN = 4'd1;
	// Reading data bytes.
	localparam S_READ_DATA = 4'd2;

	// Extract value and value size.
	localparam S_COMP_START = 4'd3;
	// Write compressed value to memory.
	localparam S_COMP_WRITE = 4'd4;
	// Done with compression, waiting for TX status byte.
	localparam S_COMP_DONE = 4'd5;

	// TX states are more numerous because need to wait for tx module each byte.
	// Write two length bytes.
	localparam S_WRITE_LEN1 = 4'd6;
	localparam S_WRITE_LEN1D = 4'd7;
	localparam S_WRITE_LEN2 = 4'd8;
	localparam S_WRITE_LEN2D = 4'd9;
	// Writing data bytes.
	localparam S_WRITE_DATA = 4'd10;
	localparam S_WRITE_DATAD = 4'd11;

	reg[3:0] state;


	initial begin
		state <= S_IDLE;
		flag_debug <= 0;
	end
	
	initial begin
		$readmemh("num_bits.hex", size_lut);
	end
	
	// Write port for tx_mem
	always @(posedge clk) begin
		if (tx_mem_we) begin
			for (i = 0; i < 16; i = i + 1) begin
				tx_mem[tx_mem_addr + i] <= tx_mem_data[i];
			end
		end
	end

	// Main FSM.
	always @(posedge clk) begin
		// Recv command byte.
		if (state == S_IDLE) begin
			if (rx_valid) begin
				if (rx_data == 0) begin
					state <= S_READ_LEN;
					rx_mem_len <= 0;
					rx_mem_ptr <= 0;
				end else if (rx_data == 1) begin
					state <= S_COMP_START;
					rx_mem_ptr <= 0;
					tx_mem_ptr <= 0;
				end else if (rx_data == 2) begin
					state <= S_WRITE_LEN1;
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
		end else if (state == S_COMP_START) begin
			flag_debug <= 1;
			tx_mem_we <= 0;
			// Check if done.
			if (rx_mem_ptr == rx_mem_len) begin
				// Send a 0 byte next cycle via tx.
				tx_data <= 0;
				tx_start <= 1;

				tx_mem_len <= tx_mem_ptr;
				state <= S_COMP_DONE;

			end else begin
				// Add one, part of EG coding algorithm.
				curr_value <= rx_mem[rx_mem_ptr] + 1;
				curr_size <= size_lut[rx_mem[rx_mem_ptr] + 1];
				state <= S_COMP_WRITE;
			end
		end else if (state == S_COMP_WRITE) begin
			tx_mem_we <= 1;
			tx_mem_addr <= tx_mem_ptr;
			// Write zeros and data simultaneously.
			// Zero: Index ptr to ptr+size-2, inclusive. size-1 bits total.
			// Data: Index ptr+size-1 to ptr+size+size-2, inclusive. size bits total.
			// Overall, 2size-1 bits total.
			for (i = 0; i < 8; i = i + 1) begin
				if (i < curr_size - 1)
					tx_mem_data[i] <= 0;
				if (i < curr_size)
					tx_mem_data[curr_size - 1 + i] <= curr_value[curr_size - i - 1];
			end
			tx_mem_ptr <= tx_mem_ptr + curr_size + curr_size - 1;
			rx_mem_ptr <= rx_mem_ptr + 1;
			state <= S_COMP_START;
		end else if (state == S_COMP_DONE) begin
			tx_mem_we <= 0;
			// Wait until done sending 0 byte.
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
			for (i = 0; i < 8; i = i + 1) begin
				tx_data[7 - i] <= tx_mem[tx_mem_ptr + i];
			end
			tx_mem_ptr <= tx_mem_ptr + 8;
			tx_start <= 1;
			state <= S_WRITE_DATAD;
		end else if (state == S_WRITE_DATAD) begin
			tx_start <= 0;
			if (tx_done) begin
				if (tx_mem_ptr >= tx_mem_len)
					state <= S_IDLE;
				else
					state <= S_WRITE_DATA;
			end
		end
	end
endmodule
