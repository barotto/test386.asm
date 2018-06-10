# test386.asm

test386.asm is a 80386 or later CPU tester, written for the 
[NASM](http://www.nasm.us/) assembler. It runs as a BIOS replacement and does
not depend on any OS or external library.

test386.asm communicates with the external world through the POST I/O port and
the parallel and/or serial ports. You'll need to configure the addresses of
these ports for the system you're testing.

Please note that in the current version, test386.asm is still incomplete and is
not able to test every functionality of the CPU. It will probably not detect
that bug that is keeping you up at night, sorry.

**WARNING**: this program is designed for emulators and was never tested on real
hardware. Use at your own risk.

## How to assemble

First of all open <tt>src/test386.asm</tt> and configure the EQUs in the
CONFIGURATION section with suitable values for your system.

Then grab the NASM assembler from http://www.nasm.us/ and follow its
installation instructions.

If you're in a UNIX environment you can then use:
```
$ make
```

Otherwise use a command line like this one:
```
nasm -i./src/ -f bin src/test386.asm -l test386.lst -o test386.bin
```

Please note that the <tt>(testBCD:19) unterminated string</tt> warning is
expected and can be ignored.

The final product is a binary file named <tt>test386.bin</tt> of exactly
65,536 bytes.

## How to use

The binary assembled file must be installed at physical address 0xf0000 and
aliased at physical address 0xffff0000.  The jump at resetVector should align
with the CPU reset address 0xfffffff0, which will transfer control to f000:0045.
All memory accesses will remain within the first 1MB.

Once the system is powered on, testing starts immediately and after a while
you should get the <tt>FFh</tt> code. In case of error the program will execute
an HLT instruction and the diagnostic code will tell you the test that caused
the problem. You should then use the logging facility of your emulator to
inspect the instruction execution flow.

I suggest to use the intermediate source-listing file <tt>test386.lst</tt> as a
guide to diagnose any possible error.

This is the list of tests with their diagnostic code:

| POST | Description                                                        |
| ---- | ---------------------------------------------------------------    |
| 0x00 | Conditional jumps and loops                                        |
| 0x01 | Quick tests of unsigned 32-bit multiplication and division         |
| 0x02 | Move segment registers in real mode                                |
| 0x03 | Store, move, scan, and compare string data in real mode            |
| 0x04 | Call in real mode                                                  |
| 0x05 | Load full pointer in real mode                                     |
| 0x09 | Page directory and page table setup, enable protected mode         |
| 0x0A | Stack functionality                                                |
| 0x0B | Moving a segment register to a 32-bit memory location              |
| 0x0C | Zero and sign-extension                                            |
| 0x0D | 16-bit addressing                                                  |
| 0x0E | 32-bit addressing                                                  |
| 0x0F | Access memory using various addressing modes                       |
| 0x10 | Store, move, scan, and compare string data in protected mode       |
| 0x11 | Page faults and memory access rights                               |
| 0x12 | Bit Scan operations                                                |
| 0x13 | Bit Test operations                                                |
| 0x14 | Double precision shifts                                            |
| 0x15 | Byte set on condition                                              |
| 0x16 | Call in protected mode                                             |
| 0x17 | Adjust RPL Field of Selector (ARPL)                                |
| 0x18 | Check Array Index Against Bounds (BOUND)                           |
| 0xE0 | Undefined behaviours and bugs (CPU family dependent) *             |
| 0xEE | Series of unverified tests for arithmetical and logical opcodes ** |
| 0xFF | Testing completed                                                  |

\* test <tt>0xE0</tt> needs to be enabled via the TEST_UNDEF equ, and 
the proper CPU family needs to be specified with the CPU_FAMILY equ (currently
only 80386 supported).

\** test <tt>0xEE</tt> always completes successfully. It will print its
computational results on the parallel and/or serial ports. You'll need to
manually compare those results with the reference file
**<tt>test386-EE-reference.txt</tt>** using a diff-like tool.

For the full list of tested opcodes see **<tt>intel-opcodes.ods</tt>**.
Those opcodes that are tested have the relevant diagnostic code in the "test in
real mode" and/or "test in prot. mode" columns.

## Copyright

test386.asm was originally developed for
[IBMulator](http://barotto.github.io/IBMulator)
starting as a derivative work of
[PCjs](http://pcjs.org).

Distributed under the GNU General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option) any 
later version.

