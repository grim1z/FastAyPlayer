;
;       Fucking Fast AY Player - 2024
;         by Hicks/Vanity and Gozeur
;

        org	#0000
        
        include	"FapMacro.asm"

FapPlay:
        include	"FapPlay.asm"
        print	"FAP Player size: ", $-FapPlay
        save	"Release/fapplay.bin", FapPlay, $-FapPlay

FapInit:
        include	"FapInit.asm"
        print	"FAP Init code size: ", $-FapInit
        save	"Release/fapinit.bin", FapInit, $-FapInit
