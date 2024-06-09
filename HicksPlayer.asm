org #3400

        DECRUNCH_BUFFER_ADDR_HIGH	equ #C0
        NR_REGISTERS_TO_DECRUNCH        equ #0C

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
        ds      3
        dec     {LoopReg}
        jr      nz, @ContinueLoop
        jr      @ExitLoop
@ContinueLoop:
        pop     de
        ld      (hl), e
        inc     l
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

MACRO   WriteToPSGReg	RegNumber, Shift
        out	(c), {RegNumber}

        ld	a, d
        out	(#FF), a        ; Equivalent to out &F600, %00XXXXXX

        ld	a, (hl)

if {Shift}==REG_SHIFT
        rra
        rra
        rra
        rra
endif

        out	(c), a
        ld	a, e
        out	(#FF), a        ; Equivalent to out &F600, %10XXXXXX
        or	b               ; A or B --> #F6 Great :)
        out	(#FF), a        ; Equivalent to out &F600, %11XXXXXX
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
        ld	bc, #C402
        ld	de, #2686
        ld	a, d
        out	(#FF), a

        ;
        ; Write to register 0
        ;
        WriteToPSGReg	0, NO_REG_SHIFT
        inc	h

        ;
        ; Write to register 2
        ;
        WriteToPSGReg	c, NO_REG_SHIFT
        inc	h

        ;
        ; Write to register 1
        ;
        dec     c
        WriteToPSGReg	c, NO_REG_SHIFT

        ;
        ; Write to register 3
        ;
        ld	c, 3
        WriteToPSGReg	c, REG_SHIFT
        inc	h

        ;
        ; Write to register 4
        ;
        inc	c
        WriteToPSGReg	c, NO_REG_SHIFT
        inc	h

        ;
        ; Write to register 5
        ;
        inc     c
        WriteToPSGReg	c, NO_REG_SHIFT

        ;
        ; Write to register 13
        ;
        inc	h
        bit	7, (hl)                 ; Check if we have to program register 13.
        ld	c, 13
        jp	nz, SkipRegister13
        dec     h        
        WriteToPSGReg	c, REG_SHIFT
        inc     h
ReturnFromSkipRegister13:

        ;
        ; Write to register 6
        ;
        ld	c, 6
        WriteToPSGReg	c, NO_REG_SHIFT
        inc	h

        ;
        ; Write to register 7
        ;
        inc     c
        WriteToPSGReg	c, NO_REG_SHIFT
        inc     h

        ;
        ; Write to register 8
        ;
        inc     c
        WriteToPSGReg	c, NO_REG_SHIFT
        inc	h

        ;
        ; Write to register 9
        ;
        inc	c
        WriteToPSGReg	c, NO_REG_SHIFT
        inc	h

        ;
        ; Write to register 10
        ;
        inc	c
        WriteToPSGReg	c, NO_REG_SHIFT
        inc	h
        
        ;
        ; Write to register 11
        ;
        inc	c
        WriteToPSGReg	c, NO_REG_SHIFT
        inc	h

if      SKIP_R12!=1
        ;
        ; Write to register 12
        ;
        inc	c
        WriteToPSGReg	c, NO_REG_SHIFT
endif

        ;
        ; Move to the next decrunch buffer and handle buffer loop.
        ;
        ld	a, (ReLoadDecrunchSavedState)
        cp	NR_REGISTERS_TO_DECRUNCH * 6
        jr	nz, SkipBufferReset
        xor	a
SkipBufferReset:
        ld	(ReLoadDecrunchSavedState), a

        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;
        ;;      Decrunch buffers start
        ;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

DecrunchEntryPoint:
ReLoadDecrunchSavedState  equ	$ + 1
        ld	sp, DecrunchSavedState
        pop	de      ; d = restart if not null       e = Lower byte of source address if restart copy from windows. Undef otherwise.
        pop	hl      ; Current position in decrunch buffer
        exx
        pop	hl      ; Current position in crunched data buffer
        ld	(ReLoadDecrunchSavedState), sp
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

        ld	c, NR_REGISTERS_TO_DECRUNCH
        ld	ly, #05
        inc	d
        dec	d
        jr	nz, RestartPausedDecrunch

        ;
        ; Load a new marker
        ;
FetchNewCrunchMarker:
        dec	ly

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

        jr	FetchNewCrunchMarker

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

        jp	FetchNewCrunchMarker

        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;
        ;;      Continue paused Decrunch
        ;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

RestartPausedDecrunch:
        dec	ly
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
        ds      4
        dec	c
        ld	d, c
        jp	z, DecrunchFinalize
        nop
        jr	FetchNewCrunchMarker

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
        exx
        ld	h, c

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
        exx
        ld	h, #80

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

        ;
        ; Write back to memory the current decrunch state.
        ;
SaveDecrunchState:
        ld	l, c
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

        ;
        ; Wait loop for constant time when register 13 is ignored.
        ;
SkipRegister13:
        ld	a, #06  
WaitLoop:
        dec	a
        jr	nz, WaitLoop
        jp	ReturnFromSkipRegister13

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

        ld	e, (hl)         ; Read number of frames.
        inc	hl
        ld	d, (hl)
        inc	hl
;        ld	(FrameCounter), de      ; Write number of frames        - TODO: Supprimer le frame counter du fichier ?????
;        ld	(FrameCounterReset), de ;
        ex	de, hl
        ld	a, (de)         ; Read number of constant registers
        inc	de

NextConstantReg:
        or	a
        jr	z, ConstantRegOver
        push	af
        ld	a, (de)
        inc	de
        add	a
        inc	a
        ld	b, #00
        ld	c, a
        ld	hl, ConstantRegisters
        add	hl, bc
        ld	a, (de)
        inc	de
        ld	(hl), a
        pop	af
        dec	a
        jr	NextConstantReg

ConstantRegOver:
        ex	de, hl
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
        ; Initialize registers
        ;
        ld	hl, ConstantRegisters
        ld	a, #0e
        ld	b, #f4
        exx
        ld	b, #f6
        ld	hl, #c080
        exx        
InitRegisterLoop:               ; TODO: pourquoi ne pas utiliser la macro WriteToPsgReg ? Juste pour la lisibilité.
        inc	b
        outi                    ; #F4 = Reg number
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
        dec	a
        jr	nz, InitRegisterLoop
        ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                                                               ;;
;;                                          PLAYER DATA                                          ;;
;;                                                                                               ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; TODO: regouper init data ensemble et les mette dans la section ".init"

ConstantRegisters:              ; Init data
        db	0, 0
        db      1, 0
        db      2, 0
        db	3, 0
        db	4, 0
        db	5, 0
        db	6, 0
        db	7, #3F
        db	8, 0
        db	9, 0
        db	10, 0
        db	11, 0
        db	12, 0
        db	13, 0

; TODO: Réutiliser l'espace du header de format auquel on ajoute un peu d'espace pour compléter.
align   256
DecrunchSavedState:
        ds      6
DecrunchSavedStateReg1:
        ds	66

CodeBackup:                   ; Init data
        ds	3
JumpToInitCode:               ; Init data
        jp	ReturnFromDecrunchCodeToInitCode

        save"Player.bin",	#4000, $ - #4000
