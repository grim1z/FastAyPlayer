;
;   *** AY streamer ***
;
;       by Hicks/Vanity
;          02.2024

      BANKSET 0
      BULDSNA

      ORG	#3000      
      RUN	$

      adr_play	equ #3300        ; code player (<&400)
      buf_ayc	equ #C000        ; buffers decrunch (&e00 max)
      adr_ayc	equ #3800

      _HicksPlayer	= 1

      include "../Sanity/macros/Macros.mac"

;
; --- Macros ---
;

if    _HicksPlayer

      ; * Init player *
MACRO	ini_play ReturnAddr
      ld	hl, adr_ayc
      ld	ix, {ReturnAddr}
      call	adr_play
MEND

      ; * Exe player *               
      MACRO	exe_play
            jp	adr_play + 3          
      MEND

else

      ; * Init player *
      MACRO	ini_play Foo
            ld	hl, #4000
            call #3000
      MEND

      ; * Exe player *               
      MACRO	exe_play
            call #3003
      MEND

endif

; * Visu temps machine *
MACRO set_tm Pen, Ink
      ld	bc, #7F00 + {Pen}
      out	(c), c
      ld	c, {Ink}
      out	(c), c                                        
MEND

;
;  ----- Code start here! -----
;

start_code

      ld	hl, #C9FB
      ld	(#38), hl
             
      ld	bc, #7FC0
      out	(c), c

      ld	sp, #2F00

      di
      ini_play	ExecPlayReturn
      ei
          
;
;        Main loop
;

main_loop

      ld	b, #F5

novbl
      in	a, (c)
      rra
      jr	c, novbl
                              
vbl
      in	a, (c)
      rra
      jr	nc, vbl


; - Synchro sur un debut/fin visible -

      halt
      ld	b, 0
      djnz	$
      djnz	$
      ld	b, 202
      djnz	$
                                                            
; - Exe player -

      di
      ld	(savSp + 1), sp
      set_tm	#10, 88

breakpoint
      exe_play	(void)      ; Temps de base Hcks: 924 NOPS
                              ; Temps de base AKY : 1182
ExecPlayReturn:
breakpoint
      set_tm	#10, 84

savSp:
      ld	sp, 0
      ei

      jp	main_loop

if    _HicksPlayer

      org	adr_play
      include     "HicksPlayer.asm"
      print	"Player size:", $-adr_play


;      org	adr_ayc: incbin "results/v5/Short-Loop0.ayc"
;      org	adr_ayc: incbin "results/v5/From_Scratch-Part1.ayc"               ; 1:08      - Const: 12
;      org	adr_ayc: incbin "results/v5/Hocus_Pocus.ayc"                      ; 2:21      - Const: -
;      org	adr_ayc: incbin "results/v5/cybernoid.ayc"                        ; 2:21      - Const: 5, 11, 12, 13
;      org	adr_ayc: incbin "results/v5/Orion_Prime-Introduction.ayc"         ; 3:47      - Const: 12
;      org	adr_ayc: incbin "results/v5/Midline_Process-Carpet.ayc"           ; 5:22      - Const: 12
;      org	adr_ayc: incbin "results/v5/Sudoku_Theme1.ayc"                    ; 7:17      - Const: 12
      org	adr_ayc: incbin "results/v5/Boblines.ayc"                         ; 1:17      - Const: 12
;      org	adr_ayc: incbin "results/v5/Fractal.ayc"                          ; 3:33      - Const: 12
;      org	adr_ayc: incbin "results/v5/Renegade.ayc"                         ; 9:38      - Const: 12
;      org	adr_ayc: incbin "results/v5/Solarium.ayc"                         ; 0:51      - Const: 12
;      org	adr_ayc: incbin "results/v5/Wireshar.ayc"                         ; 2:52      - Const: 12
;      org	adr_ayc: incbin "results/v5/Alienall.ayc"                         ; 1:59      - Const: 12
;      org	adr_ayc: incbin "results/v5/Boules_et_bits.ayc"                   ; 3:04      - Const: 12
;      org	adr_ayc: incbin "results/v5/Deep_space.ayc"                       ; 4:17      - Const: 12
;      org   adr_ayc: incbin "results/v5/Excellence_in_art.ayc"               ; 2:48      - Const: 12
;      org	adr_ayc: incbin "results/v5/Harmless_grenade.ayc"                 ; 1:01      - Const: 12

;      org	adr_ayc: incbin "resources/Cybernoid.ayc"
;     org	adr_ayc: incbin "resources/hicks-ayc/Hocus-Hicks.ayc"

      print	"Data size:", $-adr_ayc

      save    "player.bin", #3000, #5000, DSK, 'Player.dsk'
else

      org	#3000
      include     "AKY/PlayerAky.asm"
; include "AKY/PlayerAkyStabilized_CPC.asm"
      print	"Player size:", $-#3000

      org	#4000: incbin "AKY/Hocus_Pocus.aky"
;      org	#4000: incbin "AKY/From_Scratch_Part_1.aky"
      print	"Data size:", $-#4000

 ;     save    "player.bin", #3000, #5200, DSK, 'aky.dsk'
endif