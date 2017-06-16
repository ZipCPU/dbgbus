////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	hbgenhex.v
//
// Project:	dbgbus, a collection of 8b channel to WB bus debugging protocols
//
// Purpose:	Supports a conversion from a five digit channel to a printable
//		ASCII character representing the lower four bits, or special
//	command characters instead if the MSB (fifth bit) is set.  We use an
//	lowercase hexadecimal for the conversion as follows:
//
//		1'b0,0-9	->	0-9
//		1'b0,10-15	->	a-f
//
//	Other out of band characters are:
//
//	5'h10	-> R	(Read)
//	5'h11	-> W	(Write)
//	5'h12	-> A	(Address)
//	5'h13	-> S	(Special)
//	5'h14	-> I	(Interrupt)
//	5'h15	-> Z	(IDLE)
//	5'h16	-> T	(Reset)
//
//	All others characters will cause a carriage return, newline pair
//	to be sent, with the exception that duplicate carriage return, newlin
//	pairs will be suppressed.
//
//
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
module	hbgenhex(i_clk, i_stb, i_bits, o_gx_busy, o_gx_stb, o_gx_char, i_busy);
	input	wire		i_clk;
	input	wire		i_stb;
	input	wire	[4:0]	i_bits;
	output	wire		o_gx_busy;
	output	reg		o_gx_stb;
	output	reg	[7:0]	o_gx_char;
	input	wire		i_busy;

	initial	o_gx_stb    = 1'b0;
	always @(posedge i_clk)
		if ((i_stb)&&(!o_gx_busy))
			o_gx_stb <= 1'b1;
		else if (!i_busy)
			o_gx_stb <= 1'b0;

	initial	o_gx_char = 8'h00;
	always @(posedge i_clk)
		if ((i_stb)&&(!o_gx_busy))
		begin
			case(i_bits)
			5'h00: o_gx_char <= "0";
			5'h01: o_gx_char <= "1";
			5'h02: o_gx_char <= "2";
			5'h03: o_gx_char <= "3";
			5'h04: o_gx_char <= "4";
			5'h05: o_gx_char <= "5";
			5'h06: o_gx_char <= "6";
			5'h07: o_gx_char <= "7";
			5'h08: o_gx_char <= "8";
			5'h09: o_gx_char <= "9";
			5'h0a: o_gx_char <= "a";
			5'h0b: o_gx_char <= "b";
			5'h0c: o_gx_char <= "c";
			5'h0d: o_gx_char <= "d";
			5'h0e: o_gx_char <= "e";
			5'h0f: o_gx_char <= "f";
			//
			5'h10: o_gx_char <= "R";	// Read response w/data
			5'h11: o_gx_char <= "K";	// Write ACK
			5'h12: o_gx_char <= "A";	// Address was set
			5'h13: o_gx_char <= "S";	// Special
			//
			5'h18: o_gx_char <= "T";	// reseT
			5'h19: o_gx_char <= "E";	// BUS Error
			5'h1a: o_gx_char <= "I";	// Interrupt
			5'h1b: o_gx_char <= "Z";	// I'm here, but slping
			default: o_gx_char <= 8'hd;	// Carriage return
			endcase
		end

	assign	o_gx_busy = o_gx_stb;

endmodule

