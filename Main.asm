;
;   *** AY streamer ***
;
;       by Hicks/Vanity
;          02.2024

      BANKSET 0
      BULDSNA

      ORG	#A000      
      RUN	$

      adr_play	equ #4000        ; code player (<&400)
      buf_ayc	equ #7000        ; buffers decrunch (&e00 max)
      adr_ayc	equ #5000

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
      ld	( #38), hl
             
      ld	bc, #7FC0
      out	(c), c
                 

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

;      org	adr_ayc: incbin "resources/Cybernoid.ayc"
      org	adr_ayc: incbin "results/v4/Short-Loop0.ayc"
;     org	adr_ayc: incbin "results/v4/From_Scratch-Part1.ayc"
;	org	adr_ayc: incbin "results/v6/Hocus_Pocus.ayc"
;      org	adr_ayc: incbin "results/v4/Midline_Process-Carpet.ayc"
;      org	adr_ayc: incbin "results/v1/Orion_Prime-Introduction.ayc"
;      org	adr_ayc: incbin "results/v1/Sudoku_Theme1.ayc"
;      org	adr_ayc: incbin "results/v1/cybernoid.ayc"
;     org	adr_ayc: incbin "resources/hicks-ayc/Hocus-Hicks.ayc"
      print	"Data size:", $-adr_ayc

      save    "player.bin", #4000, #4200, DSK, 'Hicks.dsk'
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