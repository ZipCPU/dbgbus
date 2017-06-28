################################################################################
##
## Filename:	Makefile
##
## Project:	dbgbus, a collection of 8b channel to WB bus debugging protocols
##
## Purpose:	
## Targets:	
##
## Creator:	Dan Gisselquist, Ph.D.
##		Gisselquist Technology, LLC
##
################################################################################
##
## Copyright (C) 2015-2017, Gisselquist Technology, LLC
##
## This file is part of the debugging interface demonstration.
## The debugging interface demonstration is free software (firmware): you can
## redistribute it and/or modify it under the terms of the GNU Lesser General
## Public License as published
## by the Free Software Foundation, either version 3 of the License, or (at
## your option) any later version.
##
## This debugging interface demonstration is distributed in the hope that it
## will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
## of MERCHANTIBILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser
## General Public License for more details.
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
.PHONY: all
PROGRAMS := wbregs netuart
SCOPES :=
all: $(PROGRAMS) $(SCOPES)
CXX := g++
OBJDIR := obj-pc
BUS := hexbus
EXTSRCS := $(BUS).cpp
LCLSRCS := llcomms.cpp regdefs.cpp
BUSSRCS := $(LCLSRCS) $(addprefix ../$(BUS)/sw/,$(EXTSRCS))
DEPSRCS := wbregs.cpp netuart.cpp $(BUSSRCS)
HEADERS := llcomms.h port.h scopecls.h devbus.h $(wildcard ../$(BUS)/sw/*.h)
BUSOBJS := $(addprefix $(OBJDIR)/,$(subst .cpp,.o,$(LCLSRCS) $(EXTSRCS)))
CFLAGS := -g -Wall -I. -I../../rtl -I../$(BUS)/sw
LIBS :=
SUBMAKE := $(MAKE) --no-print-directory -C

.PHONY: objects
objects:
	echo $(BUSOBJS)

%.o: $(OBJDIR)/%.o
$(OBJDIR)/%.o: %.cpp
	$(mk-objdir)
	$(CXX) $(CFLAGS) -c $< -o $@
$(OBJDIR)/%.o: %.c
	$(mk-objdir)
	$(CXX) $(CFLAGS) -c $< -o $@
$(OBJDIR)/%.o: ../hexbus/sw/%.cpp
	$(mk-objdir)
	$(CXX) $(CFLAGS) -c $< -o $@

$(OBJDIR)/hexbus.o: ../hexbus/sw/hexbus.cpp
	$(mk-objdir)
	$(CXX) $(CFLAGS) -c $< -o $@

.PHONY: clean
clean:
	rm -rf $(OBJDIR)/ $(PROGRAMS) a.out tags *.o

$(OBJDIR)/dumpflash.o:   dumpflash.cpp regdefs.h

netuart: $(OBJDIR)/netuart.o
	$(CXX) $(CFLAGS) $^ -o $@
#
# Some simple programs that just depend upon the ability to talk to the FPGA,
# and little more. 
#
wbregs: $(OBJDIR)/wbregs.o $(BUSOBJS)
	$(CXX) $(CFLAGS) $^ $(LIBS) -o $@

## SCOPES
# These depend upon the scopecls.o, the bus objects, as well as their
# main file(s).
memscope: $(OBJDIR)/memscope.o $(OBJDIR)/scopecls.o $(BUSOBJS)
	$(CXX) $(CFLAGS) $^ $(LIBS) -o $@

define	mk-objdir
	@bash -c "if [ ! -e $(OBJDIR) ]; then mkdir -p $(OBJDIR); fi"
endef

define	build-depends
	@echo "Building dependency file(s)"
	$(mk-objdir)
	$(CXX) $(CFLAGS) -MM $(DEPSRCS) > $(OBJDIR)/xdepends.txt
	@sed -e 's/^.*.o: /$(OBJDIR)\/&/' < $(OBJDIR)/xdepends.txt > $(OBJDIR)/depends.txt
	@rm $(OBJDIR)/xdepends.txt
endef

tags: $(DEPSRCS) $(HEADERS)
	@echo "Generating tags"
	@ctags $(DEPSRCS) $(HEADERS)

.PHONY: depends
depends: $(OBJDIR)/depends.txt

$(OBJDIR)/depends.txt: $(DEPSRCS) $(HEADERS)
	$(build-depends)

-include $(OBJDIR)/depends.txt
