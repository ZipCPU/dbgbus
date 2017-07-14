////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	hbnewlines.v
//
// Project:	dbgbus, a collection of 8b channel to WB bus debugging protocols
//
// Purpose:	Add a newline to the response stream any time the receive bus
//		goes from busy to idle.
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
module	hbnewline(i_clk, i_reset,
		i_stb, i_byte, o_nl_busy,
		o_nl_stb, o_nl_byte, i_busy);
	input	wire	i_clk, i_reset;
	//
	input	wire		i_stb;
	input	wire	[7:0]	i_byte;
	output	wire		o_nl_busy;
	//
	output	reg		o_nl_stb;
	output	reg	[7:0]	o_nl_byte;
	input	wire		i_busy;

	// LAST_CR will be true any time we have sent a carriage return, but
	// have not yet sent any valid words.  Hence, once the valid words
	// stop, last_cr will go true and a carriage return will be sent.
	// No further carriage returns will be sent until after the next
	// valid word.
	reg	last_cr;

	// CR_STATE will be true any time we have sent a carriage return, but
	// not the following newline
	reg	cr_state;

	// The loaded register indicates whether or not we have a valid
	// command word (that cannot be interrupted) loaded into our buffer.
	// Valid words are anything given us from our input, as well as the
	// line-feed following a carriage return.  We use this logic so that
	// a desired output that should only be output when the bus is idle
	// (such as a newline) can be pre-empted when a new command comes
	// down the interface, but before the bus has had a chance to become
	// idle.
	reg	loaded;

	initial	last_cr  = 1'b1;
	initial	cr_state = 1'b0;
	always @(posedge i_clk)
		if (i_reset)
		begin
			cr_state <= 1'b0;
			last_cr  <= 1'b0;
			o_nl_stb <= 1'b0;
		end else if ((i_stb)&&(!o_nl_busy))
		begin
			o_nl_stb  <= i_stb;
			o_nl_byte <= i_byte;
			cr_state <= 1'b0;
			last_cr <= (i_byte[7:0] == 8'hd);
			loaded  <= 1'b1;
		end else if (!i_busy)
		begin
			if (!last_cr)
			begin
				cr_state  <= (!i_stb);
				o_nl_byte <= 8'hd;
				last_cr   <= (!i_stb);
				o_nl_stb  <= (!i_stb);
				loaded    <= 1'b0;
			end else if (cr_state)
			begin
				cr_state  <= 1'b0;
				o_nl_byte <= 8'ha;
				o_nl_stb  <= 1'b1;
				loaded  <= 1'b1;
			end else
			begin
				o_nl_stb  <= 1'b0;
				o_nl_byte <= 8'hff;
			end
		end

	assign	o_nl_busy = (o_nl_stb)&&(loaded);

endmodule
