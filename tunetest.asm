           * = $C000
            
           ; --- position of the dot ------------------

           xpos = 32
           ypos = 22
           screen = $0400
           screenpos = screen + (40 * ypos) + xpos
           colorram = $D800
           colorpos = colorram + (40 * ypos) + xpos

           colorramOffset = colorram - screen

           ; --- raster lines -------------------------

           ; 10 ms are 156.25 raster lines
           ; 20 ms are 312.50 raster lines
           ;
           ; With ypos = 22, the dot starts on raster line
           ; 227. Raster line 71 is about 10 ms before that.

           rasterStartVisible = 51

           rasterSample       = 71    ; when to sample the data line and update the frame
           rasterDot          = rasterStartVisible + (8 * ypos)
           rasterTarget       = (rasterDot + 10)
           rasterBarStart     = (rasterTarget - 14)
           rasterBarEnd       = (rasterTarget + 14)

           ; --- other screen positions ---------------

           yFirstSequence = 9
           xSequenceMarker = 2

           screenposFirstSequenceMarker = screen + (40 * yFirstSequence) + xSequenceMarker
            
           yData = 16

           screenposDataStart = screen + (40 * yData)
           screenposDataEnd   = screenposDataStart + (3 * 40)

           ; --- control characters -------------------

           ctrlWhite      = $05
           ctrlNewline    = $0D
           ctrlDown       = $11
           ctrlReverseOn  = $12
           ctrlHome       = $13
           ctrlRed        = $1C
           ctrlGreen      = $1E
           ctrlBlue       = $1F
           ctrlOrange     = $81
           ctrlBlack      = $90
           ctrlReverseOff = $92
           ctrlClear      = $93
           ctrlBrown      = $95
           ctrlLightRed   = $96
           ctrlDarkGrey   = $97
           ctrlMediumGrey = $98
           ctrlLightGreen = $99
           ctrlLightBlue  = $9A
           ctrlLightGrey  = $9B
           ctrlPurple     = $9C
           ctrlYellow     = $9E
           ctrlCyan       = $9F

           ; --- poke colors --------------------------

           pokeBlack      = $00
           pokeRed        = $02
           pokeBlue       = $06
           pokeYellow     = $07
           pokeLightRed   = $0A
           pokeDarkGrey   = $0C
           pokeLightBlue  = $0E

           ; --- key codes ----------------------------

           keyRunStop     = $03
           keyF5          = $87
           keyF7          = $88
           
           ; --- kernal vectors -----------------------
           
           outch          = $FFD2
           readkey        = $FFE4
           kernalIrq      = $EA31 ; standard IRQ handler
           kernalIrqRet   = $EA81 ; return from IRQ

           ; --- zeropage allocations for variables ---
           
           zpCurrentByte       = $02
           zpExpectedBit       = $07
           zpMainLo            = $0B ; for use by the main program
           zpMainHi            = $0C ; for use by the main program
           zpSampleLo          = $14 ; running pointer for sampling IRQ
           zpSampleHi          = $15 ; running pointer for sampling IRQ
           zpAvailableBits     = $FB
           zpSequenceIndex     = $FC
           zpTempLo            = $FC ; use only during initialization
           zpNextBytePointerLo = $FD
           zpTempHi            = $FD ; use only during initialization
           zpNextBytePointerHi = $FE
           zpRemainingBitsLo   = $43
           zpRemainingBitsHi   = $44

           ; --- interrupt vectors --------------------

           vecIrq              = $0314

           ; --- VIC registers ------------------------

           vicControl          = $D011
           vicRaster           = $D012
           vicIrqFlag          = $D019
           vicIrqMask          = $D01A
           vicBorder           = $D020
           vicBackground       = $D021

           ; --- CIA registers ------------------------

           ciaIntCtrl1         = $DC0D ; interrupt control

           ciaDataB2           = $DD01 ; data, port B
           ciaDataDirB2        = $DD03 ; data direction, port B
           ciaIntCtrl2         = $DD0D ; interrupt control

           ; --- initialize the program ---
           
Init       LDA #0
           STA vicBorder        ; border color: black
           STA vicBackground    ; background color: black
           STA ciaDataDirB2     ; all port B bits are inputs
         
           LDA #ctrlClear       ; clear the screen
           JSR outch

           LDX #<Usage          ; print the usage message
           LDY #>Usage
           JSR PrintStr

           LDA #<screenposDataStart  ; set up screen pointer for sampling
           STA zpSampleLo
           LDA #>screenposDataStart
           STA zpSampleHi

           LDA #$FF
           STA zpExpectedBit    ; no expected bit, yet

           LDA #0               ; start sequence 0
           STA zpSequenceIndex
           JSR StartSeq
           
           SEI                  ; set interrupt bit, make the CPU ignore interrupt requests

           LDA #%01111111       ; switch off interrupt signals from CIA-1
           STA ciaIntCtrl1

           AND vicControl       ; clear most significant bit of VIC's raster register
           STA vicControl

           STA ciaIntCtrl1      ; acknowledge pending interrupts from CIA-1
           STA ciaIntCtrl2      ; acknowledge pending interrupts from CIA-2

           LDA #rasterSample    ; set rasterline where interrupt shall occur
           STA vicRaster

           LDA #<Irq            ; set interrupt vectors, pointing to interrupt service routine below
           STA vecIrq
           LDA #>Irq
           STA vecIrq + 1

           LDA #%00000001       ; enable raster interrupt signals from VIC
           STA vicIrqMask

           JMP HaveSeq          ; start the first sequence and enable interrupts

           ; --- main loop ---

MainLoop   JSR readkey
           BEQ MainLoop         ; no key? -> repeat

           CMP #keyRunStop      ; has RUN/STOP been pressed?
           BEQ Exit             ; if yes, then exit

           CMP #keyF5
           BEQ PrevSeq

           CMP #keyF7
           BEQ NextSeq

           JMP MainLoop

           ; switch to prev sequence
PrevSeq    SEI                  ; suspend interrupts
           DEC zpSequenceIndex
           BMI LastSeq
           JMP HaveSeq

           ; switch to next sequence
NextSeq    SEI                  ; suspend interrupts
           INC zpSequenceIndex
           LDA zpSequenceIndex
           CMP #nSequences
           BNE HaveSeq

FirstSeq   LDA #0
           STA zpSequenceIndex
           JMP HaveSeq

LastSeq    LDA #(nSequences - 1)
           STA zpSequenceIndex

HaveSeq    JSR StartSeq
           CLI     ; enable interrupts again

           ; --- mark the currently selected sequence

           LDA #<screenposFirstSequenceMarker
           STA zpMainLo
           LDA #>screenposFirstSequenceMarker
           STA zpMainHi

           LDX #0
MarkLoop   CPX zpSequenceIndex
           BEQ MarkThis
           LDA #$20 ; ' '
           JMP MarkOther
MarkThis   LDA #$3E ; '>'
MarkOther  LDY #0
           STA (zpMainLo),Y

           CLC
           LDA zpMainLo
           ADC #40
           STA zpMainLo
           LDA zpMainHi
           ADC #0
           STA zpMainHi

           INX
           CPX #nSequences
           BEQ MainLoop
           JMP MarkLoop

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

           ; --- raster interrupt, once per frame for sampling and updating the dot ----
           
Irq        LDA ciaDataB2        ; sample the data line
           ASL A
           LDA #$30             ; '0'
           ADC #0               ; set A to '0' or '1', depending on what we sampled
           LDY #0
           STA (zpSampleLo),Y

           ; compare with expected bit
           SEC
           SBC #$30             ; convert back to numerical 0 or 1
           CMP zpExpectedBit
           BEQ Same
           LDA #$FF
           CMP zpExpectedBit
           BEQ NoExpected
           LDA #pokeLightRed
           JMP DoneComp
Same       LDA #pokeLightBlue
           JMP DoneComp
NoExpected LDA #pokeDarkGrey

           ; write color to color ram
DoneComp   PHA
           CLC
           LDA zpSampleLo
           ADC #<colorramOffset
           STA zpSampleLo
           LDA zpSampleHi
           ADC #>colorramOffset
           STA zpSampleHi
           PLA
           STA (zpSampleLo),Y
           SEC
           LDA zpSampleLo
           SBC #<colorramOffset
           STA zpSampleLo
           LDA zpSampleHi
           SBC #>colorramOffset
           STA zpSampleHi

           ; increase output position for sampled data
           INC zpSampleLo
           BNE IncDone
           INC zpSampleHi

           ; check whether we need to wrap the output position around
IncDone    LDA zpSampleLo
           CMP #<screenposDataEnd
           BNE NotEnd
           LDA zpSampleHi
           CMP #>screenposDataEnd
           BNE NotEnd

           ; reset to the beginning of the output area
           LDA #<screenposDataStart
           STA zpSampleLo
           LDA #>screenposDataStart
           STA zpSampleHi

           ; write a space after the most recent bit
NotEnd     LDA #$20             ; ' '
           STA (zpSampleLo),Y

           ; update the dot
           JSR NextBit
           STA zpExpectedBit
           CMP #0
           BEQ ClearIt
SetIt      LDA #81
           STA screenpos
           JMP Done
ClearIt    LDA #32
           STA screenpos
Done       LDA #1
           STA colorpos

           ; check whether we are in the tuning sequence
           ; and wether we are expecting a high-to-low
           ; transition
           LDA zpSequenceIndex
           BNE AckIrq
           LDA zpExpectedBit
           BNE AckIrq

           ; we are in the tuning sequence and we expect
           ; a high-to-low transition.
           ; set up the tuning-specific raster IRQ handler

           LDA #rasterBarStart
           STA vicRaster
           LDA #<TuneIrq 
           STA vecIrq
           LDA #>TuneIrq
           STA vecIrq + 1

AckIrq     ASL vicIrqFlag       ; acknowledge the interrupt by clearing the VIC's interrupt flag
           JMP kernalIrq        ; jump into KERNAL's standard interrupt service routine to handle keyboard scan, cursor display etc.

           ; --- raster interrupt for tuning --------------------------

TuneIrq    LDA vicRaster
           CLC
           ADC #2
           CMP #rasterBarEnd
           BPL BarEnd

           STA vicRaster        ; set up tuning raster interrupt for the next line

           ; color the border depending on the state of the data line
           LDA ciaDataB2
           ASL A
           BCS DataHi
           LDA #pokeBlue
           JMP DataDone
DataHi     LDA #pokeYellow
DataDone   STA vicBorder
           JMP AckIrqRet

           ; end of tuning bar; switch back to black border
           ; and the sampling IRQ
BarEnd     LDA #pokeBlack
           STA vicBorder
           
           ; set up the sample IRQ
           LDA #rasterSample
           STA vicRaster
           LDA #<Irq
           STA vecIrq
           LDA #>Irq
           STA vecIrq + 1

AckIrqRet  ASL vicIrqFlag       ; acknowledge the interrupt by clearing the VIC's interrupt flag
           JMP kernalIrqRet     ; jump into KERNAL code for returning from IRQ handler

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
           
           ; number of sequences
           nSequences = 6

           ; list of sequences, 4 bytes per sequence
Sequences  .word  2, seqAlt
           .word 50, seq1Hz
           .word  1, seqOff
           .word  1, seqOn
           .word 14, seqVary0
           .word 14, seqVary1

seq1Hz     .byte $01, $00, $00, $00, $00, $00, $00
seqOn      .byte $01
seqOff     .byte $00
seqAlt     .byte $01
seqVary0   .byte %00100101, %00000010
seqVary1   .byte %11011010, %00111101

           ; --- strings ----------------------------------------------
           
Usage      .byte ctrlClear, ctrlWhite
           .text "       == c64 light fantastic ==        "
           .text "          tune & test program           "
           .byte ctrlNewline
           .byte ctrlNewline, ctrlLightGrey
           .text "* press "
           .byte ctrlReverseOn, ctrlRed
           .text "run/stop"
           .byte ctrlReverseOff, ctrlLightGrey
           .text " to quit."
           .byte ctrlNewline
           .byte ctrlNewline
           .text "* press "
           .byte ctrlWhite
           .text "f5"
           .byte ctrlLightGrey
           .text " / "
           .byte ctrlWhite
           .text "f7"
           .byte ctrlLightGrey
           .text " to cycle through  the   "
           .text "  test sequences."
           .byte ctrlNewline
           .byte ctrlNewline
           .text "  "
           .byte ctrlYellow
           .text " "
           .byte ctrlLightGrey
           .text " tuning (alternating on/off)"
           .byte ctrlNewline
           .text "  "
           .byte ctrlCyan
           .text " "
           .byte ctrlLightGrey
           .text " 1hz blinking"
           .byte ctrlNewline
           .text "  "
           .byte ctrlCyan
           .text " "
           .byte ctrlLightGrey
           .text " always off"
           .byte ctrlNewline
           .text "  "
           .byte ctrlCyan
           .text " "
           .byte ctrlLightGrey
           .text " always on"
           .byte ctrlNewline
           .text "  "
           .byte ctrlCyan
           .text " "
           .byte ctrlLightGrey
           .text " varying off time"
           .byte ctrlNewline
           .text "  "
           .byte ctrlCyan
           .text " "
           .byte ctrlLightGrey
           .text " varying on time"
           .byte ctrlNewline
           .byte ctrlNewline
           .byte ctrlNewline
           .byte ctrlNewline
           .byte ctrlNewline
           .byte ctrlNewline
           .text "when tuning, adjust r6 such"
           .byte ctrlNewline
           .text "that "
           .byte ctrlReverseOn, ctrlYellow
           .text "yellow"
           .byte ctrlReverseOff, ctrlLightGrey
           .text " and "
           .byte ctrlReverseOn, ctrlBlue
           .text "blue"
           .byte ctrlReverseOff, ctrlLightGrey, ctrlNewline
           .text "borders have the same size."
           .byte ctrlNewline
           .text "only "
           .byte ctrlReverseOn, ctrlBlue
           .text "blue  "
           .byte ctrlReverseOff, ctrlLightGrey
           .text ": increase r6"
           .byte ctrlNewline
           .text "only "
           .byte ctrlReverseOn, ctrlYellow
           .text "yellow"
           .byte ctrlReverseOff, ctrlLightGrey
           .text ": decrease r6"
           .byte 0
