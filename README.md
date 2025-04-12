A Fast AY Player
================

FAP (Fast AY Player) is a **constant-excecution-time** and **ultra-fast** (10 raster-lines at most) AY3-891x
music player for the [Amstrad CPC](https://www.cpcwiki.eu/index.php/CPC).

Written by **Hicks/Vanity** and **Gozeur/Contrast**.

# Table of Contents
1. [Overview](#Overview)
2. [Usage](#Usage)
3. [Full example](#Full-example)
4. [Performance](#Performance)
5. [Memory considerations](#Memory-considerations)
6. [Credits](#Credits)

Overview
--------

FAP consists of:
 * A Windows and a Linux executable used to crunch YM music files.
 * Two Z80 binaries (the effective player and an initialization routine). These binaries have been
   precompiled for you. But you can recompile them if needed.

Main features:
 * Very low execution time: from 592 NOPS (9 scanlines + 16 NOPS) to 640 NOPS (10 scanlines), depending on the song.
 * Very easy to use: player is precompiled, PIC (Position Independent Code) and does not need to be specialized or configured for the song. Music data is position independent.

Usage
-----
### Step 1: Create a FAP music-file from an YM file

The first step in order to use FAP is to crunch an YM file using the PC executable.
The cruncher takes two arguments: an _YM_ and a _FAP_ file-paths, and one optional argument (see "*frame shifting options*" below).

In a Windows command shell, type the following command:
```shell
C:\> FapCrunchWin.exe path/to/input.ym path/to/output.fap [-1 or -2]
```

On a Linux machine, type the following command:
```shell
user@site:~$ FapCrunchLin path/to/input.ym path/to/output.fap [-1 or -2]
```

#### Frame shifting options

After crunching an _YM_ file, if the _Play time_ indicated is greater than **592 NOPs**, you may allow the cruncher
to re-arrange the audio-frame data to optimize for CPU-cycles on the music-replay side:

 - `-1`: re-arrange at most 0.5% of the audio-frames.
 - `-2`: re-arrange at most 1% of the audio-frames.

In any cases, the changes will be kept at a minimum and should not be audible.
The execution time reduction is not guaranted, since it depends on the YM data.
 
### Step 2: Memory setup

The second step is to setup the various elements needed in memory to replay a FAP music file:

 * **Initialization routine**\
   It can be located anywhere in memory. It is a fully Position Independant Code (PIC).
	* A precompiled version is provided in the release archive: *fap-init.bin*
 	* **Size: `335` bytes**
 * **Player code**\
   It can be located anywhere in memory since the code is relocated by the initialization routine.
	* A precompiled version is provided in the release archive: *fap-play.bin*
	* **Size: `609` bytes**
 * **Music data**\
   The *fap* file can be located anywhere in memory but **it must** be fully located either between `[#0000-#7FFF]` or `[#8000-#FFFF]` and **never cross over the `#8000` boundary**.
	* **Size: variable with a maximum of 32Kb**
 * **Replay buffers**\
   For internal usage, the player needs some extra memory. The cruncher will indicate which buffer-size is required. It can be located anywhere in memory but **it must be aligned on a `#100` byte memory address boundary** (i.e. low byte of the address is `#00`).
	* Size usually is `#B42` bytes up to `#C48` bytes on rare occasions.

### Step 3: Player initialization

Finally, the player must be initialized in order to know where all the things are located in memory.
We will pass all these information to the init-routine through Z80 registers as follow:
  * **`A`** = Most significant byte of the buffer address.
  * **`BC`** = Address of the player routine.
  * **`DE`** = Address where the player will jump back into your program.
  * **`HL`** = Address of the FAP music data.

### Step 4: Let's play!

Here we are, you can now call the player, one time par frame.

For psychopathic optimization reasons, the replay routine will abuse the stack-pointer. Therefore, **it must be jumped into** and not called (ie. `JP FapPlay` instead of the usual  `CALL FapPlay`). It also **must not be interrupted**.
When its done, it will **jump back to your program** at the return address given to the player initialization-routine. **And it's up to you to save and restore the stack-pointer** (`SP`).
 
Full example
------------

Here is a full example using the RASM syntax. Let's suppose we have generated a "music.fap" file using the cruncher.

To optimize memory, decrunch buffers, player code and data follow each other in memory without any gap. Moreover,
the init code has been stored on the default video memory area, since we assume we will reuse this memory area later on to 
display very cool video effects.

```asm
    ORG	#3000      
    RUN	$

    BuffSize	equ #B42		; Size of replay buffer given by the cruncher.
    PlayerSize	equ 609			; Size of the FAP player code

    FapInit	equ #C000       	; Address of the player initialization code.
    FapBuff	equ #4000       	; Address of the decrunch buffers (low order byte MUST BE 0).
    FapPlay	equ FapBuff+BuffSize  	; Address of the player code. Right after the decrunch buffer.
    FapData	equ FapPlay+PlayerSize	; Address of the music data. Right after the player routine.

    ;
    ; You known the story ;)
    ;
    ld	hl, #C9FB
    ld	(#38), hl

    ;
    ; Initialize the player.
    ; Once the player is initialized, you can overwrite the init code if you need some extra memory.
    ;
    di			; coz FapInit makes heavy use of SP
    ld	a, hi(FapBuff)	; High byte of the decrunch buffer address.
    ld	bc, FapPlay     ; Address of the player binary.
    ld	de, ReturnAddr  ; Address to jump after playing a song frame.
    ld	hl, FapData     ; Address of song data.
    call    FapInit
    ei

    ;
    ; Main loop
    ;
MainLoop:
    ld	b, #F5
    in	a, (c)
    rra
    jr	nc, MainLoop

    di			; Prevent interrupt apocalypse
    ld	(RestoreSp), sp	; Save our precious stack-pointer
    jp	FapPlay		; Jump into the replay-routine

ReturnAddr:		; Return address the replay-routine will jump back to

RestoreSp = $+1
    ld	sp, 0		; Restore our precious stack-pointer
    ei			; We may enable the maskable interrupts again

    halt		; Wait to make sure the VBL is over.
    halt

    jp	MainLoop

    ;
    ; Load files
    ;
    org	FapInit: incbin "out/fapinit.bin"
    org	FapPlay: incbin "out/fapplay.bin"
    org	FapData: incbin "music.fap"
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

The following table presents the performance (in NOPS) of the player depending on the maximum number of registers to
program per frame and the register 12 "constantness".

| Max reg to program | R12 constant | R12 NOT constant |
|:------------------:|:------------:|:----------------:|
|         11         |     592      |        660       |
|         12         |     616      |        684       |
|         13         |     640      |        708       |
|         14         |      -       |        732       |

Memory considerations
---------------------

  * Music data size:\
    The music data size depends on the given YM file and the optional usage of the cruncher *frame shifting option*. On average, a FAP file size is between 2Kb and 4Kb per minute.\
    If saving disk space is important for you, you can concider crunching a FAP file. On average, crunching a FAP file using an *LZ-like* algorithm reduces its size by 50%.

  * Initialisation code:\
    If you only want to replay a single music, the init-routine can be completely disposed of right after being used (eg. put it where it can happily be overwritten with something else, such as video-ram).

  * Music data header:\
    If you need a few extra bytes in memory to achieve your killing effect, you might consider overwriting the FAP data header. After calling the initialization-routine, you can freely overwrite the first 28 bytes of the music data.

Credits
-------

 * Idea and original Z80 code: Hicks/Vanity.
 * Z80 optimizations, PIC and relocation adaptation, cruncher, packaging and documentation: Gozeur/Contrast.
 * Support and testing: Targhan/Arkos, Grim/Arkos, Tom's/Pulpo Corrosivo, Tom et Jerry/GPA, Zik/Futurs.
