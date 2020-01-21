////////////////////////////////////////////////////////////////////////////////
//
// Filename:	hbconsole.v
//
// Project:	FPGA library
//
// Purpose:	This is a replacement wrapper to the original hbbus.v debugging
//		bus module.  It is intended to provide all of the functionality
//	of hbbus, while ...
//
//	1. Keeping the debugging bus within the lower 7-bits of the byte
//	2. Muxing a 7-bit (ascii) console also in the lower 7-bits of the byte
//	3. Using the top bit to indicate which channel is being referenced.
//		1'b1 for dbgbus, 1'b0 for the console.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2020, Gisselquist Technology, LLC
//
// This program is free software (firmware): you can redistribute it and/or
// modify it under the terms of  the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or (at
// your option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
// target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
//
// License:	GPL, v3, as defined and found on www.gnu.org,
//		http://www.gnu.org/licenses/gpl.html
//
//
////////////////////////////////////////////////////////////////////////////////
//
//
`default_nettype	none
//
module	hbconsole(i_clk, i_rx_stb, i_rx_byte,
		o_wb_cyc, o_wb_stb, o_wb_we, o_wb_addr, o_wb_data, o_wb_sel,
		i_wb_ack, i_wb_stall, i_wb_err, i_wb_data,
		i_interrupt,
		o_tx_stb, o_tx_data, i_tx_busy,
		i_console_stb, i_console_data, o_console_busy,
		o_console_stb, o_console_data);
	parameter	LGWATCHDOG=19,
			LGINPUT_FIFO=6,
			LGOUTPUT_FIFO=10;
	input	wire		i_clk;
	input	wire		i_rx_stb;
	input	wire	[7:0]	i_rx_byte;
	output	wire		o_wb_cyc, o_wb_stb, o_wb_we;
	output	wire	[29:0]	o_wb_addr;
	output	wire	[31:0]	o_wb_data;
	output	wire	[3:0]	o_wb_sel;
	input	wire		i_wb_ack, i_wb_stall, i_wb_err;
	input	wire	[31:0]	i_wb_data;
	input	wire		i_interrupt;
	output	wire		o_tx_stb;
	output	wire	[7:0]	o_tx_data;
	input	wire		i_tx_busy;
	//
	input	wire		i_console_stb;
	input	wire	[6:0]	i_console_data;
	output	wire		o_console_busy;
	//
	output	reg		o_console_stb;
	output	reg	[6:0]	o_console_data;
	//


	wire		w_reset;
	wire		dec_stb;
	wire	[4:0]	dec_bits;
	wire		iw_stb;
	wire	[33:0]	iw_word;
	// verilator lint_off UNUSED
	wire		wb_busy;
	// verilator lint_on UNUSED
	wire		ow_stb;
	wire	[33:0]	ow_word;
	// verilator lint_off UNUSED
	wire		int_busy;
	// verilator lint_on UNUSED
	wire		idl_busy, int_stb;
	wire	[33:0]	int_word;
	wire		hb_busy, idl_stb;
	wire	[33:0]	idl_word;
	wire		hb_stb, hx_busy;
	wire	[4:0]	hb_bits;
	wire		hx_stb, nl_busy;
	wire	[6:0]	hx_byte;
	wire		fnl_stb;
	wire	[6:0]	fnl_byte;
	reg		ps_full;
	reg	[7:0]	ps_data;

	always @(posedge i_clk)
		o_console_stb <= (i_rx_stb)&&(i_rx_byte[7] == 1'b0);
	always @(posedge i_clk)
		o_console_data <= i_rx_byte[6:0];


	//
	//
	// The incoming stream ...
	//
	//
	// First step, convert the incoming bytes into bits
	hbdechex dechxi(i_clk,
		i_rx_stb, i_rx_byte,
		dec_stb, w_reset, dec_bits);


	// ... that can then be transformed into bus command words
	hbpack	packxi(i_clk, w_reset,
		dec_stb, dec_bits, iw_stb, iw_word);


	//
	// We'll use these bus command words to drive a wishbone bus
	//
	hbexec	wbexec(i_clk, w_reset, iw_stb, iw_word, wb_busy,
			ow_stb, ow_word,
			o_wb_cyc, o_wb_stb, o_wb_we, o_wb_addr, o_wb_data,
				o_wb_sel, i_wb_ack, i_wb_stall, i_wb_err,
				i_wb_data);

	// We'll then take the responses from the bus, and add an interrupt
	// flag to the output any time things are idle.  This also acts
	// as a one-stage FIFO
	hbints	addints(i_clk, w_reset, i_interrupt,
			ow_stb,  ow_word,  int_busy,
			int_stb, int_word, idl_busy);

	// 
	// 
	// 
	hbidle	addidles(i_clk, w_reset,
			int_stb, int_word, idl_busy,
			idl_stb, idl_word, hb_busy);

	// We'll then take that ouput from that stage, and disassemble the
	// response word into smaller (5-bit) sized units ...
	hbdeword unpackx(i_clk, w_reset,
			idl_stb, idl_word, hb_busy,
			hb_stb, hb_bits, hx_busy);

	// ... that can then be transmitted back down the channel
	hbgenhex genhex(i_clk, w_reset, hb_stb, hb_bits, hx_busy,
			hx_stb, hx_byte, nl_busy);

	//
	// We'll also add carriage return newline pairs any time the channel
	// goes idle
	hbnewline addnl(i_clk, w_reset, hx_stb, hx_byte, nl_busy,
			fnl_stb, fnl_byte, (i_tx_busy)&&(ps_full));

	//
	//
	// Let's now arbitrate between the two outputs
	initial	ps_full = 1'b0;
	always @(posedge i_clk)
		if (!ps_full)
		begin
			if (fnl_stb)
			begin
				ps_full <= 1'b1;
				ps_data <= { 1'b1, fnl_byte[6:0] };
			end else if (i_console_stb)
			begin
				ps_full <= 1'b1;
				ps_data <= { 1'b0, i_console_data[6:0] };
			end
		end else if (!i_tx_busy)
		begin
			ps_full <= fnl_stb;
			ps_data <= { 1'b1, fnl_byte[6:0] };
		end

	assign	o_tx_stb = ps_full;
	assign	o_tx_data = ps_data;
	assign	o_console_busy = (fnl_stb)||(ps_full);

`ifdef	FORMAL
	reg	f_past_valid;
	initial	f_past_valid = 1'b0;
	always @(posedge i_clk)
		f_past_valid <= 1'b1;

	always @(*)
	if (int_busy)
		assume(!ow_stb);

	always @(posedge i_clk)
	if ((f_past_valid)&&(!$past(w_reset)))
	begin
		//if (($past(int_stb))&&($past(idl_busy)))
		//	assert(($stable(int_stb))&&($stable(int_word)));

		if (($past(idl_stb))&&($past(hb_busy)))
			assert(($stable(idl_stb))&&($stable(idl_word)));

		if (($past(hb_stb))&&($past(hx_busy)))
			assert(($stable(hb_stb))&&($stable(hb_bits)));

		if (($past(hx_stb))&&($past(nl_busy)))
			assert(($stable(hx_stb))&&($stable(hx_byte)));

		// if (($past(fnl_stb))&&(!$past(w_reset))&&($past(ps_full)))
			// assert(($stable(fnl_stb))&&($stable(fnl_byte)));

		if (($past(i_console_stb))&&($past(o_console_busy)))
			assume(($stable(i_console_stb))
					&&($stable(i_console_data)));

		if (($past(o_tx_stb))&&($past(i_tx_busy)))
			assert(($stable(o_tx_stb))&&($stable(o_tx_data)));
	end

	always @(posedge i_clk)
	if ((f_past_valid)&&(!$past(w_reset))
			&&($past(fnl_stb))&&($past(fnl_byte==7'ha)))
		assert((!fnl_stb)||(fnl_byte != 7'h30));

`endif
endmodule

