org #3300

        NR_REGISTERS_TO_DECRUNCH        equ #0C

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                                                               ;;
;;                                             MACROS                                            ;;
;;                                                                                               ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;
; Waste time using as few bytes as possible.
;
MACRO   SKIP_NOPS	Nops
        if      {Nops}	== 2
                cp	(hl)    ; WASTE TIME WITH FEW BYTES (2 NOPS - 1 BYTE)
        else
                if	{Nops}	== 3
                        jr	$+2     ; Add hl, RR    ; inc (hl)      ; pop hl
                else
                        if	{Nops}	== 5
                                cp	a, (ix) ; WASTE TIME WITH FEW BYTES (5 NOPS - 3 BYTES)
                        else
                                if	{Nops}	== 6
                                        inc	(hl)    ; WASTE TIME WITH FEW BYTES (3 NOPS - 1 BYTE)
                                        dec	(hl)    ; WASTE TIME WITH FEW BYTES (3 NOPS - 1 BYTE)
                                else
                                        if	{Nops}	== 7
                                                inc	(hl)    ; WASTE TIME WITH FEW BYTES (3 NOPS - 1 BYTE)
                                                nop
                                                dec	(hl)    ; WASTE TIME WITH FEW BYTES (3 NOPS - 1 BYTE)
                                        else
                                                if      {Nops}	== 8
                                                        inc	(hl)    ; WASTE TIME WITH FEW BYTES (3 NOPS - 1 BYTE)
                                                        cp      (hl)
                                                        dec	(hl)    ; WASTE TIME WITH FEW BYTES (3 NOPS - 1 BYTE)
                                                endif
                                        endif
                                endif
                        endif
                endif
        endif
MEND

;
; Update the number of remaining "copy slots" from the number of bytes to process in the next copy operation.
;
MACRO   _UpdateNrCopySlot               ; 4 NOPS
        ld	b, a
        ld	a, c
        sub	b
        ld	c, a
MEND

;
; Adjust the number of bytes to process in the next copy operation, regarding the remaining "copy slots".
;
MACRO   _AdjustCopySizeWithRemainingSlots         ; 2 NOPS
        sub	c
        ld	b, a
MEND

;
; Compute the source address of data in the dictionary
;
MACRO   _ComputeCopyFromDictSourceAddr   ; 4 NOPS
        ld	a, d
        sub	l
        cpl
        ld	e, a
        ld	d, h
MEND

;
; Copy string from dictionary
;
MACRO   _CopyFromDictLoop	LoopReg ; 10 * N NOPS - 1
@CopyLoop:
        ld	a, (de)     
        ld	(hl), a
        inc	l
        inc	e
        SKIP_NOPS 2
        dec	{LoopReg}
        jr	nz, @CopyLoop
MEND

;
; Copy literals from crunched data.
;

MACRO   _CopyLiteralLoop   LoopReg ; 2 + 10 * N NOPS
@CopyLoop:
        ld      (hl), d
        inc	l
        SKIP_NOPS 5
        dec     {LoopReg}
        jr      nz, @ContinueLoop
        jr      @ExitLoop
@ContinueLoop:
        pop     de
        ld      (hl), e
        inc	l
        SKIP_NOPS 2
        dec     {LoopReg}
        jr	nz, @CopyLoop
        nop
        dec     sp
@ExitLoop:
MEND

        ;
        ; Write a value in a PSG register
        ;
MACRO   WriteToPSGReg	RegNumber       ; 25 NOPS
        out	(c), {RegNumber}
        dec	c              ; Dec number of registers to play

        exx
        out	(c), 0
        exx

        out	(c), a

        exx
        out	(c), c
        out	(c), b
        exx
MEND

MACRO   WriteToPSGRegSkip	RegNumber, SkipVal
        ld	a, (hl)
        cp	{SkipVal}
        jr	z, @Skip

        WriteToPSGReg {RegNumber}
@Skip:
MEND

MACRO   Write8ToPlayerCodeWithReloc	Offset, Value
        ld	hl, {Offset} - RelocBase
        add	hl, bc
        ld	(hl), {Value}
MEND

MACRO   WriteHLToPlayerCodeWithReloc	Offset
        ld	iy, {Offset} - RelocBase
        add	iy, bc
        ld	(iy + 0), l
        ld	(iy + 1), h
MEND

RelocBase:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                                                               ;;
;;                                       MAIN PLAYER CODE                                        ;;
;;                                                                                               ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;
        ;;       AY programming
        ;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

CurrentPlayerBufferLow = $+1
CurrentPlayerBufferHigh = $+2
        ld	hl, #0000
        ld	a, l
        inc	a
Reloc1 = $+1
        ld	(CurrentPlayerBufferLow), a
        exx
        ld	bc, #C680
        exx
NrRegistersToPlay = $+1
        ld	bc, #F400       ; Max number of registers to play is written in the C register by the init code.
        ld	de, #0201

        ;
        ; Write to register 0
        ;
        WriteToPSGRegSkip	0, e
        inc	h

        ;
        ; Write to register 2
        ;
        WriteToPSGRegSkip       d, e
        inc	h

        ;
        ; Write to register 1
        ;
        inc     d
        ld	a, (hl)
        dec     l
        cp	(hl)
Reloc2 = $+1
        jp	z, SkipR1_3
        WriteToPSGReg   e

        ;
        ; Write to register 3
        ;
        rra
        rra
        rra
        rra
        WriteToPSGReg	d
SkipR1_3Return:
        inc     l
        inc	h

        ;
        ; Write to register 4
        ;
        inc	d
        WriteToPSGRegSkip	d, e
        inc	h

        ;
        ; Write to register 5
        ;
        inc     d
        ld	a, (hl)
        inc     h
        bit	5, (hl)                 ; Check if we have to program register 5.
        jr	nz, SkipR5
        WriteToPSGReg	d
SkipR5:

        ;
        ; Write to register 13
        ;
        rra
        rra
        rra
        rra
        bit	6, (hl)                 ; Check if we have to program register 13.
        ld	e, 13
        jr	nz, SkipRegister13
        WriteToPSGReg	e
SkipRegister13

        ;
        ; Write to register 6
        ;
        inc	d
        ld	a, (hl)
        bit	7, a
        jr	nz, SkipRegister6      
        WriteToPSGReg	d
SkipRegister6:
        inc	h

        ;
        ; Write to register 7
        ;
        inc	d
        WriteToPSGRegSkip	d, b
        inc     h

        ;
        ; Write to register 8
        ;
        inc	d
        WriteToPSGRegSkip	d, b
        inc	h

        ;
        ; Write to register 9
        ;
        inc	d
        WriteToPSGRegSkip	d, b
        inc	h

        ;
        ; Write to register 10
        ;
        inc	d
        WriteToPSGRegSkip	d, b
        inc	h
        
        ;
        ; Write to register 11
        ;
        inc	d
        WriteToPSGRegSkip	d, 1

SkipR12OverwriteJR:
        ; Playing R12 is very uncommon. No effort has been made to make this case efficient.
        jr      PlayR12Trampoline

ReturnFromPlayR12:
        jr	z, SkipDecrunchTrampoline2
Reloc3 = $+1
        ld	(NrValuesToDecrunch), a

        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;
        ;;      Decrunch buffers start
        ;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        ex	de, hl  ; Protect HL from next modification

        ;
        ; Move to the next decrunch buffer and handle buffer loop.
        ;
DecrunchEntryPoint:
ReLoadDecrunchSavedState  equ	$ + 1
ReLoadDecrunchSavedStatehigh  equ	$ + 2
        ld	hl, #0000
        ld	a, l
DecrunchStateLoopValue = $+1
        cp	0       ; The loop value is written here by the init code.
        jr	nz, SkipBufferReset
        xor	a
SkipBufferReset:
        ld	l, a
        ld	sp, hl
        ld	a, e    ; Backup current position of the player in the decrunched buffer
        pop	de      ; d = restart if not null       e = Lower byte of source address if restart copy from windows. Undef otherwise.
        pop	bc      ; Current position in decrunch buffer (B=low address byte / C = High address byte)
        pop	hl      ; Current position in crunched data buffer
Reloc4 = $+2
        ld	(ReLoadDecrunchSavedState), sp
        sub	b       ; Compute distance between player read position and current position in decrunch buffer.
        cp	28      ; Leave a security gap between the current decrunch position and the player position.
        jr	c, SkipDecrunchTrampoline
        
        ld	a, h
        res	7, h
        ld	sp, hl          ; Load current position in decrunch buffer

        ld	h, c
        ld	l, b

        ; SP = current position in decrunch source buffer
        ; HL = current position in decrunch destination buffer
        ; DE = 
        ; BC = B: C: number of values to decrunch
        ; ly = number of markers decoded

        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;
        ;;      Decrunch buffers start
        ;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

NrValuesToDecrunch = $+1
        ld	c, 220
NrDecrunchLoop = $+2
        ld	ly, 50
        inc	d
        dec	d
        jr	nz, RestartPausedDecrunch

        ;
        ; Load a new marker
        ;
FetchNewCrunchMarker:
        pop	de

        ld	a, #1F
        cp      e

        jr	nc, CopyLiteral         ; A < 1F --> Copy literals
                                        ; A > 1F --> Copy from dictionnary

        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;
        ;;      Copy from dictionnary
        ;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

CopyFromDict:
        ld	a, e
        sub	#1d
        cp	c
        jr	nc, CopySubStringFromDict

        _UpdateNrCopySlot	(void)                  ; 4 NOPS
        _ComputeCopyFromDictSourceAddr	(void)          ; 5 NOPS

RestartCopyFromDict:
        _CopyFromDictLoop	b                       ; 10 * N - 1 NOPS       - MOD: A, DE, HL + B

        dec	ly
        jr	nz, FetchNewCrunchMarker
Reloc5 = $+1
        jp      ExitMainDecrunchLoop

SkipDecrunchTrampoline2:
        ld	a, 15
Reloc6 = $+1
        jp	SkipDecrunchLoop

SkipDecrunchTrampoline:
Reloc7 = $+1
        jp      SkipDecrunch

PlayR12Trampoline:
Reloc8 = $+1
        jp	PlayR12
        
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;
        ;;      Copy Literal
        ;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

CopyLiteral:
        jr	z, DoFramesLoop
        ld	a, e
        inc	a
        
RestartCopyLiteral:
        cp	c
        jr	nc, CopySubLiteralChain

        _UpdateNrCopySlot	(void)          ; 4 NOPS
        _CopyLiteralLoop	b               ; 2 + 10 * N NOPS

        dec	ly
        jr	nz, FetchNewCrunchMarker
        jr      ExitMainDecrunchLoop

        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;
        ;;      Continue paused Decrunch
        ;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

RestartPausedDecrunch:
        rla
        jr	nc, RestartPausedCopyFromDict

        ;
        ; Restart Copy Literal
        ;
        ld	a, d
        dec	sp
        pop	de
        jr	RestartCopyLiteral

RestartPausedCopyFromDict:
        SKIP_NOPS 5

        ld	a, d
        cp	c
        ld	d, h
        jr	nc, RestartSubCopyFromDict
        nop

        _UpdateNrCopySlot	(void)          ; 4 NOPS
        jr	RestartCopyFromDict
RestartSubCopyFromDict:
        _AdjustCopySizeWithRemainingSlots	(void)
        nop
        jr	RestartCopySubStringFromDict      

        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;
        ;;      Do Frames loop
        ;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        
DoFramesLoop:
        dec     sp
        exx
        pop	hl
DataBufferReset = $+1
        ld	bc, #0000
        add	hl, bc
        ld	sp, hl
        exx
        nop
        dec	c
        ld	d, c
        jr	z, DecrunchFinalize

        SKIP_NOPS 2

        dec	ly
Reloc9 = $+1
        jp	nz, FetchNewCrunchMarker
        jr      ExitMainDecrunchLoop2

        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;
        ;;      Copy sub string and jump to decrunch finalize
        ;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        ;
        ;       Copy from dictionnary
        ;
CopySubStringFromDict:
        _AdjustCopySizeWithRemainingSlots	(void)        ; 2 NOPS
        _ComputeCopyFromDictSourceAddr	(void)                ; 4 (+1) NOPS

RestartCopySubStringFromDict:
        _CopyFromDictLoop	c                             ; 12 * N NOPS        
        ld	d, b
        ld	a, c

        dec     ly
        jr	z, SaveDecrunchState
        jr      EnterStabilizeLoop

        ;
        ; We have more literal to copy than available copy slots
        ;
CopySubLiteralChain:
        sub     c
        _CopyLiteralLoop	c
        ld	d, a

DecrunchFinalize:
        ld	a, #80

        ;
        ; Decrunch stabilization loop
        ;
        dec     ly
StabilizeLoop:
        jr	z, SaveDecrunchState

        SKIP_NOPS 3
EnterStabilizeLoop:
        ld	b, 4
        djnz    $

        dec	ly
        jr	StabilizeLoop

ExitMainDecrunchLoop:
        nop
ExitMainDecrunchLoop2:
        xor	a
        ld	d, a
        SKIP_NOPS 5
        dec	c
        jr	nz, ExitMainDecrunchLoop

        ;
        ; Write back to memory the current decrunch state.
        ;
SaveDecrunchState:
        ld	b, l    ; Dirty trick!!! BC = LH (backup for latter push) while setting HL to AC.
        ld	l, c
        ld	c, h
        ld	h, a
        add	hl, sp
Reloc10 = $+2
        ld	sp, (ReLoadDecrunchSavedState)
        push	hl      ; Save current position in crunched data buffer
        push	bc      ; Save current position in decrunch buffer
        push	de
DecrunchFinalCode:

        ;
        ; Return to the calling code.
        ;
ReturnAddress = $+1
        jp	#0000

SkipR1_3:
        SKIP_NOPS	3
Reloc11 = $+1
        jp      SkipR1_3Return
        
SkipDecrunch:
Reloc12 = $+1
        ld	a, (NrValuesToDecrunch)
        add	a, 11
        SKIP_NOPS 6
SkipDecrunchLoop:
        SKIP_NOPS 8
        dec	a
        jr	nz, SkipDecrunchLoop
        jr      DecrunchFinalCode

PlayR12:
        ;
        ; Write to register 12
        ;
        inc	h
        inc	d
        ld	a, (hl)
        dec     l
        cp	(hl)
        jr	z, SkipRegister12
        WriteToPSGReg	d
SkipRegister12:
        dec     l
        ld	a, c
        add	a, a
Reloc9 = $+1
        jp	ReturnFromPlayR12

        print	"Player size: ", $-#3300



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                                                               ;;
;;                                          PLAYER INIT                                          ;;
;;                                                                                               ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        ;
        ; Params:
        ;       A:  High byte of decrunch buffer
        ;       BC: Address of the player code
        ;       DE: RET address to jump at the end of the player execution.
        ;       HL: Music crunched data buffer
PlayerInit:
        exa             ; Backup A for later use
        push	de      ; Address to return from the player

        ;
        ;       Get the value of PC (small trick for PIC code). We need it for some PIC code.
        ;
        exx
        ld	de, (#0000)     ; Backup bytes from #0000
        ld	hl, #E9E1       ; Write POP HL; JP (HL)
        ld	(#0000), hl
        call	#0000
RetFromGetPC2:
        ld	(#0000), de     ; Restore bytes

        ; Compute address of PlayerInit base address
        ld	iy, PlayerInit - RetFromGetPC2
        ex	de, hl
        add	iy, de
        push	iy              ; Push for future use
        exx

        push	hl      ; Address of crunched data

        ;
        ; Initialize DataBufferReset in the player code. 
        ;
        WriteHLToPlayerCodeWithReloc DataBufferReset

        ;
        ; Do player code relocation
        ;
        ld	ix, #0000: add ix, sp      ; Backup SP

        push	bc      ; Pass BC to BC' using push / pop
        exx
        pop     bc

        ld	de, RelocTable - PlayerInit
        add	iy, de
        ld	sp, iy
        ld	a, (RelocTableEnd - RelocTable) / 2

RelocMainLoop:
        pop     hl
        add	hl, bc
        ld	e, (hl)
        inc	hl
        ld	d, (hl)
        ex	de, hl
;        add	hl, bc
        ex	de, hl
        ld	(hl), d
        dec	hl
        ld	(hl), e

        dec	a
        jr	nz, RelocMainLoop

        exx
        ld	sp, ix                  ; Restore SP

        ld	xl, NR_REGISTERS_TO_DECRUNCH

        ;
        ; Load Skip R12 flag
        ;
        ld	a, (hl)
        inc     hl
        or	a
        jr	z, NoSkipR12

        ; Let skip the R12 play.
        dec     xl
        exx
        ld	hl, #8779       ; Overwrite JR to PlayR12 with some instructions
        WriteHLToPlayerCodeWithReloc    SkipR12OverwriteJR
        exx

NoSkipR12:
        ld	a, xl   ; Let N = Number of registers to decrunch
        add	a, a    ; A = 2 * N
        ld	b, a    ; B = 2 * N
        add	a, a    ; A = 4 * N
        add	b       ; A = 6 * N

        exx
        Write8ToPlayerCodeWithReloc	DecrunchStateLoopValue, a
        exx

        ;
        ; Load number of registers to play
        ;
        ld	a, (hl)
        inc	hl

        exx
        Write8ToPlayerCodeWithReloc	NrRegistersToPlay, a
        exa
        Write8ToPlayerCodeWithReloc	CurrentPlayerBufferHigh, a
        exa

        ;
        ; Initialize registers
        ;
        push	bc              ; Backup player base address
        ld	bc, #C680
        exx
        ld	bc, #F400
        ld	de, #000E
InitRegisterLoop:
        ld	a, (hl)
        inc	hl
        WriteToPSGReg	d
        inc	d
        dec	e
        jr	nz, InitRegisterLoop

        ;
        ;       Compute the address of the decrunch state array. The array is located right after the decrunch buffers.
        ;
        exx
        pop	bc              ; Restore player base address
        exa
        add	a, xl
        Write8ToPlayerCodeWithReloc	ReLoadDecrunchSavedStateHigh, a
        exx

        ld	d, a
        sub	a, xl
        exa
        ld	e, 0            ; DE = address of the decrunch state array

        ;
        ; Initialize decrunch save state array.
        ;
        ld	xh, xl
        pop     bc
InitDecrunchStateLoop:
        xor	a
        ld	(de), a
        inc	de
        ld	(de), a
        inc	de
        exa
        ld	(de), a
        inc     a
        exa
        inc	de
        ld	(de), a
        inc	de

        ld	a, (hl)
        add	a, c
        ld	(de), a
        inc	de
        inc	hl
        ld	a, (hl)
        adc	a, b
        ld	(de), a
        inc	de
        inc	hl
        dec     xh
        jr	nz, InitDecrunchStateLoop

        ;
        ;       Update the player return adress to return in the following init code.
        ;
        exx
        pop	hl              ; Base address of PlayerInit
        ld	de, ReturnFromDecrunchCodeToInitCode - PlayerInit
        add	hl, de
        WriteHLToPlayerCodeWithReloc	ReturnAddress

        ld	hl, sp          ; Backup SP
        exx

        ;
        ; Loop to initialize decrunch buffers
        ;
        ld	xh, xl
InitDecrunchBufferLoop:
breakpoint
        ld	iy, #FFFF
        ld	e, #FF
        jp	DecrunchEntryPoint

ReturnFromDecrunchCodeToInitCode:
        ld	sp, #0000
        dec     xh
        jr	nz, InitDecrunchBufferLoop

        exx:    ld sp, hl       ; Restore SP

        Write8ToPlayerCodeWithReloc NrDecrunchLoop, 4

        pop	hl
        WriteHLToPlayerCodeWithReloc	ReturnAddress

        exx

        ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                                                               ;;
;;                                        RELOCATION TABLE                                       ;;
;;                                                                                               ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

RelocTable:
        dw	Reloc1 - RelocBase
        dw	Reloc2 - RelocBase
        dw	Reloc3 - RelocBase
        dw	Reloc4 - RelocBase
        dw	Reloc5 - RelocBase
        dw	Reloc6 - RelocBase
        dw	Reloc7 - RelocBase
        dw	Reloc8 - RelocBase
        dw	Reloc9 - RelocBase
        dw	Reloc10 - RelocBase
        dw	Reloc11 - RelocBase
        dw	Reloc12 - RelocBase
RelocTableEnd:
