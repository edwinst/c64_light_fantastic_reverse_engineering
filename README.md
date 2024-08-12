# Reverse engineering of the "Light fantastic" experiment's software

Here are my notes for my ongoing reverse-engineering of the C64 programs for the "Light fantastic" experiment.

See the Retro Recipes video for what this is about: https://www.youtube.com/watch?v=MezkfYTN6EQ

# Summary

I've disassembled the tuning and receiver programs for C64. Strangely, the
receiver program looks incomplete. Here's how it basically works:

HW: The multivibrator is used to lengthen the pulses read by the
phototransistor in order to bridge the gap between TV fields (50 Hz "half-frames"). The tuning
procedure tells you to adjust the timing of the circuit such that the
lengthening of the pulses is just enough so the user port signal (PB7) never
goes to LOW if a bright square is displayed under the sensor.

Tuning program: It displays a bright square and then just checks if it ever
reads PB7 as LOW. If so, it puts an asterisk '*' between the arrows. (You can
clear the asterisk by pressing a key.) If the asterisk does no longer show up,
it means PB7 is reading HIGH each time it is sampled.

Receiver program: It first waits for a keypress. Then it waits for the bright
square to *dis*appear (i.e. the first start bit). Each byte is transmitted as a '0'
start bit and then 8 data bits with hard-coded timing. Then there is a short
gap (stop bit(s)). The program then synchronizes again to the start bit of the next byte. All
the timing and reading loops are there, but strangely, my disassembly seems to
be missing the part that actually stores the transmitted data in memory.

The receiver is designed to read a tokenized BASIC program into memory. For the C64,
it reads tokenized BASIC lines until a $0000 in the first two bytes of a tokenized
line signals the end of the program.

# Contact

For more info, contact me using edwin dot steiner at gmx dot net.

# Protocol

Bytes are transmitted as 9 bits (a fixed '0' start bit and then 8 data bits).
After each byte there is a little gap that could be interpreted as "don't care" stop bit(s).
They are not sampled by the receiver program. However, the transmission must go HIGH again
(i.e. bright square) after each byte before the receiver starts sampling again, so the receiver
can synchronize to the next start bit (transition HIGH -> LOW, i.e. bright -> dark).
In this sense the stop bit(s) must be '1'.

Bits are sent LSB first. (Each bit, after having been received, is rotated into the 'A' register using ROR,
which means bits enter the MSB of A and then move down to the right. So the first bit received this way
ends up in the LSB of 'A' when all bits of the byte have been received. The start bit is shifted out
of 'A' when the last data bit is shifted in.)

The overall protocol for receiving bytes seems to work like this (it is meant to read a tokenized BASIC program):

- main loop:
    - read 2 bytes (start address of next BASIC line); if both are zero (end of program), then quit
    - read 2 bytes (the tokenized line number, any values)
    - read 1..n zero-terminated bytes (including the zero byte) (this reads one tokenized BASIC line)
    - repeat main loop

# Bit timing

Bit timing within a byte is hard-coded in the receiver program by running a fixed number of iterations
of the delay loops.

A very rough estimate of the bit time, not considering bad lines or time spent outside of the delay routine:

On a PAL C64:

30 * 124 iterations of the delay loop = 18733 cycles = 18733 / (17.734475 MHz / 18) = 18733 * 1.015 µs = about 19 ms per bit

Considering some additional time spent outside of the delay code, this lines up with a bit time of ~20 ms, i.e. a bit frequency of 50 Hz, or one bit per TV field.

# Missing code

In the receiver program, there are JSRs (subroutine calls) to the address $C075.
The code expected at that address seems to be responsible for processing the
bytes received from the TV. However, the published C64 program ends exactly
before this address!

# Receiver program for BBC Micro

The receiver program for the BBC Micro is very similar to the one for C64 but it looks complete.
In particular, it does include the subroutine for storing the received bytes.

However, the protocol for determining when the transmission is over is different in the BBC receiver, due to the different format of tokenized BASIC lines on the BBC Micro.

The BBC protocol seems to work like this:

- read the first byte (the leading #$0D of the first tokenized line)
- main loop:
    - read a byte (this should be the high byte of a tokenized line number)
    - if the byte has bit 7 set, then quit
    - read a byte (this should be the low byte of a tokenized line number)
    - read a sequence of 1..n bytes, terminated by #$0D (carriage return; which is also stored)
    - repeat main loop

This protocol is meant to read a tokenized BASIC program. Each line starts with a #$0D character,
followed by two bytes for the line number. If the line number is >= 32768 unsigned ($8000), the receiver stops.

