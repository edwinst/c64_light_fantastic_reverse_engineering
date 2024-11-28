# Reverse engineering of the "Light fantastic" experiment

Here are my notes from reverse-engineering of the C64 programs for the "Light fantastic" experiment,
and some software accompanying my YouTube video in which I recreated the experiment.

"Light fantastic" was a broadcasting experiment in the 1985 British TV show "4 Computer Buffs" during which
programs for home computers were transmitted as part of the TV signal, encoded in a blinking dot on the screen.

My video in which I recreate the experiment is here:

- https://youtu.be/AF6sMBbEZLA

Further information about the experiment and attempts at reproducing it can be found in the following:

- Aug 10, 2024 Retro Recipes video "Receiving A Program From The Past " on YouTube: https://www.youtube.com/watch?v=MezkfYTN6EQ
- A thread on lemon64: https://www.lemon64.com/forum/viewtopic.php?p=1027686

# TUNETEST program

The TUNETEST program (`tunetest.prg`) is an improved tuning and test program I wrote for this experiment.

The program displays a dot blinking out various test sequences you can select using the function keys F5/F7.
Simultaneously (actually interleaved with updating the dot), the program samples the user port input PB7
(line "L") and writes the result ('1' or '0') on the screen. Each bit is colored depending on whether it
equals the expected value corresponding to the brightness of the dot (green = bit is as expected, red =
bit differs from expectation).

Note that other than the receiver program, the TUNETEST program does not need to synchronize with the
serial transmission. It always samples each bit in the middle of its bit period, based on the C64's raster
interrupt. Therefore, correct sampling results in the TUNETEST program are a necessary but not sufficient
condition for getting the reception to work with the receiver program.

If the alternating sequence is selected (the dot alternates between bright and dark with each PAL field,
i.e. it blinks with a frequency of 25 Hz), TUNETEST additionally measures the positive pulse width of the signal
received on user port input PB7 (line "L") and displays it by coloring a bar in the borders of the screen:

- If the bar is fully blue, the pulse width is below 20 ms.

- If the bar is fully yellow, the pulse width is above 20.8 ms.

- In between, the border between the yellow and blue areas of the bar indicates the pulse width linearly
between about 20 ms and 20.8 ms. When the blue and yellow areas have the same size, the pulse width
is approximately 20.4 ms and the circuit is tuned correctly. (When in doubt, a slightly longer pulse width
is better than a slightly too short one. So don't tune below 20.4 ms.)

- If no rising edge of the signal can be detected, the border turns red.

CAUTION: It is very important to place the sensor precisely and consistently centered on the dot.
Moving the sensor horizontally or vertically with respect to the dot changes the pulse width, since it
changes the shape of the brightness signal seen by the receiver circuit! Therefore tuning and reception
attempts MUST use the same positioning of the sensor relative to the dot to get good results!

The program can only be exited by resetting the C64. (Sorry about that, but cleaning up the state of
the computer would add quite a lot of code to the program.)

# Summary of disassembled programs

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

# Expected signal for the C64 program

Since the transmitted program is a tokenized BASIC program that will be placed at the default location
for BASIC programs on the C64 (starting at memory address $0801) and the first two bytes contain the address of the
next BASIC line (i.e. of the second line of the program), we can expect the following:

If the first line of the program uses strictly less than the maximum of 255 bytes (which is very likely), then
the second line will start at an address of the form $08xx, therefore the second byte of the transmission is
expected to be $08.

$08 is transmitted as (LSB first) 0001 0000. Including a start bit (0) and one or two stop bits (1), one of the following
patterns is expected at the start of the transmission:

For one stop bit per byte:

    ...111 (0) **** **** (10) 0001 0000 (1)

For two stop bits per byte:

    ...111 (0) **** **** (110) 0001 0000 (11)

where

    1         denotes 20 ms of a field with a bright dot
    0         denotes 20 ms of a field with darkness
    ...111    denotes the continuously bright dot before the transmission of the first byte
    *         denotes 20 ms of an unknown bit value in the first transmitted byte
    ( )       parentheses surround start and stop bits

    Note: Spaces are just for readability.

Using a video player with the capability to step through the fields of an interlaced video,
it should therefore be possible to check whether the expected signal is present.

## UPDATE of expected signal

I found that the actual "4 Computer Buffs" transmission used three stop bits of the values `011`.
(This may be an unused parity bit that is always 0 plus two stop bits.)

So the expected signal in this transmission is:


    ...111 (0) **** **** (0110) 0001 0000 (0110)

# Missing code

In the receiver program, there are JSRs (subroutine calls) to the address $C075.
The code expected at that address seems to be responsible for processing the
bytes received from the TV. However, the published C64 program ends exactly
before this address!

From context and from looking at the BBC receiver program, the missing subroutine at $C075 should do the following:

- store the byte in register A into the byte pointed to by zeropage[$FD]:zeropage[$FC]
- increment the pointer zeropage[$FD]:zeropage[$FC]
- return, with the read byte still in register A

# Example of completed receiver program by nc513

For an example of a complete receiver program for the C64, see the file `C000_C64REC_nc513.prg`. This program was posted
to the lemon64 thread by user nc513 on Aug 8, 2024, independent from my reverse engineering. It contains the following
additions to the originally published C64 receiver program:

- (at $C07D) the subroutine for storing the received byte and incrementing the running pointer (zeropage[$FD]:zeropage[$FC]),
- (at $C043) after having received the end of the transmission and before exiting, the program sets the `VARTAB` pointer (zeropage[$2E]:zeropage[$$2D]) to the first byte beyond the received program code.

See `c64_receiver_program_by_nc513_disassembly.txt` for an (uncommented) disassembly of this program.

Note: I am not sure whether setting `VARTAB` suffices for establishing a valid BASIC interpreter state after
downloading the transmitted program.

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

# Preparing the interlaced master tape video for correct playback

The digitized master tapes have very nice picture quality and they have properly interlaced fields, so they provide a PAL field
every 20 ms, which is critical for the reception to work. However, I could not make the VideoLAN player (VLC media player) to
play back these interlaced fields correctly on a 50 Hz HDMI output. I therefore resorted to extracting the individual fields and
then re-encoding them to a progressive 50 Hz video using `ffmpeg`. There is probably a more elegant way to do this without the intermediate step but the following worked for me.

The commands for extracting the fields are:

    mkdir frames

    ffmpeg -i "Four Computer Buffs S01E05 VT32757 © Fremantle.mp4" \
        -ss 00:04:00 -t 00:05:30 \
        -filter_complex "[0]field=top[t];[0]field=bottom[b];[t][b]interleave" \
        -r 50 \
        frames/field%05d.png

When this has completed, you should have all the fields as individual image files in the "frames" directory.

The command for re-encoding the fields is:

    ffmpeg -framerate 50 -i frames/field%05d.png \
        -c:v libx264 -pix_fmt yuv420p \
        transmission.mp4

The resulting video `transmission.mp4` is a 50 Hz progressive video with all the information needed for the reception to work.

Note: These commands were run on a Linux system. For windows, the backslashes for line continuation need to be changed to carets (`^`)
if you put these commands in a Windows batch file (alternately, just put each command on a single line). I'm not sure whether
anything about the double quotes needs to be changed for Windows.

# Credits

I learned about this fascinating story through Perifractic's wonderful YouTube recipode (https://www.youtube.com/watch?v=MezkfYTN6EQ).

The program `C000_C64REC_nc513.prg` was independently assembled and uploaded to lemon64 by user nc513. See the thread https://www.lemon64.com/forum/viewtopic.php?p=1027686 on Aug 8, 2024.

For disassembling, I used "Infiltrator Disassembler" by Gerald Hinder (https://csdb.dk/release/?id=100129).

For assembling the "TUNETEST" program, I used TMPx v1.1.0 released by style64.org ("Turbo Assembler" originally from Wolfram Roemhild): https://turbo.style64.org/

For making disk images, I used "DirMaster 3.1.5/Style" by The Wiz and Elwix: https://style64.org/dirmaster

