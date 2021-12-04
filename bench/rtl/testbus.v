////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	testbus.v
// {{{
// Project:	dbgbus, a collection of 8b channel to WB bus debugging protocols
//
// Purpose:	This file composes a top level "demonstration" bus that can
//		be used to prove that things work.  Components contained within
//	this demonstration include:
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2015-2021, Gisselquist Technology, LLC
// {{{
// This file is part of the debugging interface demonstration.
//
// The debugging interface demonstration is free software (firmware): you can
// redistribute it and/or modify it under the terms of the GNU Lesser General 
// Public License as published by the Free Software Foundation, either version
// 3 of the License, or (at your option) any later version.
//
// This debugging interface demonstration is distributed in the hope that it
// will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
// of MERCHANTIBILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser
// General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with this program.  (It's in the $(ROOT)/doc directory.  Run make
// with no target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
// }}}
// License:	LGPL, v3, as defined and found on www.gnu.org,
// {{{
//		http://www.gnu.org/licenses/lgpl.html
//
////////////////////////////////////////////////////////////////////////////////
//
`default_nettype	none
// }}}
module	testbus #(
		// {{{
		// Must match testbus_tb, =4Mb w/ a 100MHz ck
		parameter	UARTSETUP = 25
		// }}}
	) (
		// {{{
		input	wire		i_clk,
		// verilator lint_off UNUSED
		input	wire		i_reset, // Ignored, but needed for our test infra.
		// verilator lint_on UNUSED
		input	wire		i_uart,
		output	wire		o_uart
`ifdef	VERILATOR
		, output reg		o_halt // Tell the SIM when to stop
`endif
		// }}}
	);

	// Local declarations
	// {{{
	wire		rx_stb;
	wire	[7:0]	rx_data;
	wire		tx_stb, tx_busy;
	wire	[7:0]	tx_data;

	// Bus interface wires
	wire	wb_cyc, wb_stb, wb_we;
	wire	[29:0]	wb_addr;
	wire	[31:0]	wb_odata;
	wire	[3:0]	wb_sel;
	reg		wb_ack;
	wire		wb_stall;
	reg		wb_err;
	reg	[31:0]	wb_idata;
	wire		bus_interrupt;

	//
	// Define some wires for returning values to the bus from our various
	// components
	reg	[31:0]	smpl_data;
	wire	[31:0]	mem_data, scop_data;
	wire	smpl_stall, mem_stall, scop_stall;
	wire	scop_int;
	reg	smpl_interrupt;
	wire	scop_ack, mem_ack;
	reg	smpl_ack;

	wire	smpl_sel, scop_sel, mem_sel;

	reg	[31:0]	smpl_register, power_counter;
	reg	[29:0]	bus_err_address;

	wire	none_sel;
	wire	scope_trigger;
	wire	[31:0]	debug_data;
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Serial port
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	rxuartlite #(24,
		.CLOCKS_PER_BAUD(UARTSETUP)
	) rxtransport(
		// {{{
		i_clk, i_uart, rx_stb, rx_data
		// }}}
	);

	txuartlite #(24,
		.CLOCKS_PER_BAUD(UARTSETUP)
	) txtransport(
		// {{{
		i_clk, tx_stb, tx_data, o_uart, tx_busy
		// }}}
	);
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Turn serial bytes into bus requests
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	hbbus
	genbus(
		// {{{
		.i_clk(i_clk),
		// The receive transport wires
		.i_rx_stb(rx_stb), .i_rx_byte(rx_data),
		// The bus control output wires
		.o_wb_cyc(wb_cyc), .o_wb_stb(wb_stb), .o_wb_we(wb_we),
			.o_wb_addr(wb_addr), .o_wb_data(wb_odata),
			.o_wb_sel(wb_sel),
		//	The return bus wires
		.i_wb_stall(wb_stall), .i_wb_ack(wb_ack),
		.i_wb_data(wb_idata), .i_wb_err(wb_err),
		// An interrupt line
		.i_interrupt(bus_interrupt),
		// The return transport wires
		.o_tx_stb(tx_stb), .o_tx_byte(tx_data), .i_tx_busy(tx_busy)
		// }}}
	);
	// }}}
	// Nothing should be assigned to the null page
	assign	smpl_sel = (wb_addr[29:4] == 26'h081);
	assign	scop_sel = (wb_addr[29:4] == 26'h082);
	assign	mem_sel  = (wb_addr[29:12] ==18'h1);

	////////////////////////////////////////////////////////////////////////
	//
	// The "null" device
	// {{{
	//
	// Replaced with looking for nothing being selected
	assign	none_sel = (!smpl_sel)&&(!scop_sel)&&(!mem_sel);

	always @(posedge i_clk)
		wb_err <= (wb_stb)&&(none_sel);

	////////////////////////////////////////////////////////////////////////
	//
	// A "Simple" example device
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	initial	smpl_ack = 1'b0;
	always @(posedge i_clk)
		smpl_ack <= ((wb_stb)&&(smpl_sel));
	assign	smpl_stall = 1'b0;

	always @(posedge i_clk)
	case(wb_addr[3:0])
	4'h0:    smpl_data <= 32'h20170622;
	4'h1:    smpl_data <= smpl_register;
	4'h2:    smpl_data <= { bus_err_address, 2'b00 };
	4'h3:    smpl_data <= power_counter;
	4'h4:    smpl_data <= { 31'h0, smpl_interrupt };
	default: smpl_data <= 32'h00;
	endcase

	// simpl_interrupt, simpl_register, o_halt
	// {{{
	initial	smpl_interrupt = 1'b0;
	always @(posedge i_clk)
	if ((wb_stb)&&(smpl_sel)&&(wb_we))
	begin
		case(wb_addr[3:0])
		4'h1: smpl_register  <= wb_odata;
		4'h4: smpl_interrupt <= wb_odata[0];
`ifdef	VERILATOR
		4'h5: o_halt         <= wb_odata[0];
`endif
		default: begin end
		endcase
	end
	// }}}

	// Start our clocks since power up counter from zero
	initial	power_counter = 0;
	always @(posedge i_clk)
	// Count up from zero until the top bit is set
	if (!power_counter[31])
		power_counter <= power_counter + 1'b1;
	else // Once the top bit is set, keep it set forever
		power_counter[30:0] <= power_counter[30:0] + 1'b1;

	initial	bus_err_address = 0;
	always @(posedge i_clk)
	if (wb_err)
		bus_err_address <= wb_addr;

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// An example block RAM device
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//
	memdev	#(14)
	blkram(
		// {{{
		i_clk, 1'b0, wb_cyc, (wb_stb)&&(mem_sel), wb_we, wb_addr[11:0],
				wb_odata, wb_sel,
			mem_stall, mem_ack, mem_data
		// }}}
	);
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// A wishbone scope
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	assign	scope_trigger = (mem_sel)&&(wb_stb);
	assign	debug_data    = { wb_cyc, wb_stb, wb_we, wb_ack, wb_stall,
			wb_addr[5:0], 1'b1, wb_odata[9:0], wb_idata[9:0] };

	wbscope
	thescope(
		// {{{
		.i_data_clk(i_clk), .i_ce(1'b1), .i_trigger(scope_trigger),
			.i_data(debug_data),
		.i_wb_clk(i_clk), .i_wb_cyc(wb_cyc),
			.i_wb_stb((wb_stb)&&(scop_sel)),
			.i_wb_we(wb_we), .i_wb_addr(wb_addr[0]),
			.i_wb_data(wb_odata), .i_wb_sel(wb_sel),
		.o_wb_stall(scop_stall), .o_wb_ack(scop_ack),
			.o_wb_data(scop_data),
		.o_interrupt(scop_int)
		// }}}
	);
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Bus response composition
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	// Now, let's put those bus responses together
	//
	initial	wb_ack = 1'b0;
	always @(posedge i_clk)
		wb_ack <= (smpl_ack)||(scop_ack)||(mem_ack);

	always @(posedge i_clk)
	if (smpl_ack)
		wb_idata <= smpl_data;
	else if (scop_ack)
		wb_idata <= scop_data;
	else if (mem_ack)
		wb_idata <= mem_data;
	else
		wb_idata <= 32'h0;

	assign	wb_stall = ((smpl_sel)&&(smpl_stall))
			||((scop_sel)&&(scop_stall))
			||((mem_sel)&&(mem_stall));

	assign	bus_interrupt = (smpl_interrupt) | (scop_int);
	// }}}
endmodule
