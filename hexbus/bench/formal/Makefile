################################################################################
##
## Filename:	Makefile
## {{{
## Project:	dbgbus, a collection of 8b channel to WB bus debugging protocols
##
## Purpose:	A formal bench-test makefile.  Directs formal proofs only.
##		"make" or "make all" will therefore run all proofs in this
##	directory to completion or failure.
##
## Creator:	Dan Gisselquist, Ph.D.
##		Gisselquist Technology, LLC
##
################################################################################
## }}}
## Copyright (C) 2015-2021, Gisselquist Technology, LLC
## {{{
## This file is part of the debugging interface demonstration.
##
## The debugging interface demonstration is free software (firmware): you can
## redistribute it and/or modify it under the terms of the GNU Lesser General
## Public License as published by the Free Software Foundation, either version
## 3 of the License, or (at your option) any later version.
##
## This debugging interface demonstration is distributed in the hope that it
## will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
## of MERCHANTIBILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser
## General Public License
## for more details.
##
## You should have received a copy of the GNU Lesser General Public License
## along with this program.  (It's in the $(ROOT)/doc directory.  Run make
## with no target there if the PDF file isn't present.)  If not, see
## <http://www.gnu.org/licenses/> for a copy.
## }}}
## License:	LGPL, v3, as defined and found on www.gnu.org,
## {{{
##		http://www.gnu.org/licenses/lgpl.html
##
################################################################################
##
## }}}
# Make certain the "all" target is the first and therefore the default target
.PHONY: all
all:	hbexec hbexecaxi hbints hbnewline
#
RTL   := ../../rtl
FWB   := fwb_master.v
FAXIL := ../../../bench/formal/faxil_master.v

.PHONY: hbexec
## {{{
hbexec: hbexec_prf/PASS
hbexec_prf/PASS: hbexec.sby $(RTL)/hbexec.v fwb_master.v
	sby -f hbexec.sby prf
## }}}

.PHONY: hbexecaxi
## {{{
hbexecaxi: hbexecaxi_prf/PASS hbexecaxi_prflp/PASS hbexecaxi_cvr/PASS
hbexecaxi_prf/PASS: hbexecaxi.sby $(RTL)/hbexecaxi.v $(FAXIL)
	sby -f hbexecaxi.sby prf
hbexecaxi_prflp/PASS: hbexecaxi.sby $(RTL)/hbexecaxi.v $(FAXIL)
	sby -f hbexecaxi.sby prflp
hbexecaxi_cvr/PASS: hbexecaxi.sby $(RTL)/hbexecaxi.v $(FAXIL)
	sby -f hbexecaxi.sby cvr
## }}}

.PHONY: hbints
## {{{
hbints: hbints_prf/PASS
hbints_prf/PASS: hbints.sby $(RTL)/hbints.v
	sby -f hbints.sby prf
## }}}

.PHONY: hbnewline
## {{{
hbnewline: hbnewline_prf/PASS
hbnewline_prf/PASS: hbnewline.sby $(RTL)/hbnewline.v
	sby -f hbnewline.sby prf
## }}}

.PHONY: clean
## {{{
clean:
	rm -rf hbexec_*/
	rm -rf hbexecaxi_*/
	rm -rf hbints_*/
	rm -rf hbnewline_*/
## }}}
