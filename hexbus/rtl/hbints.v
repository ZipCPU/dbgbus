////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	hbints.v
//
// Project:	dbgbus, a collection of 8b channel to WB bus debugging protocols
//
// Purpose:	
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2017, Gisselquist Technology, LLC
//
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
//
// License:	LGPL, v3, as defined and found on www.gnu.org,
//		http://www.gnu.org/licenses/lgpl.html
//
//
////////////////////////////////////////////////////////////////////////////////
//
//
`default_nettype	none
//
//
`define	INT_PREFIX	5'b11010
`define	INT_WORD	{ `INT_PREFIX, {(34-5){1'b0}} }
//
module	hbints(i_clk, i_reset, i_interrupt,
		i_stb,     i_word, o_int_busy,
		o_int_stb, o_int_word, i_busy);
	input	wire		i_clk, i_reset;
	input	wire		i_interrupt;
	//
	input	wire		i_stb;
	input	wire	[33:0]	i_word;
	output	wire		o_int_busy;
	//
	output	reg		o_int_stb;
	output	reg	[33:0]	o_int_word;
	input	wire		i_busy;

	reg	int_state, pending_interrupt;

	initial	int_state = 1'b0;
	initial	pending_interrupt = 1'b0;
	always @(posedge i_clk)
		if (i_reset)
			int_state <= 1'b0;
		else if ((i_interrupt)&&(!int_state))
			int_state <= 1'b1;
		else if ((!pending_interrupt)&&(!i_interrupt))
			int_state <= 1'b0;

	always @(posedge i_clk)
		if (i_reset)
			pending_interrupt <= 1'b0;
		else if ((i_interrupt)&&(!int_state))
			pending_interrupt <= 1'b1;
		else if ((o_int_stb)&&(!i_busy)
				&&(o_int_word[33:29] == `INT_PREFIX))
			pending_interrupt <= 1'b0;

	reg	loaded;
	initial	loaded = 1'b0;
	always @(posedge i_clk)
		if (i_reset)
			loaded <= 1'b0;
		else if (i_stb)
			loaded <= 1'b1;
		else if ((o_int_stb)&&(!i_busy))
			loaded <= 1'b0;

	initial	o_int_stb = 1'b0;
	always @(posedge i_clk)
		if (i_reset)
			o_int_stb <= 1'b0;
		else if (i_stb)
			o_int_stb <= 1'b1;
		else if (pending_interrupt)
			o_int_stb <= 1'b1;
		else if ((!loaded)||(!i_busy))
			o_int_stb <= 1'b0;

	initial	o_int_word = `INT_WORD;
	always @(posedge i_clk)
		if (i_stb)
			o_int_word <= i_word;
		else if ((pending_interrupt)&&(!loaded))
			// Send an interrupt
			o_int_word <= `INT_WORD;

	assign	o_int_busy = (o_int_stb)&&(loaded);

endmodule
