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
MACRO   _CopyFromDictLoop	LoopReg ; 11 * N NOPS
@CopyLoop:
        ld	a, (de)     
        ld	(hl), a
        inc	l
        inc	e
        nop
        dec	{LoopReg}
        jr	nz, @CopyLoop
MEND

;
; Copy literals from crunched data.
;
MACRO   _CopyLiteralLoop	LoopReg ; 11 * N NOPS
@CopyLoop:
        ld	a, (hl)     
        ld	(de), a
        inc	hl
        inc	e
        dec	{LoopReg}
        jr	nz, @CopyLoop
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
        ld	b, l
        pop	hl
        ld	sp, hl
        ld	h, a
        ld	l, b

        ds	12
        
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
        ld	h, #00
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
        
        ds      13

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

        nop
        ex	de, hl
        ld	hl, #0000
        add	hl, sp

        cp	c
        jp	nc, CopySubLiteralChain

        _UpdateNrCopySlot	(void)          ; 4 NOPS
        _CopyLiteralLoop        b

        ld	sp, hl
        ex	de, hl

        jp	FetchNewCrunchMarker


        ;
        ; We have more literal to copy than available copy slots
        ;
CopySubLiteralChain:

        _AdjustCopySizeWithRemainingSlots       (void)
        _CopyLiteralLoop	c

        ld	sp, hl
        ex	de, hl

        ld	d, b
        ds      3

        ld	h, #80


        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;
        ;;      Finish decrunch code
        ;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

DecrunchFinalize:
        ld	l, #00
        add	hl, sp

        ld	sp, (ReLoadDecrunchSavedState)
        push	hl
        push	de
DecrunchFinalCode:
        ld	a, #06
        sub	ly        
StabilizeLoop:
        jr	z, WriteToPSG

        ds      30

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
        ld	bc, #f406
        ld	de, #0102
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
        WriteToPSGReg	d

        ;
        ; Write to register 3
        ;
        inc     e
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
        WriteToPSGReg	c

        ;
        ; Write to register 8
        ;
        ld	d, #08
        ld	a, (hl)
        inc	h
        WriteToPSGReg	d

        ;
        ; Write to register 9
        ;
        inc	d
        ld	a, (hl)
        inc	h
        WriteToPSGReg	d

        ;
        ; Write to register 10
        ;
        inc	d
        ld	a, (hl)
        inc	h
        WriteToPSGReg	d
        
        ;
        ; Write to register 11
        ;
        inc	d
        ld	a, (hl)
        inc	h
        WriteToPSGReg	d

if      SKIP_R12!=1
        ;
        ; Write to register 12
        ;
        ld	a, (hl)
        inc	h
        inc	d
        WriteToPSGReg	d
endif

        ;
        ; Write to register 5
        ;
        ld	a, (hl)
        inc     e
        WriteToPSGReg	e

        ;
        ; Write to register 13
        ;
        inc	h
        bit	7, (hl)                 ; Test "Continue" bit. If set, do not write to register 13.
        jr	nz, SkipRegister13
        inc     d
        rra
        rra
        rra
        rra
        WriteToPSGReg	d

ReturnFromSkipRegister13:
        ;
        ; Write to register 7
        ;
        ld	a, (hl)
        inc     c
        WriteToPSGReg	c

        ;
        ; Move to the next decrunch buffer and handle buffer loop.
        ;
        ld	hl, (CurrentDecrunchBuffer)
        inc	l
        ld	a, h
        cp	DECRUNCH_BUFFER_ADDR_HIGH + NR_REGISTERS_TO_DECRUNCH - 1
        jr	nz, SkipBufferReset

        ; Loop back to the first decrunch buffer.
        ld	bc, DecrunchSavedState
        ld	(ReLoadDecrunchSavedState), bc
        ld	h, DECRUNCH_BUFFER_ADDR_HIGH
ReturnFromSkipBufferReset:
        ld	(CurrentDecrunchBuffer), hl

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
WaitLoop
        dec	a
        jr	nz, WaitLoop
        jr	ReturnFromSkipRegister13

        ;
        ; Wait loop for constant time if there is no need to reset decrunch buffers
        ;
SkipBufferReset:
        ds	6
        inc	h
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
