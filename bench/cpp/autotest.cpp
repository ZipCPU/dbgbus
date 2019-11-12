////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	autotest.cpp
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
#include <stdio.h>
#include <assert.h>
#include <signal.h>
#include <poll.h>
#include <sched.h>
#include "verilated.h"
#include "verilated_vcd_c.h"
#include "Vtestbus.h"
#include "testb.h"
#include "uartsim.h"

#define	UARTSETUP	25
#include "port.h"

#define	TIMEOUT		250
//
// Wrap the bus in a test bench
//
class	TESTBUS_TB : public TESTB<Vtestbus> {
public:
	unsigned long	m_tx_busy_count;
	UARTSIM		m_uart;
	bool		m_done;
	int		m_ticks;

	TESTBUS_TB(const int tcp_port=0) : m_uart(tcp_port) {
		m_done = false;
		m_ticks = 0;
	}

	void	trace(const char *vcd_trace_file_name) {
		fprintf(stderr, "Opening TRACE(%s)\n", vcd_trace_file_name);
		opentrace(vcd_trace_file_name);
	}

	void	close(void) {
		TESTB<Vtestbus>::closetrace();
	}

	void	tick(void) {
		m_ticks++;
		if (m_done)
			return;

		if (m_ticks < 25*20)
			m_core->i_uart = 1;
		else
			m_core->i_uart = m_uart(m_core->o_uart,
				UARTSETUP);

		TESTB<Vtestbus>::tick();
	}

	bool	done(void) {
		if (m_done)
			return true;
		else {
			if (Verilated::gotFinish())
				m_done = true;
			else if (m_core->o_halt)
				m_done = true;
			return m_done;
		}
	}
};

void	getresponse(int fdin, int fdout, const char *cmd, char *response) {
	char	*rptr = response;
	const char	*ptr, *sptr;
	int	posn, nr;

	sptr = cmd;
	while(NULL != (ptr = strchr(sptr, '\n'))) {
		// Make our request
		putc('<', stdout);
		putc(' ', stdout);
		for(; *sptr && sptr<ptr; sptr++) {
			assert(1 == write(fdin, sptr, 1));
			putc(*sptr, stdout);
		} if (*sptr && *sptr == '\n') {
			assert(1 == write(fdin, sptr, 1));
			putc(*sptr, stdout);
			sptr++;
		} fflush(stdout);

		sched_yield();
		posn = 0;
		while((nr = read(fdout, &rptr[posn], 1))>0) {
			if (rptr[posn] == '\r')
				continue;
			if ((posn > 0)&&(rptr[posn] == '\n')&&(rptr[posn-1]=='\n'))
				continue;
			posn += nr;

			if (rptr[posn-1] == '\n') {
				// Check for more ...
				struct	pollfd	fds;

				fds.fd = fdout;
				fds.events = POLLIN;
				if (poll(&fds, 1, TIMEOUT) <= 0)
					break;
			}
		}
		if (nr < 0) {
			perror("O/S ERR");
			exit(EXIT_FAILURE);
		}

		rptr[posn] = '\0';
		while(*rptr && isspace(*rptr))
			rptr++, posn--;
		printf("> %s", rptr);
		rptr += posn;
		while(*sptr && (isspace(*sptr)))
			sptr++;
		if ('\0' == *sptr)
			break;
	}
}

int	test1_read(int fdin, int fdout) {
	const char CHECKSTR[] = "A00002040R20170622\n";
	char	response[512], *rptr;

	getresponse(fdin, fdout, "A2040R\n",
		response);

	rptr = response;
	while(*rptr && isspace(*rptr))
		rptr++;

	if (0 != strcmp(rptr, CHECKSTR)) {
		printf("CHECK1: -- FAILS\n");
		printf("RCV: %s", rptr);
		printf("PAT: %s", CHECKSTR);
		return 1;
	}
	return 0;
}

int	test2_multiread(int fdin, int fdout) {
	// Pattern isn't stable enough to check
	// const char CHECKSTR[] = "A0000204dR0000d0c9\nR00019197\nR000249fc\nR000302e7\n";
	char	response[512];

	getresponse(fdin, fdout, "A204dR\nR\nR\nR\n",
		response);
	return 0;
}

int	test3_interrupts(int fdin, int fdout) {
	const char CHECKSTR[] = "A00002051R00000000K00000000I\nK00000000\nK00000000I\nK00000000\n";
	char	response[512], *rptr;

	getresponse(fdin, fdout, "A2051RW1\nW0\nW1\nW0\n",
		response);

	rptr = response;
	while(*rptr && isspace(*rptr))
		rptr++;

	if (0 != strcmp(rptr, CHECKSTR)) {
		printf("CHECK3: -- FAILS\n");
		printf("RCV: %s", rptr);
		printf("PAT: %s", CHECKSTR);
		return 1;
	}

	return 0;
}

int	test4_scope_trigger(int fdin, int fdout) {
	const char CHECKSTR[] = "A00002080R12a001fc\nA00004000\nK00000000\nA00002080IR72a001fc\nA00004000Rdeadbeef\n";
	char	response[512], *rptr;

	getresponse(fdin, fdout, "A2080R\nA4000Wdeadbeef\nA2080R\nA4000R\n",
		response);

	rptr = response;
	while(*rptr && isspace(*rptr))
		rptr++;

	if (0 != strcmp(rptr, CHECKSTR)) {
		printf("CHECK4: -- FAILS\n");
		printf("RCV: %s", rptr);
		printf("PAT: %s", CHECKSTR);

		return 1;
	}

	return 0;
}

int	test5_scope_data(int fdin, int fdout) {
	const char CHECKSTR[] = "A00002080R72a001fc\n"
			"A00004000\nK00000000\n"
			"A00002080R72a001fc\n"
			"A00002085R001b6c00\n"
			"R001b6c00\n"
			"R001b6c00\n"
			"R001b6c00\n"
			"R001b6c00\n"
			"R001b6c00\n";
	char	response[512], *rptr;

	getresponse(fdin, fdout, "A02080R\nA4000Wdeadbeef\nA2080R\nA2085R\nR\nR\nR\nR\nR\n",
		response);

	rptr = response;
	while(*rptr && isspace(*rptr))
		rptr++;

	if (0 != strcmp(rptr, CHECKSTR)) {
		printf("CHECK5: -- FAILS\n");
		printf("RCV: %s", rptr);
		printf("PAT: %s", CHECKSTR);

		return 1;
	}

	return 0;
}

int	main(int argc, char **argv) {
	int	childs_stdin[2], childs_stdout[2];

	if ((pipe(childs_stdin)!=0)||(pipe(childs_stdout) != 0)) {
		fprintf(stderr, "ERR setting up child pipes\n");
		perror("O/S ERR");
		printf("TEST FAILURE\n");
		exit(EXIT_FAILURE);
	}

	pid_t childs_pid = fork();

	if (childs_pid < 0) {
		fprintf(stderr, "ERR settingng up child pprocess\n");
		perror("O/S ERR");
		printf("TEST FAILURE\n");
		exit(EXIT_FAILURE);
	}

	if (childs_pid) {
		int	err, fdin, fdout;

		// We are the parent process, which will query the TB
		close(childs_stdin[0]);
		close(childs_stdout[1]);

		fdin = childs_stdin[1];
		fdout = childs_stdout[0];

		err = test1_read(fdin, fdout);
		if (0 == err)
			err = test2_multiread(fdin, fdout);
		if (0 == err)
			err = test3_interrupts(fdin, fdout);
		if (0 == err)
			err = test4_scope_trigger(fdin, fdout);
		if (0 == err)
			err = test5_scope_data(fdin, fdout);

		kill(childs_pid, 15);
		if (err != 0) {
			printf("ERR %d\nTEST_FAILURE!\n", err);
			exit(EXIT_FAILURE);
		} else {
			printf("SUCCESS!\n");
			exit(EXIT_SUCCESS);
		}
	} else {

		// Child process that will run the test bench itself
		close(childs_stdin[1]);
		close(childs_stdout[0]);
		close(STDIN_FILENO);
		if (dup(childs_stdin[0]) < 0) {
			fprintf(stderr, "ERR setting up child FD\n");
			perror("O/S ERR");
			exit(EXIT_FAILURE);
		}
		close(STDOUT_FILENO);
		if (dup(childs_stdout[1]) < 0) {
			fprintf(stderr, "ERR setting up child FD\n");
			perror("O/S ERR");
			exit(EXIT_FAILURE);
		}

		TESTBUS_TB	*tb = new TESTBUS_TB();
#define	VCDTRACE
#ifdef	VCDTRACE
		tb->trace("autotest.vcd");
#endif
		while(!tb->done())
			tb->tick();
	}
}
