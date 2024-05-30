org #3000

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
MACRO   _ComputeCopyFromDictSourceAddr   ; 8 NOPS
        dec	sp
        pop	af
        sub	l
        cpl
        ld	e, a
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
MACRO   _CopyLiteralLoop	LoopReg ; 10 + 10 * N NOPS - 1
        ds      2
        srl	{LoopReg}
        jp	nc, @CopyLoop
        jr	z, @CopyOne
        dec	sp
        pop	de
        ld	(hl), d
        inc	l
@CopyLoop:
        pop	de
        ld	(hl), e
        inc	l
        ld	(hl), d
        inc	l
        ds      7
        dec	{LoopReg}
        jr	nz, @CopyLoop
        
        jr      @CopyEnd
@CopyOne:
        nop
        dec	sp
        pop	de
        ld	(hl), d
        inc     l
@CopyEnd:
MEND

        jp	PlayerInit

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                                                               ;;
;;                                       MAIN PLAYER CODE                                        ;;
;;                                                                                               ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

PlayerEntryPoint:
ReLoadDecrunchSavedState equ $ + 1
        ld	sp, DecrunchSavedState
        pop	de      ; d = restart if not null       e = ???
        pop	hl      ; Current position in decrunch buffer
        ld	(ReLoadDecrunchSavedState), sp

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

        ld	a, h
        res	7, h
        ld	sp, hl          ; Load current position in decrunch buffer
CurrentDecrunchBuffer equ $ + 1
CurrentDecrunchBufferLow equ $ + 1
CurrentDecrunchBufferHigh equ $ + 2
        ld	hl, DECRUNCH_BUFFER_ADDR_HIGH << 8

NrDataToDecrunch:  equ	$ + 1
        ld	c, #00
        ld	ly, #00
        inc	d
        dec	d
        jr	nz, RestartPausedDecrunch

        ;
        ; Load a new marker
        ;
FetchNewCrunchMarker:
        inc	ly
        dec	sp
        pop	af              ; Fetch marker from crunch data.
        cp	#1f

        ; TODO: changer l'ordre des jump pour aller en priorité sur "CopyFromDict"

        jr	z, DoFramesLoop    ; A = 1F --> Reset source buffer for frame loop
        jr	c, CopyLiteral          ; A < 1F --> Copy literals
                                        ; A > 1F --> Copy from dictionnary

        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;
        ;;      Copy from dictionnary
        ;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        sub	#1d
        cp	c
        jp	nc, CopySubStringFromDict


        _UpdateNrCopySlot	(void)                  ; 4 NOPS
        _ComputeCopyFromDictSourceAddr	(void)          ; 8 (+1) NOPS
RestartCopyFromDict:
        ld	d, h

        _CopyFromDictLoop	b                       ; 12 * N NOPS

        jr	FetchNewCrunchMarker

        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;
        ;;      Do Frames loop
        ;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        
DoFramesLoop:
        dec	sp
        pop	af
        ld	(hl), a
        inc     l

        exx
        pop	hl
        ld	sp, hl
        exx
        ds      9
        dec	c
        ld	d, c
        jp	z, PreDecrunchFinalize
        jr	FetchNewCrunchMarker

        ;
        ;       Copy from dictionnary
        ;
CopySubStringFromDict:
        _AdjustCopySizeWithRemainingSlots	(void)        ; 2 NOPS
        _ComputeCopyFromDictSourceAddr	(void)                ; 8 (+1) NOPS

RestartCopySubStringFromDict:
        ld	d, h                           ; TODO: copier LD D, H dans restart decrunch et l'intégrer dans _ComputeCopyFromDictSourceAddr pour plus de clareté.
        _CopyFromDictLoop	c                             ; 12 * N NOPS
        
        ld	d, b
        ld	h, c
        ld	l, c
        jp	DecrunchFinalize

        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;
        ;;      Continue paused Decrunch
        ;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

RestartPausedDecrunch:
        nop
        inc	ly
        rla
        jp	c, RestartCopyLiteral
        
        ds      11

        ld	a, d
        cp	c
        jp	nc, RestartSubCopyFromDict

        _UpdateNrCopySlot	(void)          ; 4 NOPS
        jr	RestartCopyFromDict
RestartSubCopyFromDict:
        _AdjustCopySizeWithRemainingSlots (void)
        jr	RestartCopySubStringFromDict

        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;
        ;;      Copy Literal
        ;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

RestartCopyLiteral:
        ds	3
        
        ld	a, d
        jr	SkipInc                 ; TODO: peut être remplacé par "dec a; nop; nop"

        ;
        ;       Copy literals
        ;
CopyLiteral:
        inc	a
SkipInc:

        
        cp	c
        jr	nc, CopySubLiteralChain

        _UpdateNrCopySlot	(void)          ; 4 NOPS
        _CopyLiteralLoop        b

        jp	FetchNewCrunchMarker
        

        ;
        ; We have more literal to copy than available copy slots
        ;
CopySubLiteralChain:

        _AdjustCopySizeWithRemainingSlots       (void)
        _CopyLiteralLoop	c

        ld	d, b

PreDecrunchFinalize:
        ds      1
        ld	hl, #8000

        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;
        ;;      Finish decrunch code
        ;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

DecrunchFinalize:
        add	hl, sp

        ld	sp, (ReLoadDecrunchSavedState)
        push	hl
        push	de
DecrunchFinalCode:
        ld	a, #04
        sub	ly        
StabilizeLoop:
        jr	z, WriteToPSG

        ds      28

        dec	a
        jr	StabilizeLoop           ; TODO: jr nz,SabiliteLoop (skip jr z, WriteToPSG) ---> Gagne 1 NOP sur la sortie.

        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;
        ;;       AY programming
        ;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        ;
        ; Write a value in a PSG register
        ;

        NO_REG_SHIFT	= 0
        REG_SHIFT	= 1

MACRO   WriteToPSGReg	RegNumber, Shift
        out	(c), {RegNumber}

        ld	a, #26
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
        ld	a, d
        out	(#FF), a        ; Equivalent to out &F600, %11XXXXXX
MEND

        ;
        ;       Main PSG Programming code
        ;
WriteToPSG:
        ld	hl, (CurrentDecrunchBuffer)
        ld	h, DECRUNCH_BUFFER_ADDR_HIGH
        ld	bc, #f402
        ld	de, #f6b6
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
        bit	7, (hl)                 ; Test "Continue" bit. If set, do not write to register 13.
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
        ld	hl, (CurrentDecrunchBuffer)
        inc	l
        ld	a, h
        cp	DECRUNCH_BUFFER_ADDR_HIGH + NR_REGISTERS_TO_DECRUNCH - 1
        jr	nz, SkipBufferReset

        ; Loop back to the first decrunch buffer.
        ld	h, DECRUNCH_BUFFER_ADDR_HIGH
        ld	(CurrentDecrunchBuffer), hl
        ld	hl, DecrunchSavedState                  ; TODO: optimisation après avoir déplacé SavedState : reset seulement le poids faible. Gain = 3 NOPS.
        ld	(ReLoadDecrunchSavedState), hl
ReturnFromSkipBufferReset:

        ;
        ; Return to the calling code.
        ;
ReturnAddress = $+1
        jp	#0000

        ;
        ; Wait loop for constant time if there is no need to reset decrunch buffers
        ;
SkipBufferReset:
        ds      5
        inc	h
        ld	(CurrentDecrunchBuffer), hl
        jr	ReturnFromSkipBufferReset

        ;
        ; Wait loop for constant time when register 13 is ignored.
        ;
SkipRegister13:
        nop
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

InitDecrunchStateLoop:
        inc	de
        ld	(de), a
        inc	de
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
        ld	a, #01
        ld	(NrDataToDecrunch), a
        ld	hl, (DECRUNCH_BUFFER_ADDR_HIGH + 1) << 8
        ld	(CurrentDecrunchBuffer), hl
        ld	hl, DecrunchSavedStateReg1
        ld	(ReLoadDecrunchSavedState), hl
        ld	b, #0b
InitDecrunchBufferLoop:
        push	bc
        ld	(SaveStack), sp        
        jp	PlayerEntryPoint
SaveStack equ $ + 1
ReturnFromDecrunchCodeToInitCode:
        ld	sp, #0000
        pop	bc
        ld	a, (CurrentDecrunchBufferHigh)
        inc	a
        ld	(CurrentDecrunchBufferHigh), a
        ld	a, (NrDataToDecrunch)
        inc	a
        ld	(NrDataToDecrunch), a
        djnz	InitDecrunchBufferLoop

        ld	a, NR_REGISTERS_TO_DECRUNCH
        ld	(NrDataToDecrunch), a
        ld	hl, DECRUNCH_BUFFER_ADDR_HIGH << 8
        ld	(CurrentDecrunchBuffer), hl
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
DecrunchSavedState:
        ds      4
DecrunchSavedStateReg1:
        ds	44

CodeBackup:                   ; Init data
        ds	3
JumpToInitCode:               ; Init data
        jp	ReturnFromDecrunchCodeToInitCode

        save"Player.bin",	#4000, $ - #4000
