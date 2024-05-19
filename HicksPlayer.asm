org #4000

        DECRUNCH_BUFFER_ADDR_HIGH	equ #70
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
MACRO   _ComputeCopyFromDictSourceAddr   ; 10 NOPS
        dec	sp
        pop	af
        inc	a
        ld	e, a
        ld	a, l
        sub e
        ld	e, a
MEND

;
; Copy string from dictionary
;
MACRO   _CopyFromDictLoop	LoopReg ; 12 * N NOPS
@CopyLoop:
        ld	a, (de)     
        ld	(hl), a
        inc	l
        inc	e
        nop
        nop
        dec	{LoopReg}
        jp	nz, @CopyLoop
MEND

;
; Copy literals from crunched data.
;
MACRO   _CopyLiteralLoop	LoopReg ; 12 * N NOPS
@CopyLoop:
        dec	sp
        pop	af
        ld	(hl), a         ; TODO: POP DE (ou BC) puis LD(HL), D; LD(HL), E
        inc	l
        dec	{LoopReg}
        jp	nz, @CopyLoop
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
        pop	af      ; TODO:  remove pop AF and corresponding PUSH BC. The old A value is stored in E. Adjust Saved state size
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
        jp	c, CopyLiteral          ; A < 1F --> Copy literals
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
        _ComputeCopyFromDictSourceAddr	(void)          ; 10 (+1) NOPS
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
        ld	a, h
        pop	hl
        ld	sp, hl
        ld	h, a
        ld	l, #00

        ds	14
        
        jr	FetchNewCrunchMarker

        ;
        ;       Copy from dictionnary
        ;
CopySubStringFromDict:
        _AdjustCopySizeWithRemainingSlots	(void)        ; 2 NOPS
        _ComputeCopyFromDictSourceAddr	(void)                ; 10 (+1) NOPS

RestartCopySubStringFromDict:
        ld	d, h                           ; TODO: copier LD D, H dans restart decrunch et l'intégrer dans _ComputeCopyFromDictSourceAddr pour plus de clareté.
        _CopyFromDictLoop	c                             ; 12 * N NOPS
        
        ld	d, b
        ld	b, RESTART_COPY_FROM_DICT_MARKER
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
        or	a
        jp	nz, RestartCopyLiteral
        
        ds      14

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
        ds      12

        cp	c
        jp	nc, CopySubLiteralChain

        _UpdateNrCopySlot	(void)          ; 4 NOPS
        _CopyLiteralLoop        b

        jp	FetchNewCrunchMarker

        ;
        ; We have more literal to copy than available copy slots
        ;
CopySubLiteralChain:
        nop                             ; TODO: déplacer le nop dans le "ds 3" ci-dessous

        sub	c
        ld	d, a                    ; TODO: remplacer par _AdjustCopySizeWithRemainingSlots et mettre ld d, b plus bas comme en fin de copy from dict.
        _CopyLiteralLoop        c

        ld	b, RESTART_COPY_LITERAL_MARKER
        ds      3

        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;
        ;;      Finish decrunch code
        ;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

DecrunchFinalize:
        ld	hl, #0000
        add	hl, sp

        ld	sp, (ReLoadDecrunchSavedState)
        push	bc
        push	hl
        push	de
DecrunchFinalCode:
        ld	a, #06
        sub	ly        
StabilizeLoop:
        jr	z, WriteToPSG

        ds      32

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
; A:   Value to write in the register
; B:   #F4
;
; B':  #F6
; HL': Constant #C080
;
MACRO   WriteToPSGReg	RegNumber
        out	(c), {RegNumber}
        exx
        out	(c), 0
        exx
        out	(c), a
        exx
        out	(c), l
        out	(c), h
        exx
MEND

WriteToPSG:
        ld	hl, (CurrentDecrunchBuffer)
        ld	h, DECRUNCH_BUFFER_ADDR_HIGH
        ld	b, #f4
        ld	e, #02
        exx
        ld	b, #f6
        ld	hl, #c080
        out	(c), h  ; F6 = #C0
        exx

        ;
        ; Write to register 0
        ;
        ld	a, (hl)
        inc	h
        WriteToPSGReg	0

        ;
        ; Write to register 2
        ;
        ld	a, (hl)
        inc	h
        WriteToPSGReg	e

        ;
        ; Write to register 1
        ;
        ld	a, (hl)
        dec	e
        WriteToPSGReg	e

        ;
        ; Write to register 3
        ;
        ld	e, #03
        rra
        rra
        rra
        rra
        inc	h
        WriteToPSGReg	e

        ;
        ; Write to register 4
        ;
        ld	a, (hl)
        inc	h
        inc	e
        WriteToPSGReg	e

        ;
        ; Write to register 6
        ;
        ld	a, (hl)
        inc	h
        ld	e, #06
        WriteToPSGReg	e

        ;
        ; Write to register 8
        ;
        ld	e, #08
        ld	a, (hl)
        inc	h
        WriteToPSGReg	e

        ;
        ; Write to register 9
        ;
        inc	e
        ld	a, (hl)
        inc	h
        WriteToPSGReg	e

        ;
        ; Write to register 10
        ;
        inc	e
        ld	a, (hl)
        inc	h
        WriteToPSGReg	e
        
        ;
        ; Write to register 11
        ;
        inc	e
        ld	a, (hl)
        inc	h
        WriteToPSGReg	e

if      SKIP_R12!=1
        ;
        ; Write to register 12
        ;
        ld	a, (hl)
        inc	h
        inc	e
        WriteToPSGReg	e
endif

        ;
        ; Write to register 5
        ;
        ld	a, (hl)
        ld	e, #05
        WriteToPSGReg	e

        ;
        ; Write to register 13
        ;
        inc	h
        bit	7, (hl)                 ; Test "Continue" bit. If set, do not write to register 13.
        jr	nz, SkipRegister13
        ld	e, #0d
        rra
        rra
        rra
        rra
        WriteToPSGReg	e

ReturnFromSkipRegister13:
        ;
        ; Write to register 7
        ;
        ld	a, (hl)
        ld	e, #07
        WriteToPSGReg	e

        ld	hl, (CurrentDecrunchBuffer)
        inc	l
        inc	h
        ld	a, h
        cp	DECRUNCH_BUFFER_ADDR_HIGH + NR_REGISTERS_TO_DECRUNCH
        jr	nz, SkipBufferReset

        ld	bc, DecrunchSavedState
        ld	(ReLoadDecrunchSavedState), bc
        ld	h, DECRUNCH_BUFFER_ADDR_HIGH
ReturnFromSkipBufferReset:
        ld	(CurrentDecrunchBuffer), hl

FrameCounter equ $ + 1
        ld	hl, #0000
        dec	hl
        ld	a, h
        or	l
        jr	z, ResetFrameCounter

        ds	6

        jr	SkipFrameCounterReset
        
ResetFrameCounter:
FrameCounterReset  equ	$ + 1
        ld	hl, #0000
        xor	a
        ld	(CurrentDecrunchBufferLow), a

SkipFrameCounterReset:
        ld	(FrameCounter), hl
ReturnAddress = $+1
        jp	#0000

        ;
        ; Wait loop for constant time when register 13 is ignored.
        ;
SkipRegister13:
        ld	a, #06        
WaitLoop
        dec	a
        jp	nz, WaitLoop
        jr	ReturnFromSkipRegister13

        ;
        ; Wait loop for constant time if there is no need to reset decrunch buffers
        ;
SkipBufferReset:
        ds      7
        jr	ReturnFromSkipBufferReset

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
        ld	(FrameCounter), de      ; Write number of frames
        ld	(FrameCounterReset), de ;
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
        inc	de
        inc	de
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
        ds      6
DecrunchSavedStateReg1:
        ds	66

CodeBackup:                   ; Init data
        ds	3
JumpToInitCode:               ; Init data
        jp	ReturnFromDecrunchCodeToInitCode

        save"Player.bin",	#4000, $ - #4000
