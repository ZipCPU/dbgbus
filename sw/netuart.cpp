////////////////////////////////////////////////////////////////////////////////
//
// Filename:	netuart.cpp
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
// Copyright (C) 2015-2023, Gisselquist Technology, LLC
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

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <termios.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <string.h>
#include <poll.h>
#include <signal.h>
#include <ctype.h>
#include <assert.h>
#include <errno.h>

#include "port.h"
#include "regdefs.h"

void	sigstop(int v) {
	fprintf(stderr, "SIGSTOP!!\n");
	exit(0);
}
void	sighup(int v) {
	fprintf(stderr, "SIGHUP!!\n");
	exit(0);
}
void	sigint(int v) {
	fprintf(stderr, "SIGINT!!\n");
	exit(0);
}
void	sigsegv(int v) {
	fprintf(stderr, "SIGSEGV!!\n");
	exit(0);
}
void	sigbus(int v) {
	fprintf(stderr, "SIGBUS!!\n");
	exit(0);
}
void	sigpipe(int v) {
	fprintf(stderr, "SIGPIPE!!\n");
	exit(0);
}

int	setup_listener(const int port) {
	int	skt;
	struct  sockaddr_in     my_addr;

	printf("Listening on port %d\n", port);

	skt = socket(AF_INET, SOCK_STREAM, 0);
	if (skt < 0) {
		perror("Could not allocate socket: ");
		exit(-1);
	}

	// Set the reuse address option
	{
		int optv = 1, er;
		er = setsockopt(skt, SOL_SOCKET, SO_REUSEADDR, &optv, sizeof(optv));
		if (er != 0) {
			perror("SockOpt Err:");
			exit(-1);
		}
	}

	memset(&my_addr, 0, sizeof(struct sockaddr_in)); // clear structure
	my_addr.sin_family = AF_INET;
	my_addr.sin_addr.s_addr = htonl(INADDR_ANY);
	my_addr.sin_port = htons(port);

	if (bind(skt, (struct sockaddr *)&my_addr, sizeof(my_addr))!=0) {
		perror("BIND FAILED:");
		exit(-1);
	}

	if (listen(skt, 1) != 0) {
		perror("Listen failed:");
		exit(-1);
	}

	return skt;
}

class	LINBUFS {
public:
	char	m_iline[512], m_oline[512];
	char	m_buf[256];
	int	m_ilen, m_olen;
	bool	m_connected;

	LINBUFS(void) {
		m_ilen = 0; m_olen = 0; m_connected = false;
	}
};

bool	check_incoming(LINBUFS &lb, int ttyfd, int confd, int timeout) {
	struct	pollfd	p[2];
	int	pv, nfds;

	p[0].fd = ttyfd;
	p[0].events = POLLIN | POLLERR;
	if (confd >= 0) {
		p[1].fd = confd;
		p[1].events = POLLIN | POLLRDHUP | POLLERR;
		nfds = 2;
	} else nfds = 1;

	if ((pv=poll(p, nfds, timeout)) < 0) {
		perror("Poll Failed!  O/S Err:");
		exit(-1);
	}
	if (p[0].revents & POLLIN) {
		int nr = read(ttyfd, lb.m_buf, 256);
		if (nr > 0) {
			// printf("%d read from TTY\n", nr);
			if (confd >= 0) {
				int	nw;
				nw = write(confd, lb.m_buf, nr);
				if(nw != nr) {
					// This fails when the other end resets
					// the connection.  Thus, we'll just
					// kindly close the connection and skip
					// the assert that once was at the end.
					fprintf(stderr, "ERR: Could not write return string to buffer\n");
					perror("O/S Err:");
					close(confd);
					confd = -1;
					lb.m_connected = false;
					nfds = 1;
					// assert(nw == nr);
				}
			}
		} else if (nr < 0) {
			fprintf(stderr, "ERR: Could not read from TTY\n");
			perror("O/S Err:");
			exit(EXIT_FAILURE);
		} else if (nr == 0) {
			fprintf(stderr, "TTY device has closed\n");
			exit(EXIT_SUCCESS);
		} for(int i=0; i<nr; i++) {
			lb.m_iline[lb.m_ilen++] = lb.m_buf[i];
			if ((lb.m_iline[lb.m_ilen-1]=='\n')
					||(lb.m_iline[lb.m_ilen-1]=='\r')
					||((unsigned)lb.m_ilen
						>= sizeof(lb.m_iline)-1)) {
				if ((unsigned)lb.m_ilen >= sizeof(lb.m_iline)-1)
					lb.m_iline[lb.m_ilen] = '\0';
				else
					lb.m_iline[lb.m_ilen-1] = '\0';
				if (lb.m_ilen > 1)
					printf("%c %s\n",
						(confd>=0)?'>':'#', lb.m_iline);
				lb.m_ilen = 0;
			}
		}
	} else if (p[0].revents) {
		fprintf(stderr, "ERR: UNKNOWN TTY EVENT: %d\n", p[0].revents);
		perror("O/S Err?");
		exit(EXIT_FAILURE);
	}
		

	if((nfds>1)&&(p[1].revents & POLLIN)) {
		int nr = read(confd, lb.m_buf, 256);
		if (nr == 0) {
			lb.m_connected = false;
			if (lb.m_olen > 0) {
				lb.m_oline[lb.m_olen] = '\0';
				printf("< %s\n", lb.m_oline);
			} lb.m_olen = 0;
			// printf("Disconnect\n");
			close(confd);
		} else if (nr > 0) {
			// printf("%d read from SKT\n", nr);
			int nw = 0, ttlw=0;

			errno = 0;
			do {
				nw = write(ttyfd, &lb.m_buf[ttlw], nr-ttlw);

				if ((nw < 0)&&(errno == EAGAIN)) {
					nw = 0;
					usleep(10);
				} else if (nw < 0) {
					fprintf(stderr, "ERR: %4d\n", errno);
					perror("O/S Err: ");
					assert(nw > 0);
					break;
				} else if (nw == 0) {
					// TTY device has closed our connection
					fprintf(stderr, "TTY device has closed\n");
					exit(EXIT_SUCCESS);
					break;
				}
				// if (nw != nr-ttlw)
					// printf("Only wrote %d\n", nw);
				ttlw += nw;
			} while(ttlw < nr);
		} for(int i=0; i<nr; i++) {
			lb.m_oline[lb.m_olen++] = lb.m_buf[i];
			assert(lb.m_buf[i] != '\0');
			if ((lb.m_oline[lb.m_olen-1]=='\n')
					||(lb.m_oline[lb.m_olen-1]=='\r')
					||((unsigned)lb.m_olen
						>= sizeof(lb.m_oline)-1)) {
				if ((unsigned)lb.m_olen >= sizeof(lb.m_oline)-1)
					lb.m_oline[lb.m_olen] = '\0';
				else
					lb.m_oline[lb.m_olen-1] = '\0';
				if (lb.m_olen > 1)
					printf("< %s\n", lb.m_oline);
				lb.m_olen = 0;
			}
		}
	} else if ((nfds>1)&&(p[1].revents)) {
		fprintf(stderr, "UNKNOWN SKT EVENT: %d\n", p[1].revents);
		perror("O/S Err?");
		exit(EXIT_FAILURE);
	}

	return (pv > 0);
}

int	myaccept(int skt, int timeout) {
	int	con = -1;
	struct	pollfd	p[1];
	int	pv;

	p[0].fd = skt;
	p[0].events = POLLIN | POLLERR;
	if ((pv=poll(p, 1, timeout)) < 0) {
		perror("Poll Failed!  O/S Err:");
		exit(-1);
	} if (p[0].revents & POLLIN) {
		con = accept(skt, 0, 0);
		if (con < 0) {
			perror("Accept failed!  O/S Err:");
			exit(-1);
		}
	} return con;
}

int	main(int argc, char **argv) {
	// First, accept a network connection
	int	skt = setup_listener(FPGAPORT);
	int	tty;
	bool	done = false;

	signal(SIGSTOP, sigstop);
	signal(SIGBUS, sigbus);
	signal(SIGSEGV, sigsegv);
	signal(SIGPIPE, SIG_IGN);
	signal(SIGINT, sigint);
	signal(SIGHUP, sighup);

	if ((argc > 1)&&(NULL != strstr(argv[1], "/ttyUSB"))) {
		// printf("Opening %s\n", argv[1]);
		tty = open(argv[1], O_RDWR | O_NONBLOCK);
		if (tty < 0) {
		printf("Could not open tty\n");
			fprintf(stderr, "Could not open tty device, %s\n", argv[1]);
			perror("O/S Err:");
			exit(-1);
		}
	} else if (argc == 1) {
		const	char *deftty = "/dev/ttyUSB2";
		// printf("Opening %s\n", deftty);
		tty = open(deftty, O_RDWR | O_NONBLOCK);
		if (tty < 0) {
			fprintf(stderr, "Attempted to guess the TTY, but could not open %s\n", deftty);
			perror("O/S Err:");
			exit(-1);
		}
	} else {
		printf("Unknown argument: %s\n", argv[1]);
		exit(-2);
	}

	if (tty < 0) {
		printf("Could not open tty\n");
		perror("O/S Err:");
		exit(-1);
	} else if (isatty(tty)) {
		struct	termios	tb;

		printf("Setting up TTY for %d Baud\n", BAUDRATE);
		if (tcgetattr(tty, &tb) < 0) {
			printf("Could not get TTY attributes\n");
			perror("O/S Err:");
			exit(-2);
		}

		cfmakeraw(&tb); // Sets no parity, 8 bits, one stop bit
		tb.c_cflag &= (~(CRTSCTS)); // Sets no parity, 8 bit
		tb.c_cflag &= (~(CSTOPB)); // One stop bit

		// 8-bit
		tb.c_cflag &= ~(CSIZE);
		tb.c_cflag |= CS8;
		if (BAUDRATE == 2400) {
			// 2400 Baud
			cfsetispeed(&tb, B2400);
			cfsetospeed(&tb, B2400);
		} else if (BAUDRATE == 9600) {
			// 9.6 kBaud
			cfsetispeed(&tb, B9600);
			cfsetospeed(&tb, B9600);
		} else if (BAUDRATE == 19200) {
			// 19.2 kBaud
			cfsetispeed(&tb, B19200);
			cfsetospeed(&tb, B19200);
		} else if (BAUDRATE == 38400) {
			// 38.4 kBaud
			cfsetispeed(&tb, B38400);
			cfsetospeed(&tb, B38400);
		} else if (BAUDRATE == 57600) {
			// 57.6 kBaud
			cfsetispeed(&tb, B57600);
			cfsetospeed(&tb, B57600);
		} else if (BAUDRATE == 115200) {
			// 115.2kBaud
			cfsetispeed(&tb, B115200);
			cfsetospeed(&tb, B115200);
		} else if (BAUDRATE == 1000000) {
			// 1 MBaud
			cfsetispeed(&tb, B1000000);
			cfsetospeed(&tb, B1000000);
		} else if (BAUDRATE == 2000000) {
			// 2 MBaud
			cfsetispeed(&tb, B2000000);
			cfsetospeed(&tb, B2000000);
		} else if (BAUDRATE == 2500000) {
			// 2.5 MBaud
			cfsetispeed(&tb, B2500000);
			cfsetospeed(&tb, B2500000);
		} else if (BAUDRATE == 3000000) {
			// 2 MBaud
			cfsetispeed(&tb, B3000000);
			cfsetospeed(&tb, B3000000);
		} else if (BAUDRATE == 3000000) {
			// 3.5 MBaud
			cfsetispeed(&tb, B3500000);
			cfsetospeed(&tb, B3500000);
		} else if (BAUDRATE == 4000000) {
			// 4 MBaud
			cfsetispeed(&tb, B4000000);
			cfsetospeed(&tb, B4000000);
		} else {
			fprintf(stderr, "Unsupported baud rate: %d Hz\n", BAUDRATE);
			exit(EXIT_FAILURE);
		}

		if (tcsetattr(tty, TCSANOW, &tb) < 0) {
			printf("Could not set any TTY attributes\n");
			perror("O/S Err:");
		}
		tcflow(tty, TCOON);
	}

	LINBUFS	lb;
	while(!done) {
		int	con;

		// Accept a connection before going on
		// Let's call poll(), so we can still read any
		// tty messages even when not accepted
		con = myaccept(skt, 50);
		if (con >= 0) {
			lb.m_connected = true;

			/*
			// Set our new socket as non-blocking
			int flags = fcntl(fd, F_GETFL, 0);
			flags |= O_NONBLOCK;
			fcntl(fd, F_SETFL, flags);
			*/

			// printf("Received a new connection\n");
		}

		// Flush any buffer within the TTY
		while(check_incoming(lb, tty, -1, 0))
			;

		// Now, process that connection until it's gone
		while(lb.m_connected)
			check_incoming(lb, tty, con, -1);
	}

	printf("Closing our socket\n");
	close(skt);
}

