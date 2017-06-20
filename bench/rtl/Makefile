################################################################################
##
## Filename: 	bench/rtl/Makefile
##
## Project:	dbgbus, a collection of 8b channel to WB bus debugging protocols
##
## Purpose:	
##
## Creator:	Dan Gisselquist, Ph.D.
##		Gisselquist Technology, LLC
##
################################################################################
##
## Copyright (C) 2015-2017, Gisselquist Technology, LLC
##
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
##
## License:	LGPL, v3, as defined and found on www.gnu.org,
##		http://www.gnu.org/licenses/lgpl.html
##
##
################################################################################
##
##
all:
BUS := hexbus
SUBMAKE := $(MAKE) --no-print-directory -C

.PHONY: all
all: verilate library

.PHONY: verilate
verilate: obj_dir/Vtestbus.h

obj_dir/Vtestbus.h: testbus.v txuartlite.v rxuartlite.v memdev.v wbscope.v
obj_dir/Vtestbus.h: testbus.v txuartlite.v rxuartlite.v memdev.v wbscope.v
obj_dir/Vtestbus.h: $(wildcard ../../$(BUS)/rtl/*.v)
	verilator -Wall -trace -cc testbus.v -y ../../$(BUS)/rtl

obj_dir/Vtestbus.mk:
obj_dir/Vtestbus.cpp:

.PHONY: library
library: obj_dir/Vtestbus.h
	$(SUBMAKE) obj_dir/ -f Vtestbus.mk

clean:
	rm -rf obj_dir/
