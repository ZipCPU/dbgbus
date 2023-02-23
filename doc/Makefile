################################################################################
##
## Filename: 	Makefile
## {{{
## Project:	wbuart32, a full featured UART with simulator
##
## Purpose:	To coordinate the build of documentation PDFs from their
##		LaTeX sources.
##
##	Targets include:
##		all		Builds all documents
##
##		gpl-3.0.pdf	Builds the GPL license that some of the files in
##				this repository are released under.
##
##		lgpl-3.0.pdf	Builds the LGPL license that everything else is
##				released under.
##
## Creator:	Dan Gisselquist, Ph.D.
##		Gisselquist Technology, LLC
##
################################################################################
## }}}
## Copyright (C) 2015-2023, Gisselquist Technology, LLC
## {{{
## This program is free software (firmware): you can redistribute it and/or
## modify it under the terms of  the GNU General Public License as published
## by the Free Software Foundation, either version 3 of the License, or (at
## your option) any later version.
##
## This program is distributed in the hope that it will be useful, but WITHOUT
## ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
## FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
## for more details.
##
## You should have received a copy of the GNU General Public License along
## with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
## target there if the PDF file isn't present.)  If not, see
## <http://www.gnu.org/licenses/> for a copy.
## }}}
## License:	GPL, v3, as defined and found on www.gnu.org,
## {{{
##		http://www.gnu.org/licenses/gpl.html
##
################################################################################
##
## }}}
.PHONY: all
all:	gpl lgpl
pdf:	gpl lgpl
DSRC := src

.PHONY: gpl
## GPL
## {{{
gpl:   gpl-3.0.pdf
gpl-3.0.pdf: $(DSRC)/gpl-3.0.tex
	latex $(DSRC)/gpl-3.0.tex
	latex $(DSRC)/gpl-3.0.tex
	dvips -q -z -t letter -P pdf -o gpl-3.0.ps gpl-3.0.dvi
	ps2pdf -dAutoRotatePages=/All gpl-3.0.ps gpl-3.0.pdf
	rm gpl-3.0.dvi gpl-3.0.log gpl-3.0.aux gpl-3.0.ps
## }}}

.PHONY: lgpl
## LGPL
## {{{
lgpl: lgpl-3.0.pdf
lgpl-3.0.pdf: $(DSRC)/lgpl-3.0.tex
	latex $(DSRC)/lgpl-3.0.tex
	latex $(DSRC)/lgpl-3.0.tex
	dvips -q -z -t letter -P pdf -o lgpl-3.0.ps lgpl-3.0.dvi
	ps2pdf -dAutoRotatePages=/All lgpl-3.0.ps lgpl-3.0.pdf
	rm lgpl-3.0.dvi lgpl-3.0.log lgpl-3.0.aux lgpl-3.0.ps
## }}}

.PHONY: clean
## {{{
clean:
	rm -f gpl-3.0.pdf
	rm -f lgpl-3.0.pdf
## }}}
