# HexBus Debugging Protocol

The files in this directory contain a *very simple* protocol for commanding
a wishbone bus.  I call it the "Hex Bus" protocol.  It is designed to be
a simple demonstration of what can be done with an on-board protocol.

## Design Goals

The protocol was built with two primary goals in mind:

- It should be easy for someone new to FPGA's to understand

- It should be easy for someone reading the protocol to understand what's taking place across it.

Note what's not a part of this protocol: efficiency.  There are a lot of
efficiency things that can be added to this bus.  Those are left as the
topic of another design on another day.

## Posts Describing this port

This port is being developed and presented as part of the
[ZipCPU Blog](http://zipcpu.com).  On that blog, you'll find articles
describing:

1. An overview of a debugging wishbone interface
   [[Ref]](http://zipcpu.com/blog/2017/06/05/wb-bridge-overview.html)

2. A description of the wishbone bus master portion of the interface
   [[Ref]](http://zipcpu.com/blog/2017/06/08/simple-wb-master.html)

3. A description of the Verilog end of this interface
   [[1]](http://zipcpu.com/blog/2017/06/14/creating-words-from-bytes.html)
   [[2]](http://zipcpu.com/blog/2017/06/15/words-back-to-bytes.html)
   [[3]](http://zipcpu.com/blog/2017/06/16/adding-ints.html)
   [[4]](http://zipcpu.com/blog/2017/06/19/debug-idles.html)
   [[5]](http://zipcpu.com/blog/2017/06/20/dbg-put-together.html)

4. A description of the [software interface](sw)
   [[Ref]](http://zipcpu.com/blog/2017/06/29/sw-dbg-interface.html)


## Making things legible

If you are new to running a command link across a serial port, then you may
be curious how the whole thing works.  You'd like to watch the interaction
between the host computer and the FPGA and understand the link.  You might
even wish to debug the link, by watching it and seeing what's going on.

For this reason, every character used on this link is a printable character.
Newlines and carriage returns among them will not break the link.  You could
even type commands into the serial port by hand [using a
terminal](http://zipcpu.com/blog/2017/06/26/dbgbus-verilator.html), if you
like.  (Not recommended, but there is a time and place for it ...)

In our port, there are four basic commands that you can send to the FPGA: 

- A set address request starts with an 'A', and it is followed by the address
  in question in lower case hexadecimal.  Only word addressing is supported,
  therefore the last two bits
  are special.  addr[0], if set, means that subsequent reads (or writes) will
  not increment the address.  addr[1] if set means this is a difference address
  that will be added to the last address.

- A read request starts with an 'R'.  Since the address has already been given,
  no further information is required to accomplish a single read.

- A write request starts with a 'W' and is followed by up to 8 lower case
  hexadecimal characters.  Any unspecified upper bits are filled with zeros.

  Multiple writes may be separated by either commas, newlines, or any other
  character not otherwise used in the protocol.

- You can also reset the port by sending a 'T' (for reseT).

The bus will then return a response to these various commands:

- Set address commands will receive a confirmation containing new address in
  response.  This response will begin with an 'A', and will end with up to
  eight 4-bit hex words.

- Read request commands will receive a read response.  Read responses begin
  with and 'R', and they are followed with up to eight hexadecimal characters

- Write requests are acknowledged with a simple 'W' per request.

- If reset, the board will respond with a 'T'

- In an interrupt occurrs on the board, the board will place an 'I' into the
  channel.  It will not produce any more interrupts down the channel until
  the interrupt line is reset

- If the channel is idle, then periodically an idle byte ('Z') will be sent
  through the channel just so you know that it's there.

- Any and all other "special" responses will start with a 'S' and be followed
  by up to 8-hex characters indicating the payload of the response

As an example, suppose we wish to write a 0x823471 to address 0x01000.  If we
prefix commands sent to the bus with "< " and things received with "> ", the
interaction would look something like:

```text
> Z
< A1000W823471
> W
> Z
```

## Hex Bus Capabilities

Eventually, we'll compare and contrast various bus capabilities against each
other.  For now, it's worth describing the command link into the FPGA with
the characteristics:

| Keyword | Value |
|:------------------------|------------------:|
| Codeword size           | 34-bits           |
| Compression             | None              |
| Data bits used per byte | 4                 |
| Vector Read Support     | No | 
| Asynchronous Read/Write | No | 
| Commands Accepted       | Set address, Read, Write, Reset | 
| Bytes per Address       | 2-9 | 
| Bytes per Write         | 2-9 | 
| Bytes per Read          | 1  | 
| Worst case (Write) Rate | 9(N+1)  | 

The reverse link, coming back from the FPGA, may be summarized as:

| Keyword | Value
|:------------------------|------------------:|
| Data bits used per byte | 4                 |
| Compression             | None              |
| Interrupt Support       | None | 
| Vector Read Support     | No | 
| Asynchronous Read/Write | No | 
| Commands Accepted       | Set address, Read, Write, Reset | 
| Bytes per Address       | 2-9 | 
| Bytes per Write         | 1 | 
| Bytes per Read          | 2-9 on return  | 
| Worst case (Read) Rate | 9(N+1)  | 
|-------------------------|-------------------|

## Not Rocket Science

This command link is far from rocket science.  It's not a very high performance
link: it doesn't support compression, can't handle more than one transaction
at a time, has no FIFO support, and has a very low bandwidth at up to 9 bytes
required per transaction.  Still, it's a working bus and worth looking into
to understand how such a bus might be written.

