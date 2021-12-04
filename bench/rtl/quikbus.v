////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	quikbus.v
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
module	quikbus #(
		// UARTSETUP must match testbus_tb, =4Mb w/ a 100MHz ck
		parameter	UARTSETUP = 25
	) (
		// {{{
		input	wire		i_clk,
		input	wire		i_uart,
		output	wire		o_uart,
		input	wire		i_scope_ce, i_scope_trigger,
		input	wire [31:0]	i_scope_data
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
	wire		wb_ack;
	wire		wb_stall;
	wire		wb_err;
	wire	[31:0]	wb_idata;
	wire		scop_int;

	//
	// Define some wires for returning values to the bus from our various
	// components
	wire	[31:0]	scop_data;
	wire		scop_stall;
	wire		scop_ack;
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Control the design via the serial port
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	rxuartlite #(
		.CLOCKS_PER_BAUD(UARTSETUP)
	) rxtransport(
		// {{{
		i_clk, i_uart, rx_stb, rx_data
		// }}}
	);

	txuartlite #(
		.CLOCKS_PER_BAUD(UARTSETUP)
	) txtransport(
		// {{{
		i_clk, tx_stb, tx_data, o_uart, tx_busy
		// }}}
	);

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Convert serial data to bus commands and back
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
		.i_interrupt(scop_int),
		// The return transport wires
		.o_tx_stb(tx_stb), .o_tx_byte(tx_data), .i_tx_busy(tx_busy)
		// }}}
	);

	assign	wb_err = 1'b0;
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// A wishbone scope -- the goal of this design
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	wbscope
	thescope(
		// {{{
		.i_data_clk(i_clk), .i_ce(i_scope_ce),
			.i_trigger(i_scope_trigger), .i_data(i_scope_data),
		.i_wb_clk(i_clk), .i_wb_cyc(wb_cyc), .i_wb_stb(wb_stb),
			.i_wb_we(wb_we), .i_wb_addr(wb_addr[0]),
			.i_wb_data(wb_odata), .i_wb_sel(4'hf),
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
	assign	wb_ack   = scop_ack;
	assign	wb_idata = scop_data;
	assign	wb_stall = scop_stall;
	// }}}

	// Make verilator happy
	// {{{
	// verilator lint_off UNUSED
	wire	unused;
	assign	unused = &{ 1'b0, wb_addr[29:1], wb_sel };
	// verilator lint_on  UNUSED
	// }}}
endmodule
