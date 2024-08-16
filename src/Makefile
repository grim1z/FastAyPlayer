ACE = /opt/tools/cpc/ACE/AceDL
RASM = rasm

BUILD_DIR = Build
PLAYER_DIR = FapPlayer

FAP_CRUNCH = $(BUILD_DIR)/FapCrunchLin
TEST_TARGET = TestZic.sna
PLAYER_TARGET = $(BUILD_DIR)/fapplay.bin
CRUNCHER_TARGET = $(BUILD_DIR)/FapCrunchLin
RELEASE_TARGET = FapRelease.zip

TARGETS = $(PLAYER_TARGET) $(CRUNCHER_TARGET) $(TEST_TARGET) $(RELEASE_TARGET)

all: $(TARGETS)

$(RELEASE_TARGET): $(PLAYER_TARGET) $(CRUNCHER_TARGET)
	cp -f README.md $(BUILD_DIR)
	zip $(RELEASE_TARGET) $(BUILD_DIR)/*

$(CRUNCHER_TARGET): FapCrunch/*.cpp FapCrunch/*.h
	g++ -std=c++11 FapCrunch/*.cpp -o $(CRUNCHER_TARGET)

$(TEST_TARGET): $(PLAYER_DIR)/Test.asm $(BUILD_DIR)/fapinit.bin
	mkdir -p $(BUILD_DIR)
ifdef WSL_DISTRO_NAME
	cmd.exe /c "D:\Dropbox\RetroGaming\CPC\rasm.exe -v -ss -sb -sa -void -twe -xr -eo $(PLAYER_DIR)/Test.asm $(TEST_TARGET)"
else
	rasm -d -v -ss -sb -sa -void -twe -xr -eo $(PLAYER_DIR)/Test.asm $(TEST_TARGET)
endif

$(PLAYER_TARGET): $(PLAYER_DIR)/Fap*.asm
	mkdir -p $(BUILD_DIR)
ifdef WSL_DISTRO_NAME
	cmd.exe /c "D:\Dropbox\RetroGaming\CPC\rasm.exe -v -void -twe -xr -eo $(PLAYER_DIR)/FapMain.asm /tmp/player.bin"
else
	rasm -d -v -void -twe -xr -eo $(PLAYER_DIR)/FapMain.asm /tmp/player.bin
endif

clean:
	rm -rf $(BUILD_DIR) $(TARGETS)

run:
ifdef WSL_DISTRO_NAME
	cmd.exe /c "D:\Dropbox\RetroGaming\CPC\AceDL\AceDL.exe -crtc 1 -ffr $(TEST_TARGET)"
else
	$(ACE) -crtc 1 -ffr $(TEST_TARGET)
endif

dsk:
ifdef WSL_DISTRO_NAME
	cmd.exe /c "D:\Dropbox\RetroGaming\CPC\AceDL\AceDL.exe -crtc 1 -ffr Player.dsk"
else
	$(ACE) -crtc 1 -ffr Player.dsk
endif

ym:
	$(FAP_CRUNCH) resources/src-ym/From_Scratch-Part1.ym results/From_Scratch-Part1.fap
	$(FAP_CRUNCH) resources/src-ym/Hocus_Pocus.ym results/Hocus_Pocus.fap
	$(FAP_CRUNCH) resources/src-ym/cybernoid.ym results/cybernoid.fap
	$(FAP_CRUNCH) resources/src-ym/Orion_Prime-Introduction.ym results/Orion_Prime-Introduction.fap
	$(FAP_CRUNCH) resources/src-ym/Midline_Process-Carpet.ym results/Midline_Process-Carpet.fap
	$(FAP_CRUNCH) resources/src-ym/Sudoku_Theme1.ym results/Sudoku_Theme1.fap
	$(FAP_CRUNCH) resources/src-ym/Boblines.ym results/Boblines.fap
	$(FAP_CRUNCH) resources/src-ym/Fractal.ym results/Fractal.fap
	$(FAP_CRUNCH) resources/src-ym/Renegade.ym results/Renegade.fap
	$(FAP_CRUNCH) resources/src-ym/Solarium.ym results/Solarium.fap
	$(FAP_CRUNCH) resources/src-ym/Wireshar.ym results/Wireshar.fap
	$(FAP_CRUNCH) resources/src-ym/Alienall.ym results/Alienall.fap
	$(FAP_CRUNCH) resources/src-ym/Boules_et_bits.ym results/Boules_et_bits.fap
	$(FAP_CRUNCH) resources/src-ym/Deep_space.ym results/Deep_space.fap
	$(FAP_CRUNCH) resources/src-ym/Excellence_in_art.ym results/Excellence_in_art.fap
	$(FAP_CRUNCH) resources/src-ym/Harmless_grenade.ym results/Harmless_grenade.fap

	$(FAP_CRUNCH) resources/src-ym/Short-Loop0.ym results/Short-Loop0.fap
	$(FAP_CRUNCH) resources/src-ym/Short-Loop1.ym results/Short-Loop1.fap
	$(FAP_CRUNCH) resources/src-ym/Short-Loop2.ym results/Short-Loop2.fap
	$(FAP_CRUNCH) resources/src-ym/Short-Loop3.ym results/Short-Loop3.fap
	$(FAP_CRUNCH) resources/src-ym/Short-Loop4.ym results/Short-Loop4.fap
	$(FAP_CRUNCH) resources/src-ym/Short-Loop5.ym results/Short-Loop5.fap
	$(FAP_CRUNCH) resources/src-ym/Short-Loop6.ym results/Short-Loop6.fap
	$(FAP_CRUNCH) resources/src-ym/Short-Loop7.ym results/Short-Loop7.fap
	$(FAP_CRUNCH) resources/src-ym/Short-Loop8.ym results/Short-Loop8.fap
	$(FAP_CRUNCH) resources/src-ym/Short-Loop9.ym results/Short-Loop9.fap
	$(FAP_CRUNCH) resources/src-ym/Short-Loop10.ym results/Short-Loop10.fap
