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

POST 0 Basic 16-bit flags, jumps, and shifts tests  
POST 1 Quick tests of unsigned 32-bit multiplication and division  
POST 2 Test of moving a segment register to a 32-bit register  
POST 3 Test store, move, scan, and compare string data in real mode  
POST 4 Page directory and a page table setup  
POST 5 Protected mode enable  
POST A Test the stack  
POST B Test moving a segment register to a 32-bit memory location  
POST C Test zero and sign-extension  
POST D Test 16-bit addressing  
POST E Test 32-bit addressing  
POST F Access memory using various addressing modes  
POST 10 Verify string operations  
POST 11 Verify Page faults  
POST 12 Verify Bit Scan operations  
POST 13 Verify Bit Test operations  
POST 14 Test double precision shifts  
POST EE Series of unverified tests for arithmetical and logical opcodes  
POST FE Testing finished, back to real mode  
POST FF Testing successful

Note: test 0xEE always completes successfully. It will print its computational 
results on the parallel and/or serial ports. You'll need to manually compare
those results with the reference file test386-EE-reference.txt

**WARNING**: this program is designed to test emulators and was never tested on
real hardware. Use at your own risk.

test386.asm is a derivative work of [PCjs](http://pcjs.org) and originally
developed for [IBMulator](http://barotto.github.io/IBMulator)

Distributed under the GNU General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option) any 
later version.

