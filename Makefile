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
	./script/Ym2Hicks.py resources/src-ym/Short-Loop0.ym results/v4/Short-Loop0.ayc
	./script/Ym2Hicks.py resources/src-ym/Short-Loop1.ym results/v4/Short-Loop1.ayc
	./script/Ym2Hicks.py resources/src-ym/From_Scratch-Part1.ym results/v4/From_Scratch-Part1.ayc
	./script/Ym2Hicks.py resources/src-ym/Hocus_Pocus.ym results/v4/Hocus_Pocus.ayc
	./script/Ym2Hicks.py resources/src-ym/cybernoid.ym results/v4/cybernoid.ayc
	./script/Ym2Hicks.py resources/src-ym/Orion_Prime-Introduction.ym results/v4/Orion_Prime-Introduction.ayc
	./script/Ym2Hicks.py resources/src-ym/Midline_Process-Carpet.ym results/v4/Midline_Process-Carpet.ayc
	./script/Ym2Hicks.py resources/src-ym/Sudoku_Theme1.ym results/v4/Sudoku_Theme1.ayc
