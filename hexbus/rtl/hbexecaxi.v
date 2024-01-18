////////////////////////////////////////////////////////////////////////////////
//
// Filename:	hbexecaxi.v
// {{{
// Project:	dbgbus, a collection of 8b channel to WB bus debugging protocols
//
// Purpose:	This core is identical to hbexec, save that it issues a command
//		over an AXI-lite bus rather than a WB bus.
//
//	As with the hbexec, basic bus commands are:
//
//	2'b00	Read
//	2'b01	Write (lower 32-bits are the value to be written)
//	2'b10	Set address
//		Next 30 bits are the address
//		bit[1] is an address difference bit
//		bit[0] is an increment bit
//	2'b11	Special command
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2017-2024, Gisselquist Technology, LLC
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
module	hbexecaxi #(
		// {{{
		parameter	ADDRESS_WIDTH=30,
		parameter [0:0]	OPT_LOWPOWER=1'b0,
		// Shorthand for address width
		localparam	AW=ADDRESS_WIDTH,
				CW=34,	// Command word width
		localparam	DW=32
		// }}}
	) (
		// {{{
		input	wire			i_clk, i_reset,
		// The input command channel
		input	wire			i_cmd_stb,
		input	wire	[(CW-1):0]	i_cmd_word,
		output	wire			o_cmd_busy,
		// The return command channel
		output	reg			o_rsp_stb,
		output	reg	[(CW-1):0]	o_rsp_word,
		// AXI Write Channel
		// {{{
		output	reg			M_AXI_AWVALID,
		input	wire			M_AXI_AWREADY,
		output	reg	[AW+1:0]	M_AXI_AWADDR,
		output	wire	[2:0]		M_AXI_AWPROT,
		//
		output	reg			M_AXI_WVALID,
		input	wire			M_AXI_WREADY,
		output	reg	[DW-1:0]	M_AXI_WDATA,
		output	wire	[3:0]		M_AXI_WSTRB,
		//
		input	wire			M_AXI_BVALID,
		output	reg			M_AXI_BREADY,
		input	wire	[1:0]		M_AXI_BRESP,
		// }}}
		// AXI Read channel
		// {{{
		output	reg			M_AXI_ARVALID,
		input	wire			M_AXI_ARREADY,
		output	wire	[AW+1:0]	M_AXI_ARADDR,
		output	wire	[2:0]		M_AXI_ARPROT,
		//
		input	wire			M_AXI_RVALID,
		output	reg			M_AXI_RREADY,
		input	wire	[DW-1:0]	M_AXI_RDATA,
		input	wire	[1:0]		M_AXI_RRESP
		// }}}
		// }}}
	);

	// Verilator lint_off UNUSED
	localparam [1:0]	CMD_SUB_RD = 2'b00,
				CMD_SUB_WR =	2'b01,
				CMD_SUB_ADDR =	2'b10,
				CMD_SUB_SPECIAL=2'b11;
	// Verilator lint_on  UNUSED
	// localparam [0:0]	CMD_SUB_BUS = 1'b0;
	localparam [1:0]	RSP_SUB_DATA =	2'b00,
				RSP_SUB_ACK =	2'b01,
				RSP_SUB_ADDR =	2'b10,
				RSP_SUB_SPECIAL=2'b11;

	localparam [33:0]	RSP_WRITE_ACKNOWLEDGEMENT
						= { RSP_SUB_ACK, 32'h0 },
				RSP_RESET = { RSP_SUB_SPECIAL, 3'h0, 29'h00 },
				RSP_BUS_ERROR={ RSP_SUB_SPECIAL, 3'h1, 29'h00 };


	//
	//
	reg	[(CW-1):0]	rsp_word;
	reg			newaddr, inc;

	//
	// Decode our input commands
	//
	wire	i_cmd_addr, i_cmd_wr, i_cmd_rd;
	assign	i_cmd_addr = (i_cmd_stb && !o_cmd_busy)&&(i_cmd_word[33:32] == CMD_SUB_ADDR);
	assign	i_cmd_rd   = (i_cmd_stb && !o_cmd_busy)&&(i_cmd_word[33:32] == CMD_SUB_RD);
	assign	i_cmd_wr   = (i_cmd_stb && !o_cmd_busy)&&(i_cmd_word[33:32] == CMD_SUB_WR);

	// AWVALID, WVALID, BREADY
	// {{{
	initial	M_AXI_AWVALID = 0;
	initial	M_AXI_WVALID = 0;
	initial	M_AXI_BREADY = 0;

	always @(posedge i_clk)
	if (i_reset)
	begin
		M_AXI_AWVALID <= 0;
		M_AXI_WVALID  <= 0;
		M_AXI_BREADY <= 0;
		//
	end else if (M_AXI_BREADY)
	begin
		// We are waiting on a return
		if (M_AXI_BVALID)
			M_AXI_BREADY <= 0;

		if (M_AXI_AWREADY)
			M_AXI_AWVALID <= 0;
		if (M_AXI_WREADY)
			M_AXI_WVALID <= 0;
	end else if (i_cmd_wr)
	begin
		M_AXI_AWVALID <= 1;
		M_AXI_WVALID  <= 1;
		M_AXI_BREADY  <= 1;
	end
	// }}}

	// ARVALID, RREADY
	// {{{
	initial	M_AXI_ARVALID = 0;
	initial	M_AXI_RREADY = 0;
	always @(posedge i_clk)
	if (i_reset)
	begin
		M_AXI_ARVALID <= 0;
		M_AXI_RREADY <= 0;
	end else if (M_AXI_RREADY)
	begin
		// We are waiting on a return
		if (M_AXI_ARREADY)
			M_AXI_ARVALID <= 0;

		if (M_AXI_RVALID)
			M_AXI_RREADY <= 0;
	end else if (i_cmd_rd)
	begin
		M_AXI_ARVALID <= 1;
		M_AXI_RREADY  <= 1;
	end
	// }}}

	// M_AXI_AWADDR, newaddr, inc
	// {{{
	initial	M_AXI_AWADDR = 0;
	initial	newaddr = 1;
	always @(posedge i_clk)
	begin
		if (i_cmd_addr)
		begin
			if (!i_cmd_word[1])
				M_AXI_AWADDR <= { i_cmd_word[AW+1:2], 2'b00 };
			else
				M_AXI_AWADDR <= { i_cmd_word[AW+1:2], 2'b00 }
						+ M_AXI_AWADDR;
			inc <= !i_cmd_word[0];

			newaddr <= 1;
		end else begin
			if ((M_AXI_AWVALID && M_AXI_AWREADY)
					||(M_AXI_ARVALID && M_AXI_ARREADY))
				M_AXI_AWADDR[AW+1:2]<= M_AXI_AWADDR[AW+1:2]+(inc ? 1:0);

			if (i_cmd_rd || i_cmd_wr)
				newaddr <= 0;
		end

		M_AXI_AWADDR[1:0] <= 0;

		if (i_reset)
			newaddr <= 1;
	end
	// }}}

	assign	M_AXI_ARADDR = M_AXI_AWADDR;
	assign	M_AXI_AWPROT = 0;
	assign	M_AXI_ARPROT = 0;

	assign	o_cmd_busy = M_AXI_BREADY || M_AXI_RREADY;

	// M_AXI_WDATA
	// {{{
	initial	M_AXI_WDATA = 0;
	always @(posedge i_clk)
	if (OPT_LOWPOWER && i_reset)
		M_AXI_WDATA <= 0;
	else if ((!OPT_LOWPOWER && !M_AXI_BREADY) ||(OPT_LOWPOWER && i_cmd_wr))
		M_AXI_WDATA <= i_cmd_word[31:0];
	else if (OPT_LOWPOWER && M_AXI_WREADY)
		M_AXI_WDATA <= 0;
	// }}}

	assign	M_AXI_WSTRB = -1;

	// rsp_word
	// {{{
	always @(*)
	begin
		rsp_word = 0;

		if (M_AXI_BVALID)
		begin
			if (M_AXI_BRESP[1])
				rsp_word[33:28] = RSP_BUS_ERROR[33:28];
			else
				rsp_word[33:32] = RSP_WRITE_ACKNOWLEDGEMENT[33:32];
		end

		if (M_AXI_RVALID)
		begin
			if (M_AXI_RRESP[1])
				rsp_word[33:28] = rsp_word[33:28]
						| RSP_BUS_ERROR[33:28];
			else
				rsp_word = rsp_word
					| { RSP_SUB_DATA, M_AXI_RDATA };
		end

		if (newaddr)
			rsp_word = rsp_word | { RSP_SUB_ADDR,
					{(32-AW-2){1'b0}},
					M_AXI_AWADDR[AW+1:2], 1'b0, !inc };
	end
	// }}}

	// o_rsp_stb, o_rsp_word
	// {{{
	initial	o_rsp_stb = 1'b1;
	initial	o_rsp_word = RSP_RESET;
	always @(posedge i_clk)
	if (i_reset)
	begin
		o_rsp_stb <= 1'b1;
		o_rsp_word <= RSP_RESET;
	end else begin
		o_rsp_stb  <= 0;
		o_rsp_word <= 0;

		if (M_AXI_BVALID || M_AXI_RVALID)
			o_rsp_stb <= 1;

		if (newaddr && (i_cmd_rd || i_cmd_wr))
			o_rsp_stb <= 1;

		o_rsp_word <= rsp_word;

		if (OPT_LOWPOWER && ((!M_AXI_BVALID && !M_AXI_RVALID)
			&& (!newaddr || (!i_cmd_rd && !i_cmd_wr))))
			o_rsp_word <= 0;
	end
	// }}}

	// Make Verilator happy
	// {{{
	// verilator lint_off UNUSED
	wire	unused;
	assign	unused = &{ 1'b0, i_cmd_rd, M_AXI_BRESP[0], M_AXI_RRESP[0] };
	// verilator lint_on UNUSED
	// }}}
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
//
// Formal properties
// {{{
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
`ifdef	FORMAL
`ifdef	HBEXECAXI
`define	ASSUME	assume
`else
`define	ASSUME	assert
`endif
`define	ASSERT	assert


	////////////////////////////////////////////////////////////////////////
	//
	// Reset properties
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	reg	f_past_valid;
	initial	f_past_valid = 1'b0;
	always @(posedge i_clk)
		f_past_valid <= 1'b1;

	initial	`ASSUME(i_reset);
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Bus property checks
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//
	localparam	F_LGDEPTH=2;
	wire	[F_LGDEPTH-1:0]
			faxil_awr_outstanding, faxil_wr_outstanding,
			faxil_rd_outstanding;

	faxil_master #(
		.C_AXI_ADDR_WIDTH(AW+2),.C_AXI_DATA_WIDTH(32),
		.F_OPT_ASSUME_RESET(1'b1),
		.F_OPT_NO_RESET(1'b1),
		// .F_MAX_STALL(3),
		// .F_MAX_ACK_DELAY(3),
		.F_LGDEPTH(F_LGDEPTH)
	) faxil(
		.i_clk(i_clk), .i_axi_reset_n(!i_reset),
		.i_axi_awvalid(M_AXI_AWVALID), .i_axi_awready(M_AXI_AWREADY),
			.i_axi_awaddr(M_AXI_AWADDR),
			.i_axi_awprot(M_AXI_AWPROT),
		.i_axi_wvalid(M_AXI_WVALID), .i_axi_wready(M_AXI_WREADY),
			.i_axi_wdata(M_AXI_WDATA),
			.i_axi_wstrb(M_AXI_WSTRB),
		.i_axi_bvalid(M_AXI_BVALID), .i_axi_bready(M_AXI_BREADY),
			.i_axi_bresp(M_AXI_BRESP),
		.i_axi_arvalid(M_AXI_ARVALID), .i_axi_arready(M_AXI_ARREADY),
			.i_axi_araddr(M_AXI_ARADDR),
			.i_axi_arprot(M_AXI_ARPROT),
		.i_axi_rvalid(M_AXI_RVALID), .i_axi_rready(M_AXI_RREADY),
			.i_axi_rdata(M_AXI_RDATA),
			.i_axi_rresp(M_AXI_RRESP),
		.f_axi_rd_outstanding(faxil_rd_outstanding),
			.f_axi_wr_outstanding(faxil_wr_outstanding),
			.f_axi_awr_outstanding(faxil_awr_outstanding)
	);

	always @(*)
		assert(!M_AXI_BREADY || !M_AXI_RREADY);

	always @(*)
	if (!M_AXI_BREADY)
	begin
		assert(faxil_awr_outstanding == 0);
		assert(faxil_wr_outstanding  == 0);
		assert(M_AXI_AWVALID == 0);
		assert(M_AXI_WVALID  == 0);
	end else begin
		assert(faxil_awr_outstanding == (M_AXI_AWVALID ? 0:1));
		assert(faxil_wr_outstanding  == (M_AXI_WVALID  ? 0:1));
	end

	always @(*)
	if (!M_AXI_RREADY)
	begin
		assert(faxil_rd_outstanding == 0);
		assert(M_AXI_ARVALID == 0);
	end else
		assert(faxil_rd_outstanding == (M_AXI_ARVALID ? 0:1));

	always @(posedge i_clk)
	if ((!f_past_valid)||($past(i_reset)))
	begin
		`ASSUME(!i_cmd_stb);
		assert(!M_AXI_BREADY);
		assert(!M_AXI_RREADY);
	end

	always @(*)
	if (M_AXI_BVALID)
		assert(M_AXI_BREADY);
	always @(*)
	if (M_AXI_RVALID)
		assert(M_AXI_RREADY);

	always @(*)
		assert(M_AXI_AWADDR[1:0] == 2'b00);
	always @(*)
		assert(M_AXI_ARADDR[1:0] == 2'b00);

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Incoming interface properties
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//
	always @(*)
		assert(o_cmd_busy == (M_AXI_BREADY || M_AXI_RREADY));

	always @(posedge i_clk)
	if (!f_past_valid || $past(i_reset))
	begin
		assume(!i_cmd_stb);
	end else if ($past(i_cmd_stb && o_cmd_busy))
	begin
		assume(i_cmd_stb);
		assume($stable(i_cmd_word));
	end
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Induction properties
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Lowpower check
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	// We have only two values to check: WDATA and o_rsp_word
	generate if (OPT_LOWPOWER)
	begin
		always @(*)
		if (!M_AXI_WVALID)
			assert(M_AXI_WDATA == 0);

		always @(*)
		if (!o_rsp_stb)
			assert(o_rsp_word == 0);
	end endgenerate

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Contract checking
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	// On any new address request, raise the newaddr flag
	// {{{
	always @(posedge i_clk)
	if (!f_past_valid || $past(i_reset))
		assert(newaddr);
	else if ($past(i_cmd_addr))
		assert(newaddr);
	else if ($past(i_cmd_rd || i_cmd_wr))
		assert(!newaddr);
	else
		assert($stable(newaddr));
	// }}}

	// Following any command for a read or write, any pending new address
	// gets flushed to the outgoing stream
	// {{{
	always @(posedge i_clk)
	if ((f_past_valid)&&(!$past(i_reset))&&($past(i_cmd_rd || i_cmd_wr)))
	begin
		`ASSERT(o_rsp_stb  == $past(newaddr));
		if ($past(newaddr))
			`ASSERT(o_rsp_word == { RSP_SUB_ADDR, {(30-AW){1'b0}},
				$past(M_AXI_AWADDR[AW+1:1]), !$past(inc) });
	end
	// }}}

	// The new address flag must be low while any request is pending
	// {{{
	always @(*)
	if (!i_reset && (M_AXI_BREADY || M_AXI_RREADY))
		assert(!newaddr);
	// }}}

	// A reset return follows immediately following any reset
	// {{{
	always @(posedge i_clk)
	if ((f_past_valid)&&($past(i_reset)))
		`ASSERT((o_rsp_stb)&&(o_rsp_word == RSP_RESET));
	// }}}

	// Wirte responses follow any valid write return
	// {{{
	always @(posedge i_clk)
	if (f_past_valid && !$past(i_reset)
			&& $past(M_AXI_BVALID && !M_AXI_BRESP[1]))
	begin
		assert(o_rsp_stb);
		assert(o_rsp_word == RSP_WRITE_ACKNOWLEDGEMENT);
	end
	// }}}

	// Read value responses follow any returned read value
	// {{{
	always @(posedge i_clk)
	if (f_past_valid && !$past(i_reset)
			&& $past(M_AXI_RVALID && !M_AXI_RRESP[1]))
	begin
		assert(o_rsp_stb);
		assert(o_rsp_word == { RSP_SUB_DATA, $past(M_AXI_RDATA) });
	end
	// }}}

	// Bus error responses follow any form of bus error
	// {{{
	always @(posedge i_clk)
	if (f_past_valid && (!$past(i_reset))
		&&(($past(M_AXI_BVALID && M_AXI_BRESP[1]))
			||($past(M_AXI_RVALID && M_AXI_RRESP[1]))))
	begin
		assert(o_rsp_stb);
		assert(o_rsp_word == RSP_BUS_ERROR);
	end
	// }}}

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Cover checks
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//
	reg	[3:0]	cvr_reads, cvr_writes;

	initial	cvr_writes = 0;
	always @(posedge i_clk)
	if (i_reset || M_AXI_RREADY)
		cvr_writes <= 0;
	else if (M_AXI_BVALID)
		cvr_writes <= cvr_writes + 1;

	always @(posedge i_clk)
		cover(cvr_writes == 1 && faxil_awr_outstanding == 0
			&& faxil_wr_outstanding == 0);

	always @(posedge i_clk)
		cover(cvr_writes == 4 && faxil_awr_outstanding == 0
			&& faxil_wr_outstanding == 0);

	initial	cvr_reads = 0;
	always @(posedge i_clk)
	if (i_reset || M_AXI_BREADY)
		cvr_reads <= 0;
	else if (M_AXI_RVALID)
		cvr_reads <= cvr_reads + 1;

	always @(posedge i_clk)
		cover(cvr_reads == 1 && M_AXI_RVALID);

	always @(posedge i_clk)
		cover(o_rsp_stb && $past(cvr_reads == 1));

	always @(posedge i_clk)
		cover(o_rsp_stb && $past(M_AXI_RVALID));

	always @(posedge i_clk)
		cover(cvr_reads == 2);

	always @(posedge i_clk)
		cover(cvr_reads == 2 && M_AXI_RVALID);

	always @(posedge i_clk)
		cover(cvr_reads == 3 && M_AXI_RVALID);

	always @(posedge i_clk)
		cover(cvr_reads == 1 && faxil_rd_outstanding == 0);

	always @(posedge i_clk)
		cover(cvr_reads == 4 && faxil_rd_outstanding == 0);
	// }}}
`endif
// }}}
endmodule
