# Debug Bus Interface(s)

This depository consists of a series of debugging bus interfaces.

Each interface connects an external debug port, whether UART, SPI, JTAG, or
RPI Parallel port, to the master port of a wishbone
bus.  Hence, the debug interface allows you access to any device located on
the wishbone bus--both to read from and write to that bus.

It is my intention to use the various components of each of the busses as
teaching tools on the [ZipCPU blog](http://zipcpu.com).  Indeed, if you
look at the [topics page of the blog](http://zipcpu.com/topics.html), you'll
see that the series is now complete.

## License

All of the files in this repository are licensed by either GPLv3 or the LGPL.
For example, the simple [HEXBUS](/hexbus) interface is licensed under the LGPL, whereas
the other interfaces are (or will be) licensed under GPL.
Should the license provided be insufficient for your needs, please feel free
to contact me for the terms necessary for a more appropriate license.


