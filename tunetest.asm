           * = $C000
            
           xpos = 36
           ypos = 22
           screen = $0400
           screenpos = screen + (40 * ypos) + xpos
           colorram = $D800
           colorpos = colorram + (40 * ypos) + xpos
            
           ; --- control characters -------------------

           ctrlWhite      = $05
           ctrlNewline    = $0D
           ctrlDown       = $11
           ctrlReverseOn  = $12
           ctrlHome       = $13
           ctrlRed        = $1C
           ctrlReverseOff = $92
           ctrlClear      = $93
           
           ; --- kernal vectors -----------------------
           
           outch = $FFD2
           readkey = $FFE4

           ; --- zeropage allocations for variables ---
           
           zpCurrentByte       = $02
           zpAvailableBits     = $FB
           zpSequenceIndex     = $FC
           zpTempLo            = $FC
           zpNextBytePointerLo = $FD
           zpTempHi            = $FD
           zpNextBytePointerHi = $FE
           zpRemainingBitsLo   = $43
           zpRemainingBitsHi   = $44

           ; --- initialize the program ---
           
Init       LDA #0
           STA $D020            ; border color: black
           STA $D021            ; background color: black
         
           LDA #ctrlClear
           JSR outch

           LDX #<Usage
           LDY #>Usage
           JSR PrintStr

           LDA #0               ; start sequence 0
           STA zpSequenceIndex
           JSR StartSeq
           
           SEI                  ; set interrupt bit, make the CPU ignore interrupt requests
           LDA #%01111111       ; switch off interrupt signals from CIA-1
           STA $DC0D

           AND $D011            ; clear most significant bit of VIC's raster register
           STA $D011

           STA $DC0D            ; acknowledge pending interrupts from CIA-1
           STA $DD0D            ; acknowledge pending interrupts from CIA-2

           LDA #100             ; set rasterline where interrupt shall occur
           STA $D012

           LDA #<Irq            ; set interrupt vectors, pointing to interrupt service routine below
           STA $0314
           LDA #>Irq
           STA $0315

           LDA #%00000001       ; enable raster interrupt signals from VIC
           STA $D01A

           CLI                  ; clear interrupt flag, allowing the CPU to respond to interrupt requests

           ; --- main loop ---
MainLoop   JSR readkey
           BEQ MainLoop

           CMP #$03             ; has RUN/STOP been pressed?
           BEQ Exit             ; if yes, then exit

           ; switch to the next sequence
           SEI                  ; suspend interrupts
           INC zpSequenceIndex
           JSR StartSeq
           ; check if we have reached the end of the sequence list
           LDA zpRemainingBitsLo
           BNE HaveSeq
           LDA zpRemainingBitsHi
           BNE HaveSeq

           ; we have reached the end of the list, start from the beginning
           LDA #0
           STA zpSequenceIndex
           JSR StartSeq

HaveSeq    CLI     ; enable interrupts again
           JMP MainLoop

Exit       RTS

           ; --- start a sequence (sequence index given in zpSequenceIndex)

StartSeq   LDA zpSequenceIndex      ; multiply sequence index by 4
           ASL A
           ASL A
           CLC
           ADC #<Sequences          ; add to address of Sequences
           STA zpNextBytePointerLo  ; use next byte pointer temporarily to store the address
           LDA #0
           ADC #>Sequences
           STA zpNextBytePointerHi

           ; load and store the number of bits in the sequence
           LDY #0
           LDA (zpNextBytePointerLo),Y
           STA zpRemainingBitsLo
           LDY #1
           LDA (zpNextBytePointerLo),Y
           STA zpRemainingBitsHi

           ; load and store the pointer to the sequence data

           LDY #2
           LDA (zpNextBytePointerLo),Y
           PHA
           LDY #3
           LDA (zpNextBytePointerLo),Y
           STA zpNextBytePointerHi
           PLA
           STA zpNextBytePointerLo

           ; clear zpAvailableBits
           LDA #0
           STA zpAvailableBits

           RTS

           ; --- get the next bit in the sequence (return it in A)

           ; check whether we have available bits in zpCurrentByte
NextBit    LDA zpAvailableBits
           BNE HaveBit 

           ; --- no; we must load a byte from the sequence data

           ; check whether we have remaining bits in the sequence
           ; (and therefore at least one byte remaining in the
           ; sequence data)
           LDA zpRemainingBitsHi
           BNE HaveByte
           LDA zpRemainingBitsLo
           BNE HaveByte

           ; --- no; we must restart the sequence

           JSR StartSeq

           ; --- there is at least one bit in the sequence remaining,
           ;     so there is at least one more byte to load from the
           ;     sequence data

           ; --- load the next byte from the sequence data,
           ;     store it in zpCurrentByte, and update pointers
           ;     and counters

HaveByte   LDY #0
           LDA (zpNextBytePointerLo),Y
           STA zpCurrentByte

           ; increase the next-byte-pointer
           INC zpNextBytePointerLo
           BNE PtrDone
           INC zpNextBytePointerHi

PtrDone    LDA zpRemainingBitsHi   ; check if at least 8 bits are remaining
           BNE Have8
           LDA zpRemainingBitsLo
           CMP #8
           BPL Have8

           ; we have less than 8 bits left (their number is in A)
           STA zpAvailableBits
           LDA #0
           STA zpRemainingBitsLo ; clear number of remaining bits
           STA zpRemainingBitsHi
           JMP HaveBit 

           ; --- we have at least 8 bits remaining

Have8      LDA #8
           STA zpAvailableBits
           ; decrement the remaining bits counter by 8
           LDA zpRemainingBitsLo
           SEC
           SBC #8
           STA zpRemainingBitsLo
           LDA zpRemainingBitsHi
           SBC #0
           STA zpRemainingBitsHi

           ; --- we have at least one bit available in zpCurrentByte

HaveBit    LDA zpCurrentByte ; shift the LSB out of zpCurrentByte
           LSR
           STA zpCurrentByte
           LDA #0            ; and store it (the LSB) on the stack
           ADC #0
           PHA

           ; decrement zpAvailableBits
           DEC zpAvailableBits

           PLA               ; restore the LSB from the stack
           RTS

           ; --- raster interrupt ----
           
Irq        JSR NextBit
           CMP #0
           BEQ ClearIt
SetIt      LDA #81
           STA screenpos
           JMP Done
ClearIt    LDA #32
           STA screenpos
Done       LDA #1
           STA colorpos
           
           ASL $D019            ; acknowledge the interrupt by clearing the VIC's interrupt flag

           JMP $EA31            ; jump into KERNAL's standard interrupt service routine to handle keyboard scan, cursor display etc.

           ; --- print string (pointer to string is in Y:X) -----------

PrintStr   STX zpTempLo
           STY zpTempHi

PrintLoop  LDY #0
           LDA (zpTempLo),Y     ; A <- byte at zeropage[zpTempHi]:zeropage[zpTempLo]
           BEQ EndStr
           JSR outch
           INC zpTempLo
           BNE PrintLoop
           INC zpTempHi
           JMP PrintLoop
           
EndStr     RTS 

           ; --- sequence definitions ---------------------------------
           
           ; list of sequences, 4 bytes per sequence, terminated by 4 zero bytes
Sequences  .word 50, seq1Hz
           .word  1, seqOn
           .word  1, seqOff
           .word  2, seqAlt
           .word 14, seqVary0
           .word 14, seqVary1
           .word  0, 0

seq1Hz     .byte $01, $00, $00, $00, $00, $00, $00
seqOn      .byte $01
seqOff     .byte $00
seqAlt     .byte $01
seqVary0   .byte %00100101, %00000010
seqVary1   .byte %11011010, %00111101

           ; --- strings ----------------------------------------------
           
Usage      .byte ctrlClear, ctrlWhite
           .text "       == c64 light fantastic ==        "
           .text "         test signal generator          "
           .byte ctrlNewline
           .byte ctrlNewline
           .text "* press "
           .byte ctrlReverseOn, ctrlRed
           .text "run/stop"
           .byte ctrlReverseOff, ctrlWhite
           .text " to quit."
           .byte ctrlNewline
           .byte ctrlNewline
           .text "* press any other key to cycle through  "
           .text "  the test sequences."
           .byte ctrlNewline, 0

