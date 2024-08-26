RASM = rasm

BUILD_DIR = Build
PLAYER_DIR = FapPlayer
EXAMPLE_DIR = Example

FAP_CRUNCH = $(BUILD_DIR)/FapCrunchLin
TEST_TARGET = TestZic
PLAYER_TARGET = $(BUILD_DIR)/fap-play.bin
CRUNCHER_TARGET = $(BUILD_DIR)/FapCrunchLin
RELEASE_TARGET = FapRelease.zip

TARGETS = $(PLAYER_TARGET) $(CRUNCHER_TARGET) $(TEST_TARGET) $(RELEASE_TARGET)

all: $(TARGETS)

$(RELEASE_TARGET): $(PLAYER_TARGET) $(CRUNCHER_TARGET)
	cp -f ../README.md $(BUILD_DIR)
	zip $(RELEASE_TARGET) $(BUILD_DIR)/*

$(CRUNCHER_TARGET): FapCrunch/*.cpp FapCrunch/*.h
	g++ -std=c++11 FapCrunch/*.cpp -o $(CRUNCHER_TARGET)

$(TEST_TARGET): $(EXAMPLE_DIR)/FapTest.asm $(BUILD_DIR)/fap-init.bin
	mkdir -p $(BUILD_DIR)
	rasm -d -v -ss -sb -sa -void -twe -xr -eo $(EXAMPLE_DIR)/FapTest.asm $(TEST_TARGET)

$(PLAYER_TARGET): $(PLAYER_DIR)/Fap*.asm
	mkdir -p $(BUILD_DIR)
	rasm -d -v -void -twe -xr -eo $(PLAYER_DIR)/FapMain.asm /tmp/player.bin

clean:
	rm -rf $(BUILD_DIR) $(TARGETS) *.sna

ym:
	$(FAP_CRUNCH) "Resources/ym/FenyxKell - Bobline.ym" "Resources/fap/FenyxKell - Bobline.fap"
	$(FAP_CRUNCH) "Resources/ym/Targhan - Hocus Pocus.ym" "Resources/fap/Targhan - Hocus Pocus.fap"
	$(FAP_CRUNCH) "Resources/ym/Tom&Jerry - From Scratch - Part 1.ym" "Resources/fap/Tom&Jerry - From Scratch - Part 1.fap"
	$(FAP_CRUNCH) "Resources/ym/Targhan - A Harmless Grenade.ym" "Resources/fap/Targhan - A Harmless Grenade.fap"
	$(FAP_CRUNCH) "Resources/ym/Tom&Jerry - Boules Et Bits (Extended).ym" "Resources/fap/Tom&Jerry - Boules Et Bits (Extended).fap"
	$(FAP_CRUNCH) "Resources/ym/UltraSyd - Fractal.ym" "Resources/fap/UltraSyd - Fractal.fap"
