ACE = /opt/tools/cpc/ACE/AceDL
RASM = rasm

TARGET = out/TestZic.sna
ASM_SRC = $(shell find . -name '*.asm' -o -name '*.mac')

all: $(TARGET)

$(TARGET): $(ASM_SRC)
	mkdir -p out
ifdef WSL_DISTRO_NAME
	cmd.exe /c "D:\Dropbox\RetroGaming\CPC\rasm.exe -v -void -twe -xr -sb -ss -sa Main.asm -oi $(TARGET)"
else
	rasm -d -v -void -twe -xr -sb -ss -sa Main.asm -oi $(TARGET)
endif

clean:
	rm -f out/*

run:
ifdef WSL_DISTRO_NAME
	cmd.exe /c "D:\Dropbox\RetroGaming\CPC\AceDL\AceDL.exe -crtc 1 -ffr $(TARGET)"
else
	$(ACE) -crtc 1 -ffr $(TARGET)
endif

ym:
	./script/Ym2Hicks.py resources/src-ym/From_Scratch-Part1.ym results/v5/From_Scratch-Part1.ayc
	./script/Ym2Hicks.py resources/src-ym/Hocus_Pocus.ym results/v5/Hocus_Pocus.ayc
	./script/Ym2Hicks.py resources/src-ym/cybernoid.ym results/v5/cybernoid.ayc
	./script/Ym2Hicks.py resources/src-ym/Orion_Prime-Introduction.ym results/v5/Orion_Prime-Introduction.ayc
	./script/Ym2Hicks.py resources/src-ym/Midline_Process-Carpet.ym results/v5/Midline_Process-Carpet.ayc
	./script/Ym2Hicks.py resources/src-ym/Sudoku_Theme1.ym results/v5/Sudoku_Theme1.ayc
	./script/Ym2Hicks.py resources/src-ym/Boblines.ym results/v5/Boblines.ayc
	./script/Ym2Hicks.py resources/src-ym/Fractal.ym results/v5/Fractal.ayc
	./script/Ym2Hicks.py resources/src-ym/Renegade.ym results/v5/Renegade.ayc
	./script/Ym2Hicks.py resources/src-ym/Solarium.ym results/v5/Solarium.ayc

#        ./script/Ym2Hicks.py resources/src-ym/Short-Loop0.ym results/v5/Short-Loop0.ayc
#        ./script/Ym2Hicks.py resources/src-ym/Short-Loop1.ym results/v5/Short-Loop1.ayc
#        ./script/Ym2Hicks.py resources/src-ym/Short-Loop2.ym results/v5/Short-Loop2.ayc
#        ./script/Ym2Hicks.py resources/src-ym/Short-Loop3.ym results/v5/Short-Loop3.ayc
#        ./script/Ym2Hicks.py resources/src-ym/Short-Loop4.ym results/v5/Short-Loop4.ayc
#        ./script/Ym2Hicks.py resources/src-ym/Short-Loop5.ym results/v5/Short-Loop5.ayc
#        ./script/Ym2Hicks.py resources/src-ym/Short-Loop6.ym results/v5/Short-Loop6.ayc
#        ./script/Ym2Hicks.py resources/src-ym/Short-Loop7.ym results/v5/Short-Loop7.ayc
#        ./script/Ym2Hicks.py resources/src-ym/Short-Loop8.ym results/v5/Short-Loop8.ayc
#        ./script/Ym2Hicks.py resources/src-ym/Short-Loop9.ym results/v5/Short-Loop9.ayc
#        ./script/Ym2Hicks.py resources/src-ym/Short-Loop10.ym results/v5/Short-Loop10.ayc
