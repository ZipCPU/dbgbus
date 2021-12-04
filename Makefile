################################################################################
##
## Filename:	Makefile
## {{{
## Project:	dbgbus, a collection of 8b channel to WB bus debugging protocols
##
## Purpose:	A master project makefile.  It tries to build all targets
##		within the project, mostly by directing subdirectory makes.
##
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
all:	rtl sim sw itest
#
SUBMAKE:= $(MAKE) --no-print-directory -C

#
#
# Check that we have all the programs available to us that we need
#
#
.PHONY: check-install
check-install: check-verilator check-gpp

.PHONY: check-verilator
check-verilator:
	$(call checkif-installed,verilator,-V)

.PHONY: check-gpp
check-gpp:
	$(call checkif-installed,g++,-v)

#
#
# Verify that the rtl has no bugs in it, while also creating a Verilator
# simulation class library that we can then use for simulation
#
.PHONY: verilated
verilated: check-verilator
	+@$(SUBMAKE) bench/rtl

.PHONY: rtl
rtl: verilated

#
#
# Build a simulation of this entire design
#
.PHONY: sim
sim: rtl check-gpp
	+@$(SUBMAKE) bench/cpp

#
#
# Run a scripted test of what would be interactive, were the post to be followed
#
.PHONY: itest
itest: sim
	+@$(SUBMAKE) bench/cpp test

#
#
# Build the host support software
#
.PHONY: sw
sw: check-gpp
	+@$(SUBMAKE) sw

#
#
# Check if the given program is installed
#
define	checkif-installed
	@bash -c '$(1) $(2) < /dev/null >& /dev/null; if [[ $$? != 0 ]]; then echo "Program not found: $(1)"; exit -1; fi'
endef


.PHONY: clean
clean:
	+$(SUBMAKE) bench/rtl     clean
	+$(SUBMAKE) bench/cpp     clean
	+$(SUBMAKE) sw            clean
