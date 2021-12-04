////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	memscope.cpp
// {{{
// Project:	dbgbus, a collection of 8b channel to WB bus debugging protocols
//
// Purpose:	
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2017-2021, Gisselquist Technology, LLC
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
// }}}
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <strings.h>
#include <ctype.h>
#include <string.h>
#include <signal.h>
#include <assert.h>

#include "port.h"
#include "regdefs.h"
#include "scopecls.h"
#include "hexbus.h"

#define	WBSCOPE		R_SCOPE
#define	WBSCOPEDATA	R_SCOPD

FPGA	*m_fpga;

class	MEMSCOPE : public SCOPE {
public:
	MEMSCOPE(FPGA *fpga, unsigned addr) : SCOPE(fpga, addr) {};
	~MEMSCOPE(void) {}

	virtual	void	define_traces(void) {
		//
		register_trace("wb_cyc",    1, 31);
		register_trace("wb_stb",    1, 30);
		register_trace("wb_we",     1, 29);
		register_trace("wb_ack",    1, 28);
		register_trace("wb_stall",  1, 27);
		register_trace("wb_addr",   6, 21);
		register_trace("wb_odata", 10, 10);
		register_trace("wb_idata", 10,  0);
	}

	virtual	void	decode(DEVBUS::BUSW val) const {
		int	cyc, stb, we, ack, stall, addr, odata, idata;

		cyc   = (val >> 31)&1;
		stb   = (val >> 30)&1;
		we    = (val >> 29)&1;
		ack   = (val >> 28)&1;
		stall = (val >> 27)&1;
		addr  = (val >> 21)&0x3f;
		odata = (val >> 10)&0x3ff;
		idata = (val      )&0x3ff;

		printf("%s", (cyc)?"CYC":"   ");
		printf(" %s", (stb)?"STB":"   ");
		printf(" %s", (we) ?"W" :"R");
		printf("[@....%02x]...%03x->...%03x", addr, odata, idata);
		printf(" %s", (ack)?"ACK":"   ");
		printf(" %s", (stall)?"(STALL)":"       ");
	}
};

int main(int argc, char **argv) {
	// Open and connect to our FPGA.  This macro needs to be defined in the
	// include files above.
	FPGAOPEN(m_fpga);

	// Here, we open a scope.  An MEMSCOPE specifically.  The difference
	// between an MEMSCOPE and any other scope is ... that the
	// MEMSCOPE has particular things wired to particular bits, whereas
	// a generic scope ... just has data.
	MEMSCOPE *scope = new MEMSCOPE(m_fpga, WBSCOPE);

	if (!scope->ready()) {
		// If we get here, then ... nothing started the scope.
		// It either hasn't primed, hasn't triggered, or hasn't finished
		// recording yet.  Trying to read data would do nothing but
		// read garbage, so we don't try.
		printf("Scope is not yet ready:\n");
		scope->decode_control();
	} else {
		// The scope has been primed, triggered, the holdoff wait 
		// period has passed, and the scope has now stopped.
		//
		// Hence we can read from our scope the values we need.
		scope->print();
		// If we want, we can also write out a VCD file with the data
		// we just read.
		scope->writevcd("scopd.vcd");
	}

	// Now, we're all done.  Let's be nice to our interface and shut it
	// down gracefully, rather than letting the O/S do it in ... whatever
	// manner it chooses.
	delete	m_fpga;
}
