org #3300

        DECRUNCH_BUFFER_ADDR_HIGH	equ #C0
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
        jp      nz, @CopyLoop
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

        jp	PlayerInit

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

CurrentPlayerBuffer = $+1
        ld	hl, DECRUNCH_BUFFER_ADDR_HIGH << 8
        ld	a, l
        inc     a
        ld	(CurrentPlayerBuffer), a
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
        ld	hl, DecrunchSavedState
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
        jp      ExitMainDecrunchLoop

SkipDecrunchTrampoline2:
        ld	a, 15
        jp	SkipDecrunchLoop

SkipDecrunchTrampoline:
        jp      SkipDecrunch

PlayR12Trampoline:
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
        jp	nc, RestartSubCopyFromDict

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
        jp	nz, FetchNewCrunchMarker
        jp      ExitMainDecrunchLoop2

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
        SKIP_NOPS 3
        jp      SkipR1_3Return
        
SkipDecrunch:
        ld	a, (NrValuesToDecrunch)
        add	a, 11
        SKIP_NOPS 6
SkipDecrunchLoop:
        SKIP_NOPS 8
        dec	a
        jr	nz, SkipDecrunchLoop

        jp      DecrunchFinalCode

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
        ;       HL: Music crunched data buffer
        ;       IX: RET address to jump at the end of the player execution.
PlayerInit:
        ld	a, l
        ld	(DataBufferLow), a
        ld	a, h
        ld	(DataBufferHigh), a
        ld	(DataBufferReset), hl

        ld	(BackupReturnAddress), ix
        ld	ix, ReturnFromDecrunchCodeToInitCode
        ld	(ReturnAddress), ix

        ld	xl, NR_REGISTERS_TO_DECRUNCH

        ;
        ; Load Skip R12 flag
        ;
        ld	a, (hl)
        inc     hl
        or	a
        jr	z, NoSkipR12
        dec     xl
        ld	iy, #8779
        ld	(SkipR12OverwriteJR), iy
NoSkipR12:

        ld	a, xl   ; Let N = Number of registers to decrunch
        add	a, a    ; A = 2 * N
        ld	b, a    ; B = 2 * N
        add	a, a    ; A = 4 * N
        add     b       ; A = 6 * N
        ld	(DecrunchStateLoopValue), a

        ;
        ; Load number of registers to play
        ;
        ld	a, (hl)
        inc     hl
        ld	(NrRegistersToPlay), a

        ;
        ; Initialize registers
        ;
        exx
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
        ; Initialize decrunch save state array.
        ;
        ld	de, DecrunchSavedState
        ld	b, xl
        exa
        ld	a, DECRUNCH_BUFFER_ADDR_HIGH
        exa

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
DataBufferLow = $+1
        add	a, #00
        ld	(de), a
        inc	de
        inc	hl
        ld	a, (hl)
DataBufferHigh = $+1
        adc	a, #00
        ld	(de), a
        inc	de
        inc	hl
        djnz	InitDecrunchStateLoop

        ;
        ; Loop to initialize decrunch buffers with 1, 2, 3,..., N values
        ;
        ld	hl, DecrunchSavedState
        ld	(ReLoadDecrunchSavedState), hl
        ld	b, xl
InitDecrunchBufferLoop:
        push	bc
        ld	(SaveStack), sp
        ld	e, #FF
        jp	DecrunchEntryPoint
SaveStack equ $ + 1
ReturnFromDecrunchCodeToInitCode:
        ld	sp, #0000
        pop	bc
        djnz	InitDecrunchBufferLoop

        ld	hl, DecrunchSavedState
        ld	(ReLoadDecrunchSavedState), hl

        ld	a, 4
        ld	(NrDecrunchLoop), a

BackupReturnAddress = $+1
        ld	hl, #0000
        ld	(ReturnAddress), hl

        ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                                                               ;;
;;                                          PLAYER DATA                                          ;;
;;                                                                                               ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; TODO: Réutiliser l'espace du header de format auquel on ajoute un peu d'espace pour compléter.
align   256
DecrunchSavedState:
        ds	72
