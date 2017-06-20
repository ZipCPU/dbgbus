////////////////////////////////////////////////////////////////////////////////
//
// Filename:	testbus_tb.cpp
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
//
// License:	LGPL, v3, as defined and found on www.gnu.org,
//		http://www.gnu.org/licenses/lgpl.html
//
//
////////////////////////////////////////////////////////////////////////////////
//
//
#include <signal.h>
#include <time.h>
#include <ctype.h>
#include <string.h>
#include <stdint.h>

#include "verilated.h"
#include "verilated_vcd_c.h"
#include "Vtestbus.h"

#include "testb.h"
#include "uartsim.h"

#define	UARTSETUP	25
// #include "port.h"

class	TESTBUS_TB : public TESTB<Vtestbus> {
public:
	unsigned long	m_tx_busy_count;
	UARTSIM		m_uart;
	bool		m_done;

	TESTBUS_TB(void) : m_uart(0) {
		m_done = false;
	}

	void	reset(void) {
		m_core->i_clk = 1;
		m_core->eval();
	}

	void	trace(const char *vcd_trace_file_name) {
		fprintf(stderr, "Opening TRACE(%s)\n", vcd_trace_file_name);
		opentrace(vcd_trace_file_name);
	}

	void	close(void) {
		TESTB<Vtestbus>::closetrace();
	}

	void	tick(void) {
		if (m_done)
			return;

		m_core->i_uart = m_uart(m_core->o_uart,
				UARTSETUP);

		TESTB<Vtestbus>::tick();
	}

	bool	done(void) {
		if (!m_done)
			return (m_done = (m_core->o_halt?1:0));
		else
			return true;
	}
};

TESTBUS_TB	*tb;

int	main(int argc, char **argv) {
	Verilated::commandArgs(argc, argv);
	tb = new TESTBUS_TB;

	tb->opentrace("trace.vcd");
	// tb->reset();

	while(!tb->done())
		tb->tick();

	tb->close();
	exit(0);
}

