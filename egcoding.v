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
	initial begin
		flag_debug <= 0;
	end

	// Turn rst into a pulse.
	reg rst_pulse;
	btn_pulse rst_pulse_mod(clk, rst, rst_pulse);


	// RX module. "rx" means the UART receiver.
	wire[7:0] rx_data;
	wire rx_valid;
	uart_rx rx_module(
		.clk(clk),
		.rst(rst_pulse),
		.rx(rx),
		.data(rx_data),
		.data_valid(rx_valid)
	);

	// Recv memory. "rmem" means recv memory.
	reg rmem_we;
	reg[15:0] rmem_addr;
	reg[7:0] rmem_din;
	wire[7:0] rmem_dout;
	memory#(
		.DATA_WIDTH(8),
		.ADDR_WIDTH(8)
	) rmem(
		.clk(clk),
		.we(rmem_we),
		.addr(rmem_addr),
		.din(rmem_din),
		.dout(rmem_dout)
	);
	// Length of received array.
	reg[15:0] rmem_len;

	// recv_array FSM submodule. "rmod" means recv module.
	reg rmod_start;
	wire rmod_done;
	wire rmod_we;
	wire[15:0] rmod_addr;
	wire[7:0] rmod_din;
	wire[15:0] rmod_len;
	recv_array recv_mod(
		.clk(clk),
		.start(rmod_start),
		.done(rmod_done),
		.rx_valid(rx_valid),
		.rx_data(rx_data),
		.mem_we(rmod_we),
		.mem_addr(rmod_addr),
		.mem_data(rmod_din),
		.len(rmod_len)
	);


	// TX module. "tx" means UART transmitter.
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

	// Send memory. "tmem" means transmit memory.
	reg tmem_we;
	reg[15:0] tmem_addr;
	reg[7:0] tmem_din;
	wire[7:0] tmem_dout;
	memory#(
		.DATA_WIDTH(16),
		.ADDR_WIDTH(4)
	) tmem(
		.clk(clk),
		.we(tmem_we),
		.addr(tmem_addr),
		.din(tmem_din),
		.dout(tmem_dout)
	);


	// Compressor module. "comp" means compressor.
	reg comp_start;
	wire comp_done;
	wire[7:0] comp_r_addr;
	wire comp_t_we;
	wire[3:0] comp_t_addr;
	wire[15:0] comp_t_din;
	compress compress_mod(
		.clk(clk),
		.start(comp_start),
		.done(comp_done),
		.rmem_addr(comp_r_addr),
		.rmem_dout(rx_dout),
		.rmem_len(rmem_len),
		.tmem_we(comp_t_we),
		.tmem_addr(comp_t_addr),
		.tmem_din(comp_t_din)
	);


	// FSM states.
	// IDLE, RECV, SEND, COMP: Waiting for respective submodules.
	localparam S_IDLE = 3'd0;
	localparam S_RECV = 3'd1;
	localparam S_SEND = 3'd2;
	localparam S_COMP = 3'd3;
	// Wait for TX to finish sending; then return to "state_ret" state.
	localparam S_TX_WAIT = 3'd4;

	reg[2:0] state;
	reg[2:0] state_ret;


	initial begin
		state <= S_IDLE;
	end

	// Main FSM.
	always @(posedge clk) begin
		rmod_start <= 0;
		comp_start <= 0;
		tx_start <= 0;

		if (state == S_IDLE) begin
			// Wait for command byte.
			if (rx_valid) begin
				if (rx_data == 0) begin
					state <= S_RECV;
					rmod_start <= 1;
				end else if (rx_data == 1) begin
					state <= S_COMP;
					comp_start <= 1;
				end
			end

		end else if (state == S_RECV) begin
			// Wait until recv module done.
			if (rmod_done) begin
				state <= S_IDLE;
				rmem_len <= rmod_len;
			end

		end else if (state == S_SEND) begin

		end else if (state == S_COMP) begin
			flag_debug <= 1;
			if (comp_done) begin
				state <= S_TX_WAIT;
				state_ret <= S_IDLE;
				tx_data <= 0;
				tx_start <= 1;
			end

		end else if (state == S_TX_WAIT) begin
			if (tx_done) begin
				state <= state_ret;
			end
		end
	end

	// Memory signal mux.
	always @(*) begin
		rmem_we = 0;
		rmem_addr = 0;
		rmem_din = 0;
		tmem_we = 0;
		tmem_addr = 0;
		tmem_din = 0;
		if (state == S_RECV) begin
			rmem_we = rmod_we;
			rmem_addr = rmod_addr;
			rmem_din = rmod_din;
		end else if (state == S_COMP) begin
			rmem_addr = comp_r_addr;
			tmem_we = comp_t_we;
			tmem_addr = comp_t_addr;
			tmem_din = comp_t_din;
		end
	end
endmodule
