################################################################################
##
## Filename: 	bench/rtl/Makefile
## {{{
## Project:	dbgbus, a collection of 8b channel to WB bus debugging protocols
##
## Purpose:	This Makefile guides the translation of the project RTL files
##		into a library (Vtestbus__ALL.a) file that can then be linked
##	with our C++ test-bench driver routine.
##
## Targets:
##
##	verilate
##		This target runs Verilator to produce its files in $(VDIRFB)
##		(i.e. in obj_dir).  This target depends upon the projects
##		verilog files.
##
##	library
##		This target tells make to CD into the $(VDIRFB) (i.e. obj_dir)
##		directory created by verilator, and to run make on the
##		Verilator produced output.  The result is a V(*)__ALL.a file
##		that we can then link with later.
##
## Creator:	Dan Gisselquist, Ph.D.
##		Gisselquist Technology, LLC
##
################################################################################
## }}}
## Copyright (C) 2017-2021, Gisselquist Technology, LLC
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
# all, the first target, becomes the default target
all:
#
# We'll place into the $(BUS) variable which (of possibly multiple) debugging
# bus we want to test.  (Around here, I've also got wbubus and exbus as options,
# options that are not yet in the repository ... if they ever will be.)
BUS ?= hexbus
#
# Verilator places everything into obj_dir by default.  By creating a variable
# with this name, we can adjust it and everything will adjust as appropriate
VDIRFB  := obj_dir
#
# We'll need to call make in subdirectories.  Here's how we're going to do it.
# The actual call will need to look like $(SUBMAKE) <directory> <target>
SUBMAKE := $(MAKE) --no-print-directory -C
#
# In case you have verilator in a strange place that's not necessarily in your
# path, we allow it to be overridden here.
VERILATOR := verilator
#
# Verilator flags
#	-Wall	Turn all warnings on, and stop on a warning as if an error
#	--MMD	Build/update a dependency file, so we know when we need to
#		rebuild
#	-trace	Build a VCD generation facility into Verilator's output
#	-y <dir> Let verilator know that some of our source is in the <dir>
#		directory
#	--Mdir <dir>	Place our output files into <dir>, or $(VDIRFB) here
#	-cc	Create C++ output files (in $(VDIRFB)
#
VFLAGS := -Wall --MMD -trace -y ../../$(BUS)/rtl --Mdir $(VDIRFB) -cc

#
# Now that all of our defines are out of the way, we'll specify two default
# targets.  The first just runs verilator.  The second actually builds our
# library within the $(VDIRFB) directory
.PHONY: all
all: verilate library quikbus quiklib

.DELETE_ON_ERROR:

#
# The "verilate" target doesn't produce any files.  Just insist instead
# that the Vtestbus.h file exist
.PHONY: verilate
verilate: $(VDIRFB)/Vtestbus.h
.PHONY: quikbus
quikbus: $(VDIRFB)/Vquikbus.h

#
# Run Verilator on our RTL code
$(VDIRFB)/Vtestbus.h:
	$(VERILATOR) $(VFLAGS) testbus.v
$(VDIRFB)/Vquikbus.h:
	$(VERILATOR) $(VFLAGS) quikbus.v

.PHONY: library
## {{{
## Build the library from the Verialtor outputs.
## This just runs make in the $(VDIRFB) directory on the file Vtestbus.mk
## (also in the $(VDIRFB) directory)
library: $(VDIRFB)/Vtestbus.h
	$(SUBMAKE) $(VDIRFB)/ -f Vtestbus.mk
## }}}

quiklib: $(VDIRFB)/Vquikbus.h
	$(SUBMAKE) $(VDIRFB)/ -f Vquikbus.mk

.PHONY: clean
## {{{
## Clean up any make by products, so we can start from scratch if we need to
clean:
	rm -rf $(VDIRFB)/
## }}}

#
# Note and incorporate any dependency information, so that we'll know when/if
# we need to rebuild.
DEPS := $(wildcard $(VDIRFB)/*.d)

ifneq ($(DEPS),)
include $(DEPS)
endif
