test386.asm is a CPU tester for the 80386 or later processor. It runs as a BIOS
replacement and does not depend on any OS or external library.

If your emulator is having problems booting and loading an OS, this ROM could be
the only way to do automatic tests on the emulated CPU.

test386.asm is written in assembly for the [NASM](http://www.nasm.us/)
assembler.

test386.asm communicates with the external world through the POST I/O port and
the parallel and/or serial ports. You'll need to configure the addresses of
these ports for the system you're testing.

Please note that in the current version, test386.asm is still incomplete and is
not able to test every functionality of the 80386 CPU. It will probably not
detect that bug that is keeping you up at night, sorry.

The binary assembled file must be installed at physical address 0xf0000 and
aliased at physical address 0xffff0000.  The jump at resetVector should align
with the CPU reset address 0xfffffff0, which will transfer control to f000:0045.
All memory accesses will remain within the first 1MB.

In case of error the POST code will tell you the test that caused the problem.
Use the following list for reference:

POST 00 Conditional jumps and loops  
POST 01 Quick tests of unsigned 32-bit multiplication and division  
POST 02 Move segment registers to 16/32-bit registers  
POST 03 Store, move, scan, and compare string data in real mode  
POST 04 Call in real mode
POST 09 Page directory and page table setup, enable protected mode  
POST 0A Stack functionality  
POST 0B Moving a segment register to a 32-bit memory location  
POST 0C Zero and sign-extension  
POST 0D 16-bit addressing  
POST 0E 32-bit addressing  
POST 0F Access memory using various addressing modes  
POST 10 Store, move, scan, and compare string data in protected mode  
POST 11 Page faults  
POST 12 Bit Scan operations  
POST 13 Bit Test operations  
POST 14 Double precision shifts  
POST 15 Byte set on condition  
POST 16 Call in protected mode
POST 17 Adjust RPL Field of Selector (ARPL)
POST 18 Check Array Index Against Bounds (BOUND)
POST EE Series of unverified tests for arithmetical and logical opcodes  
POST FF Testing completed

Note: test 0xEE always completes successfully. It will print its computational 
results on the parallel and/or serial ports. You'll need to manually compare
those results with the reference file test386-EE-reference.txt

**WARNING**: this program is designed to test emulators and was never tested on
real hardware. Use at your own risk.

test386.asm was originally developed for
[IBMulator](http://barotto.github.io/IBMulator)
starting as a derivative work of
[PCjs](http://pcjs.org).

Distributed under the GNU General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option) any 
later version.

