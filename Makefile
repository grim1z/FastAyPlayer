ACE = /opt/tools/cpc/ACE/AceDL
RASM = rasm

TARGET = out/TestZic.sna

all: $(TARGET)

$(TARGET): Test.asm out/fapinit.bin
	mkdir -p out
ifdef WSL_DISTRO_NAME
	cmd.exe /c "D:\Dropbox\RetroGaming\CPC\rasm.exe -v -ss -sb -sa -void -twe -xr -eo Test.asm -oi $(TARGET)"
else
	rasm -d -v -ss -sb -sa -void -twe -xr -eo Test.asm -oi $(TARGET)
endif

out/fapinit.bin: Fap*.asm
	mkdir -p out
ifdef WSL_DISTRO_NAME
	cmd.exe /c "D:\Dropbox\RetroGaming\CPC\rasm.exe -v -void -twe -xr -eo FapMain.asm -oi /tmp/player.bin"
else
	rasm -d -v -void -twe -xr -eo FapMain.asm -oi /tmp/player.bin
endif


clean:
	rm -f out/*

run:
ifdef WSL_DISTRO_NAME
	cmd.exe /c "D:\Dropbox\RetroGaming\CPC\AceDL\AceDL.exe -crtc 1 -ffr $(TARGET)"
else
	$(ACE) -crtc 1 -ffr $(TARGET)
endif

dsk:
ifdef WSL_DISTRO_NAME
	cmd.exe /c "D:\Dropbox\RetroGaming\CPC\AceDL\AceDL.exe -crtc 1 -ffr Player.dsk"
else
	$(ACE) -crtc 1 -ffr Player.dsk
endif

ym:
	./script/Ym2Hicks.py resources/src-ym/From_Scratch-Part1.ym results/v5/From_Scratch-Part1.ayc
#	./script/Ym2Hicks.py resources/src-ym/Hocus_Pocus.ym results/v5/Hocus_Pocus.ayc -O
#	./script/Ym2Hicks.py resources/src-ym/cybernoid.ym results/v5/cybernoid.ayc -O
#	./script/Ym2Hicks.py resources/src-ym/Orion_Prime-Introduction.ym results/v5/Orion_Prime-Introduction.ayc -O
#	./script/Ym2Hicks.py resources/src-ym/Midline_Process-Carpet.ym results/v5/Midline_Process-Carpet.ayc -O
#	./script/Ym2Hicks.py resources/src-ym/Sudoku_Theme1.ym results/v5/Sudoku_Theme1.ayc -O
#	./script/Ym2Hicks.py resources/src-ym/Boblines.ym results/v5/Boblines.ayc -O
#	./script/Ym2Hicks.py resources/src-ym/Fractal.ym results/v5/Fractal.ayc -O
#	./script/Ym2Hicks.py resources/src-ym/Renegade.ym results/v5/Renegade.ayc -O
#	./script/Ym2Hicks.py resources/src-ym/Solarium.ym results/v5/Solarium.ayc -O
#	./script/Ym2Hicks.py resources/src-ym/Wireshar.ym results/v5/Wireshar.ayc -O
#	./script/Ym2Hicks.py resources/src-ym/Alienall.ym results/v5/Alienall.ayc -O
#	./script/Ym2Hicks.py resources/src-ym/Boules_et_bits.ym results/v5/Boules_et_bits.ayc -O
#	./script/Ym2Hicks.py resources/src-ym/Deep_space.ym results/v5/Deep_space.ayc -O
#	./script/Ym2Hicks.py resources/src-ym/Excellence_in_art.ym results/v5/Excellence_in_art.ayc -O
#	./script/Ym2Hicks.py resources/src-ym/Harmless_grenade.ym results/v5/Harmless_grenade.ayc -O

	./script/Ym2Hicks.py resources/src-ym/Short-Loop0.ym results/v5/Short-Loop0.ayc -O
	./script/Ym2Hicks.py resources/src-ym/Short-Loop1.ym results/v5/Short-Loop1.ayc -O
	./script/Ym2Hicks.py resources/src-ym/Short-Loop2.ym results/v5/Short-Loop2.ayc -O
	./script/Ym2Hicks.py resources/src-ym/Short-Loop3.ym results/v5/Short-Loop3.ayc -O
	./script/Ym2Hicks.py resources/src-ym/Short-Loop4.ym results/v5/Short-Loop4.ayc -O
	./script/Ym2Hicks.py resources/src-ym/Short-Loop5.ym results/v5/Short-Loop5.ayc -O
	./script/Ym2Hicks.py resources/src-ym/Short-Loop6.ym results/v5/Short-Loop6.ayc -O
	./script/Ym2Hicks.py resources/src-ym/Short-Loop7.ym results/v5/Short-Loop7.ayc -O
	./script/Ym2Hicks.py resources/src-ym/Short-Loop8.ym results/v5/Short-Loop8.ayc -O
	./script/Ym2Hicks.py resources/src-ym/Short-Loop9.ym results/v5/Short-Loop9.ayc -O
	./script/Ym2Hicks.py resources/src-ym/Short-Loop10.ym results/v5/Short-Loop10.ayc -O
