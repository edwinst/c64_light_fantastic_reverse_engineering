# Reverse engineering of the "Light fantastic" experiment's software

Here are my notes for my ongoing reverse-engineering of the C64 programs for the "Light fantastic" experiment.

# Summary

First, the summary comment I made under Perifractic's video:

I've disassembled the tuning and receiver programs for C64. Strangely, the
receiver program looks incomplete. Here's how it basically works:

HW: The multivibrator is used to lengthen the pulses read by the
phototransistor in order to bridge the gap between TV frames. The tuning
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
gap. The program then synchronizes again to the start bit of the next byte. All
the timing and reading loops are there, but strangely, my disassembly seems to
be missing the part that actually stores the transmitted data in memory.

Above the byte level there is some kind of protocol for transmitting
zero-terminated byte sequences. I do not yet understand that part due to the
missing (?) code. For more info, contact me using edwin dot steiner at
gmx dot net.

# Protocol

Bytes are transmitted as 9 bits (a fixed '0' start bit and then 8 data bits).
After each byte there is a little gap that could be interpreted as "don't care" stop bit(s).

The overall protocol for receiving bytes seems to work like this:

    - read 2 bytes; if both are zero, then quit
    - read 2 bytes (any values)
    - read 1..n zero-terminated bytes (including the zero byte)
    - repeat

# Missing code

In the receiver program, there are JSRs (subroutine calls) to the address $C075.
The code expected at that address seems to be responsible for processing the
bytes received from the TV. However, the published C64 program ends exactly
before this address!


