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
	$(FAP_CRUNCH) "Resources/ym/FenyxKell - Bobline.ym" "Resources/fap/FenyxKell - Bobline.fap"
	$(FAP_CRUNCH) "Resources/ym/Targhan - Hocus Pocus.ym" "Resources/fap/Targhan - Hocus Pocus.fap"
	$(FAP_CRUNCH) "Resources/ym/Tom&Jerry - From Scratch - Part 1.ym" "Resources/fap/Tom&Jerry - From Scratch - Part 1.fap"
	$(FAP_CRUNCH) "Resources/ym/Targhan - A Harmless Grenade.ym" "Resources/fap/Targhan - A Harmless Grenade.fap"
	$(FAP_CRUNCH) "Resources/ym/Tom&Jerry - Boules Et Bits (Extended).ym" "Resources/fap/Tom&Jerry - Boules Et Bits (Extended).fap"
	$(FAP_CRUNCH) "Resources/ym/UltraSyd - Fractal.ym" "Resources/fap/UltraSyd - Fractal.fap"
