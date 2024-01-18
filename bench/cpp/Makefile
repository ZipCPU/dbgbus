################################################################################
##
## Filename: 	bench/cpp/Makefile
## {{{
## Project:	dbgbus, a collection of 8b channel to WB bus debugging protocols
##
## Purpose:	To direct the final build of the bench testing (verilator)
##		simulation program.
##
## Creator:	Dan Gisselquist, Ph.D.
##		Gisselquist Technology, LLC
##
################################################################################
## }}}
## Copyright (C) 2015-2024, Gisselquist Technology, LLC
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
all:
# we'll fill in what "all" references in a moment
#
# Set up some variables
CXX	:= g++
# Cross compilation has taught me to use an object file directory that can be
# adjusted to reference one machine or another.
OBJDIR	:= obj-pc
# Our bench/rtl directory ...
RTLD	:= ../rtl
# This has the obj_dir subdirectory within it
VOBJDR	:= $(RTLD)/obj_dir
# We need to figure out the VERILATOR_ROOT variable.  This will tell us where
# all the Grab it from Verilator -V.
VERILATOR_ROOT ?= $(shell bash -c 'verilator -V|grep VERILATOR_ROOT | head -1 | sed -e " s/^.*=\s*//"')
VROOT	:= $(VERILATOR_ROOT)
VINCD   := $(VROOT)/include
VINC	:= -I$(VINCD) -I$(VOBJDR) -I../../sw/host -I../../sw
# We'll need to build these two Verilater files, and include them with our
# build
VSRCRAW := verilated.cpp verilated_vcd_c.cpp verilated_threads.cpp
VSRC    := $(addprefix $(VINCD)/,$(VSRCRAW))
VOBJ    := $(addprefix $(OBJDIR)/,$(subst .cpp,.o,$(VSRCRAW)))
INCS	:= $(VINC)
CFLAGS	:= -Og -g -faligned-new -Wall $(INCS)
#
BUS := hexbus
SUBMAKE := $(MAKE) --no-print-directory -C

# A list of our sources and headers.  These are used by the dependency generator
# below
TBSOURCES := testbus_tb.cpp uartsim.cpp
SOURCES   := $(TBSOURCES) autotest.cpp
TBHEADERS := $(foreach header,$(subst .cpp,.h,$(TBSOURCES)),$(wildcard $(header)))
TBOBJECTS := $(addprefix $(OBJDIR)/,$(subst .cpp,.o,$(TBSOURCES))) $(VOBJ)
AUTOSRC   := autotest.cpp uartsim.cpp
AUTOHDR   := $(foreach header,$(subst .cpp,.h,$(AUTOSRC)),$(wildcard $(header)))
AUTOOBJ   := $(addprefix $(OBJDIR)/,$(subst .cpp,.o,$(AUTOSRC))) $(VOBJ)
#
PROGRAMS := testbus_tb autotest
#
# Now the return to the default/"all" target, and fill in some details
all: $(PROGRAMS) test

#
# Generic build instructions for object files
$(OBJDIR)/%.o: %.cpp
	$(mk-objdir)
	$(CXX) $(CFLAGS) -c $< -o $@

#
# And we'll repeat those instructions for building object files from sources
# within the Verilator directory found within $(VERILATOR_ROOT)
$(OBJDIR)/%.o: $(VINCD)/%.cpp
	$(mk-objdir)
	$(CXX) $(CFLAGS) -c $< -o $@

#
# Build our actual target.  Note the dependency on the $(OBJECTS) list of
# object files above
testbus_tb: $(TBOBJECTS) $(VOBJDR)/Vtestbus__ALL.a
	$(CXX) $(CFLAGS) $(TBOBJECTS) $(VOBJDR)/Vtestbus__ALL.a -lpthread -o $@
#
#
#
autotest: $(AUTOOBJ) $(VOBJDR)/Vtestbus__ALL.a
	$(CXX) $(CFLAGS) $(AUTOOBJ) $(VOBJDR)/Vtestbus__ALL.a -lpthread -o $@

test:
#
#
# The "test" target, runs autotest to check if our core does what it should
# without any user interaction
#
.PHONY: test
test: autotest
	./autotest

#
# The "depends" target, to know what files things depend upon.  The depends
# file itself is kept in $(OBJDIR)/depends.txt
#
define build-depends
	$(mk-objdir)
	@echo "Building dependency file"
	@$(CXX) $(CFLAGS) $(INCS) -MM $(SOURCES) > $(OBJDIR)/xdepends.txt
	@sed -e 's/^.*.o: /$(OBJDIR)\/&/' < $(OBJDIR)/xdepends.txt > $(OBJDIR)/depends.txt
	@rm $(OBJDIR)/xdepends.txt
endef

.PHONY: depends
depends: tags
	$(build-depends)

$(OBJDIR)/depends.txt: depends

#
# Make sure the $(OBJDIR)/ directory exists.  This has taken some work to get
# right.  While "mkdir -p $(OBJDIR)" could be used to do this as well, it
# always bothered me that it seemed to be perpetually running.  Hence, we'll
# first check if the directory exists, and only create it if it does not.
# Finally, by adding the @ in front of the bash command, it won't get printed
# to the screen.  That way ... I can run it as often as I want without getting
# annoyed by it.  ;)
define	mk-objdir
	@bash -c "if [ ! -e $(OBJDIR) ]; then mkdir -p $(OBJDIR); fi"
endef


#
# The "tags" target
#
tags:	$(SOURCES) $(HEADERS)
	@echo "Generating tags"
	@ctags $(SOURCES) $(HEADERS)

#
# The "clean" target, removing any and all remaining build (and test) products
#
.PHONY: clean
clean:
	rm -f *.vcd
	rm -f $(PROGRAMS)
	rm -rf $(OBJDIR)/

#
# Include our generated dependency file.  The "-" in front of the include
# basically tells "make" to include it if it can, and ignore it if it cannot
# be included (i.e. if it doesn't exist)
ifneq ($(MAKECMDGOALS),clean)
-include $(OBJDIR)/depends.txt
endif
