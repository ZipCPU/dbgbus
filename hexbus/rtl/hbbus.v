////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	hbbus.v
// {{{
// Project:	dbgbus, a collection of 8b channel to WB bus debugging protocols
//
// Purpose:	This is the top level of the debug bus itself, converting
//		8-bit input words to bus requests and bus returns to outgoing
//	8-bit words.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2017-2021, Gisselquist Technology, LLC
// {{{
// This file is part of the hexbus debugging interface.
//
// The hexbus interface is free software (firmware): you can redistribute it
// and/or modify it under the terms of the GNU Lesser General Public License
// as published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// The hexbus interface is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public License
// for more details.
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
module	hbbus #(
		// {{{
		parameter	AW=30,
		localparam	DW=32
		// }}}
	) (
		// {{{
		input	wire		i_clk,
		input	wire		i_rx_stb,
		input	wire	[7:0]	i_rx_byte,
		output	wire		o_wb_cyc, o_wb_stb, o_wb_we,
		output	wire	[(AW-1):0]	o_wb_addr,
		output	wire	[(DW-1):0]	o_wb_data,
		output	wire	[(DW/8-1):0]	o_wb_sel,
		input	wire			i_wb_stall, i_wb_ack,
		input	wire	[(DW-1):0]	i_wb_data,
		input	wire			i_wb_err,
		input	wire			i_interrupt,
		output	wire			o_tx_stb,
		output	wire	[7:0]		o_tx_byte,
		input	wire			i_tx_busy
		// }}}
	);

	// Local declarations
	// {{{
	wire		w_reset;
	wire		dec_stb;
	wire	[4:0]	dec_bits;
	wire		iw_stb;
	wire	[33:0]	iw_word;
	wire		ow_stb;
	wire	[33:0]	ow_word;
	wire		idl_busy, int_stb;
	wire	[33:0]	int_word;
	wire		hb_busy, idl_stb;
	wire	[33:0]	idl_word;
	wire		hb_stb, hx_busy;
	wire	[4:0]	hb_bits;
	wire		hx_stb, nl_busy;
	wire	[6:0]	hx_byte;
	// verilator lint_off UNUSED
	wire		wb_busy;
	wire		int_busy;
	// verilator lint_on UNUSED
	// }}}

	//
	//
	// The incoming stream ...
	//
	//
	// First step, convert the incoming bytes into bits
	hbdechex
	dechxi(
		// {{{
		.i_clk(i_clk),
		.i_stb(i_rx_stb), .i_byte(i_rx_byte),
		.o_dh_stb(dec_stb), .o_reset(w_reset), .o_dh_bits(dec_bits)
		// }}}
	);


	// ... that can then be transformed into bus command words
	hbpack	packxi(
		// {{{
		.i_clk(i_clk), .i_reset(w_reset),
		.i_stb(dec_stb), .i_bits(dec_bits),
		.o_pck_stb(iw_stb), .o_pck_word(iw_word)
		// }}}
	);

	//
	// We'll use these bus command words to drive a wishbone bus
	//
	hbexec	#(AW)
	wbexec(
		// {{{
		.i_clk(i_clk), .i_reset(w_reset),
		.i_cmd_stb(iw_stb), .i_cmd_word(iw_word), .o_cmd_busy(wb_busy),
		.o_rsp_stb(ow_stb), .o_rsp_word(ow_word),
		.o_wb_cyc(o_wb_cyc), .o_wb_stb(o_wb_stb),
			.o_wb_we(o_wb_we), .o_wb_addr(o_wb_addr),
			.o_wb_data(o_wb_data), .o_wb_sel(o_wb_sel),
		.i_wb_stall(i_wb_stall), .i_wb_ack(i_wb_ack),
			.i_wb_err(i_wb_err), .i_wb_data(i_wb_data)
		// }}}
	);

	// We'll then take the responses from the bus, and add an interrupt
	// flag to the output any time things are idle.  This also acts
	// as a one-stage FIFO
	hbints
	addints(
		// {{{
		.i_clk(i_clk), .i_reset(w_reset), .i_interrupt(i_interrupt),
		.i_stb(ow_stb), .i_word( ow_word), .o_int_busy(int_busy),
		.o_int_stb(int_stb), .o_int_word(int_word), .i_busy(idl_busy)
		// }}}
	);

	//
	//
	//
	hbidle
	addidles(
		// {{{
		.i_clk(i_clk), .i_reset(w_reset),
			.i_cmd_stb(int_stb), .i_cmd_word(int_word),
				.o_idl_busy(idl_busy),
			.o_idl_stb(idl_stb), .o_idl_word(idl_word),
				.i_busy(hb_busy)
		// }}}
	);

	// We'll then take that ouput from that stage, and disassemble the
	// response word into smaller (5-bit) sized units ...
	hbdeword
	unpackx(
		// {{{
		.i_clk(i_clk), .i_reset(w_reset),
		.i_stb(idl_stb), .i_word(idl_word), .o_dw_busy(hb_busy),
		.o_dw_stb(hb_stb), .o_dw_bits(hb_bits), .i_tx_busy(hx_busy)
		// }}}
	);

	// ... that can then be transmitted back down the channel
	hbgenhex
	genhex(
		// {{{
		.i_clk(i_clk), .i_reset(w_reset),
		.i_stb(hb_stb), .i_bits(hb_bits), .o_gx_busy(hx_busy),
		.o_gx_stb(hx_stb), .o_gx_char(hx_byte), .i_busy(nl_busy)
		// }}}
	);

	//
	// We'll also add carriage return newline pairs any time the channel
	// goes idle
	hbnewline
	addnl(
		// {{{
		.i_clk(i_clk), .i_reset(w_reset),
		.i_stb(hx_stb), .i_byte(hx_byte), .o_nl_busy(nl_busy),
		.o_nl_stb(o_tx_stb), .o_nl_byte(o_tx_byte[6:0]),
			.i_busy(i_tx_busy)
		// }}}
	);

	assign	o_tx_byte[7] = 1'b0;

endmodule
