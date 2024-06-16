org #3300

        DECRUNCH_BUFFER_ADDR_HIGH	equ #C0
        NR_REGISTERS_TO_DECRUNCH        equ #0C
        NR_REGISTERS_TO_PLAY	equ NR_REGISTERS_TO_DECRUNCH + 2

        RESTART_COPY_FROM_DICT_MARKER   equ     0
        RESTART_COPY_LITERAL_MARKER	equ     1

        SKIP_R12	= 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                                                               ;;
;;                                             MACROS                                            ;;
;;                                                                                               ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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
        ds      2
        dec	{LoopReg}
        jr	nz, @CopyLoop
MEND

;
; Copy literals from crunched data.
;

MACRO   _CopyLiteralLoop   LoopReg ; 2 + 10 * N NOPS
@CopyLoop:
        ld      (hl), d
        inc     l
        ds      5
        dec     {LoopReg}
        jr      nz, @ContinueLoop
        jr      @ExitLoop
@ContinueLoop:
        pop     de
        ld      (hl), e
        inc	l
        ds      2
        dec     {LoopReg}
        jp      nz, @CopyLoop
        dec     sp
@ExitLoop:
MEND

        ;
        ; Write a value in a PSG register
        ;

        NO_REG_SHIFT	= 0
        REG_SHIFT	= 1

MACRO   WriteToPSGReg	RegNumber       ; 25 NOPS
        out	(c), {RegNumber}

        exx
        dec	c              ; Dec number of registers to play
        out	(c), 0
        exx

        out	(c), a

        exx
        out	(c), l
        out	(c), h
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

CurrentPlayerBuffer:
        ld	hl, DECRUNCH_BUFFER_ADDR_HIGH << 8
        ld	a, l
        inc     a
        ld	(CurrentPlayerBuffer + 1), a
        exx
        ld	bc, #F600 + 14  ; This value can be adjusted to increase performance.
        ld	hl, #c080
        exx
        ld	bc, #F402
        ld	de, #0301

        ;
        ; Write to register 0
        ;
        WriteToPSGRegSkip	0, e
        inc	h

        ;
        ; Write to register 2
        ;
        WriteToPSGRegSkip       c, e
        inc	h

        ;
        ; Write to register 1
        ;
        dec	c
        ld	a, (hl)
        dec     l
        cp	(hl)
        jp	z, SkipR1_3
        WriteToPSGReg   c

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
        dec	l
        cp	(hl)
        jr	z, SkipR5
        WriteToPSGReg	d
SkipR5:
        inc     l

        ;
        ; Write to register 13
        ;
        rra
        rra
        rra
        rra
        inc	h
        bit	7, (hl)                 ; Check if we have to program register 13.
        ld	c, 13
        jr	nz, SkipRegister13
        WriteToPSGReg	c
SkipRegister13

        ;
        ; Write to register 6
        ;
        inc     d
        WriteToPSGRegSkip	d, b
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
        WriteToPSGRegSkip	d, e
        inc	h

if      SKIP_R12!=1
        ;
        ; Write to register 12
        ;
        inc	d
        ld	a, (hl)
        WriteToPSGReg   d
endif

        exx
        dec	c
        jr	z, SkipDecrunchTrampoline2
        ld	a, c
        add	a, a
        ld	(NrValuesToDecrunch), a
        exx

        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;
        ;;      Decrunch buffers start
        ;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        ;
        ; Move to the next decrunch buffer and handle buffer loop.
        ;
        ld	a, (ReLoadDecrunchSavedState)
        cp	NR_REGISTERS_TO_DECRUNCH * 6
        jr	nz, SkipBufferReset
        xor	a
SkipBufferReset:
        ld	(ReLoadDecrunchSavedState), a

DecrunchEntryPoint:
ReLoadDecrunchSavedState  equ	$ + 1
        ld	sp, DecrunchSavedState
        pop	de      ; d = restart if not null       e = Lower byte of source address if restart copy from windows. Undef otherwise.
        ld	a, l    ; Current position of the player in the decrunched buffer
        pop	hl      ; Current position in decrunch buffer
        sub	l       ; Distance 
        exx
        pop	hl      ; Current position in crunched data buffer
        ld	(ReLoadDecrunchSavedState), sp
        cp	28      ; Leave a security gap between the current decrunch position and the player position.
SkipDecrunchJump:
        jr	c, SkipDecrunchTrampoline
        
        ld	a, h
        res	7, h
        ld	sp, hl          ; Load current position in decrunch buffer
        exx

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
        ld	c, 200
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
        jp	SkipDecrunch2
SkipDecrunchTrampoline:
        jp      SkipDecrunch

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
        jp      ExitMainDecrunchLoop

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
        ds      5

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
        ld	(hl), d
        inc	l
        
        exx
        pop	hl
        ld	sp, hl
        exx
        ds      6
        dec	c
        ld	d, c
        jp	z, DecrunchFinalize
        nop
        dec	ly
        jp	nz, FetchNewCrunchMarker
        jp      ExitMainDecrunchLoop

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

        ds      3
EnterStabilizeLoop:
        ds      17

        dec	ly
        jr	StabilizeLoop

ExitMainDecrunchLoop:
        xor	a
        ld	d, a
        dec	c
        ds      6
        jr	nz, ExitMainDecrunchLoop

        ;
        ; Write back to memory the current decrunch state.
        ;
SaveDecrunchState:
        exx
        ld	h, a
        ld	l, 0    ; TODO: optimiser avec un registre à 0 quelque part ?????
        add	hl, sp
        ld	sp, (ReLoadDecrunchSavedState)
        push	hl      ; Save current position in crunched data buffer
        exx
        push	hl      ; Save current position in decrunch buffer
        push	de
DecrunchFinalCode:

        ;
        ; Return to the calling code.
        ;
ReturnAddress = $+1
        jp	#0000

SkipR1_3:
        ds      3
        jp      SkipR1_3Return

SkipDecrunch2:
        ld	a, 15
        ds      4
        jr	SkipDecrunchLoop
        
SkipDecrunch:
        ld	a, (NrValuesToDecrunch)
        add	a, 11
        ds      6
SkipDecrunchLoop:
        ds	8
        dec	a
        jr	nz, SkipDecrunchLoop

        jp      DecrunchFinalCode


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                                                               ;;
;;                                          PLAYER INIT                                          ;;
;;                                                                                               ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        ;
        ; Params:
        ;       HL: Music data

PlayerInit:
        ld	(ReturnAddress), ix

        ;
        ; Initialize registers
        ;
        xor     a
        ld	b, #f4
        exx
        ld	b, #f6
        ld	hl, #c080
        exx        
InitRegisterLoop:               ; TODO: pourquoi ne pas utiliser la macro WriteToPsgReg ? Juste pour la lisibilité.
        out	(c), a          ; #F4 = Reg number
        exx
        out	(c), h          ; #F6 = #C0
        out	(c), 0          ; #F6 = #00
        exx
        inc	b
        outi                    ; #F4 = Reg Value
        exx
        out	(c), l          ; #F6 = #80
        out	(c), 0          ; #F6 = #00
        exx
        inc	a
        cp      14
        jr	nz, InitRegisterLoop

        ;
        ; Initialize decrunch save state array.
        ;
        ld	de, DecrunchSavedState
        ld	b, NR_REGISTERS_TO_DECRUNCH
        xor	a
        exa
        ld	a, DECRUNCH_BUFFER_ADDR_HIGH
        exa

InitDecrunchStateLoop:
        inc	de
        ld	(de), a
        inc	de
        inc	de
        exa
        ld	(de), a
        inc     a
        exa
        inc     de
        ldi                     ; Copy register crunched data address
        ldi
        djnz	InitDecrunchStateLoop

        ;
        ; Backup and replace decrunch final code by a jump to the init code.
        ;
        ld	hl, DecrunchFinalCode
        ld	de, CodeBackup
        ld	bc, #0003
        ldir

        ld	hl, JumpToInitCode
        ld	de, DecrunchFinalCode
        ld	bc, #0003
        ldir

        ld	hl, (SkipDecrunchJump)
        ld	(SkipDecrunchRestore), hl
        ld	hl, 0
        ld	(SkipDecrunchJump), hl

        ;
        ; Loop to initialize decrunch buffers with 1, 2, 3,..., N values
        ;
        ld	hl, DecrunchSavedState
        ld	(ReLoadDecrunchSavedState), hl
        ld	b, NR_REGISTERS_TO_DECRUNCH
InitDecrunchBufferLoop:
        push	bc
        ld	(SaveStack), sp
        jp	DecrunchEntryPoint
SaveStack equ $ + 1
ReturnFromDecrunchCodeToInitCode:
        ld	sp, #0000
        pop	bc
        djnz	InitDecrunchBufferLoop

        ld	hl, DecrunchSavedState
        ld	(ReLoadDecrunchSavedState), hl

        ;
        ; Restore decrunch final code.
        ;
        ld	hl, CodeBackup
        ld	de, DecrunchFinalCode
        ld	bc, #0003
        ldir

        ;
        ; Restore "skip decrunch" jump
        ;
SkipDecrunchRestore = $+1
        ld	hl, 0
        ld	(SkipDecrunchJump), hl

        ld	a, 4
        ld	(NrDecrunchLoop), a

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

CodeBackup:                   ; Init data
        ds	3
JumpToInitCode:               ; Init data
        jp	ReturnFromDecrunchCodeToInitCode ; TODO: utiliser le JP du DecrunchFinalCode pour simplifier le code
