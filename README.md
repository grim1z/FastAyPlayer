A Fucking Fast Ay Player
=========================

The Fast Ay Player (FAP) is a constant-time, ultra-fast music player for Amstrad CPC.
It consists of:
 * A Windows or Linux executable used to crunch YM music files.
 * Two Z80 binaries (the effective player and an initialization routine). These binaries have been
   precompiled for you. But you can recompile them if needed.

Main features:
 * Very low execution time: from 592 NOPS (9 scanlines + 16 NOPS) to 640 NOPS (10 scanlines), depending on the song.
 * Very easy to use: player is precompiled, PIC (Position Independent Code) and does not need to be specialized or configured for the song. Music data is position independent.
 * Reasonable memory usage.

Step 1: YM file crunching
-------------------------

The first step in order to use FAP is to crunch an YM file using the PC executable.

In a Windows command shell, type the following command:

```shell
C:\> FapCrunch.exe MySourceFile.ym MyDestinationFile.fap
```

On a Linux machine, type the following command:
```shell
user@site:~$ FapCrunch MySourceFile.ym MyDestinationFile.fap
```

The resulting *.fap* file is the music data file to use on the CPC machine.

### Frame shifting options

If the "*play time*" displayed by the cruncher is greater than 592 NOPS, you can try using one of the
following options:

 * **-1**: Allow the modification of less than 0.5% of frames.
 * **-2**: Allow the modification of less than 1% of frames.

Example:
```shell
C:\> FapCrunch.exe MySourceFile.ym MyDestinationFile.fap -1
```

By using one of these options, you allow the cruncher to shift the programming of certain registers by a few frames.
These shifts have been calibrated to be rare enough not to be audible.

The execution time reduction will depend on the YM source file.

Step 2: Memory setup
--------------------

The second step is to setup the memory of the CPC with all the needed stuff. 4 items must be setup
in memory: 
 * **Initialization code binary** (*fapinit.bin*): it can be located anywhere in memory since the code
   has been designed to be PIC (Position Idependant Code).
	* **Size: 335 bytes**
 * **Player code binary** (*fapplay.bin*): it can be located anywhere in memory since the code is
   relocated by the initialization code.
	* **Size: 609 bytes**
 * **Music data** (*.fap* file): it can be located anywhere in memory. There is, however, one constraint:
   <u>**all of the music data must fit below address #8000 or above address #8000**</u>, NOT overlapping address
   #8000. This is due to an optimization which uses the most significant bit of the address to store an
   internal flag. Thus, this bit must be 0 or 1 for every address of the music data.
	* **Size: variable, depends on the YM source file**
 * **Decrunch buffers**: the player needs some memory to store YM decrunched values. This buffer can be
	located anywhere in memory. Only one constraint: <u>**the low order byte of the address must be equal
	to 0**</u>.
	* **Size: #B42 for most musics. #C48 in very uncommon situations. The cruncher tells you the size to use**

Step 3: Player initialization
-----------------------------

Once everything has been stored in memory, you must initialize the player. To do so, you have to call
the initialization code, with the following registers set as follows:
  * **A** = high order byte of the address of the decrunch buffer (low address is 0).
  * **BC** = address of the player code.
  * **DE** = return address. The player is not called using the *CALL* instruction, but with *JP*. So, you have to
	tell the player where to return after playing one music frame.
  * **HL** = Address of music data.

Once the player is initialized, the initialization code is no more needed (unless you want to initialize another song later).
So, you can freely overwrite it if you need some extra memory.

Step 4: Let's play!
-------------------

Here we are, you can now call the player, one time par frame. But beware of the calling convention:
  * Use *JP* to call the player, not *CALL*
  * The SP register is trashed by the player, so backup the register before the *JP* if necessary.
 
Full example
------------

Here is a full example using the RASM syntax. Let's suppose we have generated a "music.fap" file using the cruncher.

To optimize memory, decrunch buffers, player code and data follow each other in memory without any gap. Moreover,
the init code has been stored on the default video memory area, since we assume we will reuse this memory area later on to 
display very cool video effects.

```asm
    ORG	#3000      
    RUN	$

    FapInit	equ #C000       ; Address of the player initialization code.
    FapBuff	equ #4000       ; Address of the decrunch buffers (low order byte MUST BE 0).
    FapPlay	equ #4B42       ; Address of the player code.
    FapData	equ #4DA3       ; Address of the music data. For this address, music data must be < 12893 bytes to avoid crossing the #8000 address (read above).

    ;
    ; You known the story ;)
    ;
    ld	hl, #C9FB
    ld	(#38), hl

    ;
    ; Initialize the player.
    ; Once the player is initialized, you can overwrite the init code if you need some extra memory.
    ;
    ld	a, hi(FapBuff)	; High byte of the decrunch buffer address.
    ld	bc, FapPlay     ; Address of the player binary.
    ld	de, ReturnAddr  ; Address to jump after playing a song frame.
    ld	hl, FapData     ; Address of song data.
    call    FapInit

    ;
    ; Main loop
    ;
MainLoop:
    ld	b, #F5
    in	a, (c)
    rra
    jr	nc, MainLoop
      
    di
    ld	(SaveSp), sp
    jp	FapPlay
ReturnAddr:
SaveSp = $+1
    ld	sp, 0
    ei

    halt ; Wait to make sure the VBL is over.
    halt

    jp	MainLoop

    ;
    ; Load files
    ;
    org	FapInit: incbin "out/fapinit.bin"
    org	FapPlay: incbin "out/fapplay.bin"
    org	FapData: incbin "results/v7/From_Scratch-Part1.ayc"
```

Performance
-----------

The player performance depends on:
 * The maximum number of registers to program in a song frame.
 * Is register 12 constant?

If the register 12 is not constant, the player will be slower. This is a very uncommon situation.
However, if you run into this problem, your musician can probably adjust their song a bit to keep R12 constant.

If the execution play time specified by the cruncher is higher than 592 NOPS, you can consider using frame
shifting options (see above).
| Max reg to program | R12 constant | R12 NOT constant |
|:------------------:|:------------:|:----------------:|
|         11         |     592      |         -        |
|         12         |     616      |         X        |
|         13         |     640      |         X        |
|         14         |      -       |         X        |

Credits
-------

 * Idea and original Z80 code: Hicks/Vanity
 * Z80 optimizations, PIC and relocation adaptation, cruncher and packaging: Gozeur/Contrast
