////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	hbaxil.v
//
// Project:	dbgbus, a collection of 8b channel to WB bus debugging protocols
//
// Purpose:	This is the top level of the debug bus itself, converting
//		8-bit input words to bus requests and bus returns to outgoing
//	8-bit words.
//
//	This particular version is modified from hbbus so that it can drive an
//	AXI-Lite bus.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2017-2020, Gisselquist Technology, LLC
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
module	hbaxil(S_AXI_ACLK,
		i_rx_stb, i_rx_byte,
		M_AXI_AWVALID, M_AXI_AWREADY, M_AXI_AWADDR, M_AXI_AWPROT,
		//
		M_AXI_WVALID, M_AXI_WREADY, M_AXI_WDATA, M_AXI_WSTRB,
		//
		M_AXI_BVALID, M_AXI_BREADY, M_AXI_BRESP,
		//
		M_AXI_ARVALID, M_AXI_ARREADY, M_AXI_ARADDR, M_AXI_ARPROT,
		//
		M_AXI_RVALID, M_AXI_RREADY, M_AXI_RDATA, M_AXI_RRESP,
		//
		i_interrupt,
		o_tx_stb, o_tx_byte, i_tx_busy);
	parameter	C_AXI_ADDR_WIDTH=32;
	localparam	DW=32, AW = C_AXI_ADDR_WIDTH-2;
	input	wire			S_AXI_ACLK;
	input	wire			i_rx_stb;
	input	wire	[7:0]		i_rx_byte;
	//
	output	wire			M_AXI_AWVALID;
	input	wire			M_AXI_AWREADY;
	output	wire	[AW+1:0]	M_AXI_AWADDR;
	output	wire	[2:0]		M_AXI_AWPROT;
	//
	output	wire			M_AXI_WVALID;
	input	wire			M_AXI_WREADY;
	output	wire	[DW-1:0]	M_AXI_WDATA;
	output	wire	[3:0]		M_AXI_WSTRB;
	//
	input	wire			M_AXI_BVALID;
	output	wire			M_AXI_BREADY;
	input	wire	[1:0]		M_AXI_BRESP;
	//
	output	wire			M_AXI_ARVALID;
	input	wire			M_AXI_ARREADY;
	output	wire	[AW+1:0]	M_AXI_ARADDR;
	output	wire	[2:0]		M_AXI_ARPROT;
	//
	input	wire			M_AXI_RVALID;
	output	wire			M_AXI_RREADY;
	input	wire	[DW-1:0]	M_AXI_RDATA;
	input	wire	[1:0]		M_AXI_RRESP;
	//
	input	wire			i_interrupt;
	output	wire			o_tx_stb;
	output	wire	[7:0]		o_tx_byte;
	input	wire			i_tx_busy;


	wire		i_clk;
	assign		i_clk = S_AXI_ACLK;

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
	hbexecaxi	#(AW)
	axilexec(i_clk, w_reset,
			iw_stb, iw_word, wb_busy,
			ow_stb, ow_word,
			//
			M_AXI_AWVALID, M_AXI_AWREADY, M_AXI_AWADDR,
				M_AXI_AWPROT,
			//
			M_AXI_WVALID, M_AXI_WREADY, M_AXI_WDATA,
				M_AXI_WSTRB,
			//
			M_AXI_BVALID, M_AXI_BREADY, M_AXI_BRESP,
			//
			M_AXI_ARVALID, M_AXI_ARREADY, M_AXI_ARADDR,
				M_AXI_ARPROT,
			//
			M_AXI_RVALID, M_AXI_RREADY, M_AXI_RDATA, M_AXI_RRESP
	);

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
			o_tx_stb, o_tx_byte[6:0], i_tx_busy);
	assign	o_tx_byte[7] = 1'b0;

endmodule
