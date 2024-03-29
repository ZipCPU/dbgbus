////////////////////////////////////////////////////////////////////////////////
//
// Filename:	llcomms.h
// {{{
// Project:	dbgbus, a collection of 8b channel to WB bus debugging protocols
//
// Purpose:	This is the C++ program on the command side that will interact
//		with a UART on an FPGA, both sending and receiving characters.
//	Any bus interaction will call routines from this lower level library to
//	accomplish the actual connection to and transmission to/from the board.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2017-2024, Gisselquist Technology, LLC
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
#ifndef	LLCOMMS_H
#define	LLCOMMS_H

class	LLCOMMSI {
protected:
	int	m_fdw, m_fdr;
	LLCOMMSI(void);
public:
	unsigned long	m_total_nread, m_total_nwrit;

	virtual	~LLCOMMSI(void) { close(); }
	virtual	void	kill(void)  { this->close(); };
	virtual	void	close(void);
	virtual	void	write(char *buf, int len);
	virtual int	read(char *buf, int len);
	virtual	bool	poll(unsigned ms);

	// Tests whether or not bytes are available to be read, returns a 
	// count of the bytes that may be immediately read
	virtual	int	available(void); // { return 0; };
};

class	TTYCOMMS : public LLCOMMSI {
public:
	TTYCOMMS(const char *dev);
};

class	NETCOMMS : public LLCOMMSI {
public:
	NETCOMMS(const char *dev, const int port);
	virtual	void	close(void);
};

#endif
