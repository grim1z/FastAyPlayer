RASM = rasm

ifeq "$(shell uname)" "Darwin" 
 FAP_CRUNCH = $(BUILD_DIR)/FapCrunchMac
 else
 FAP_CRUNCH = $(BUILD_DIR)/FapCrunchLin
endif

#
# Define directories
#
BUILD_DIR = Build
PLAYER_DIR = FapPlayer
EXAMPLE_DIR = Example

#
# Define targets
#
TEST_TARGET = FapTest
PLAYER_TARGET = $(BUILD_DIR)/fap-play.bin
ifeq "$(shell uname)" "Darwin" 
 CRUNCHER_TARGET = $(BUILD_DIR)/FapCrunchMac
 else
 CRUNCHER_TARGET = $(BUILD_DIR)/FapCrunchLin
endif
RELEASE_TARGET = FapRelease.zip

#
# Targets shortcuts
#
player: $(PLAYER_TARGET)
cruncher: $(CRUNCHER_TARGET)
release: $(RELEASE_TARGET)
test: $(TEST_TARGET).sna

#
# Build rules
#
$(CRUNCHER_TARGET): FapCrunch/*.cpp FapCrunch/*.h
	mkdir -p $(BUILD_DIR)
	g++ -std=c++11 $(CFLAGS) FapCrunch/*.cpp -o $(CRUNCHER_TARGET)

$(PLAYER_TARGET): $(PLAYER_DIR)/Fap*.asm
	mkdir -p $(BUILD_DIR)
	rasm -d -v -void -twe -xr -eo $(PLAYER_DIR)/FapMain.asm /tmp/player.bin

$(RELEASE_TARGET): player cruncher
	cp -f ../README.md $(BUILD_DIR)
#       FapCrunchWin.exe must be built on a windows machine. TODO: use MinGW for a cross-compilation from Linux.
	cp -f Release/FapCrunchWin.exe $(BUILD_DIR)
	zip $(RELEASE_TARGET) $(BUILD_DIR)/*

$(TEST_TARGET).sna: $(EXAMPLE_DIR)/FapTest.asm player
	mkdir -p $(BUILD_DIR)
	rasm -d -v -ss -sb -sa -void -twe -xr -eo $(EXAMPLE_DIR)/FapTest.asm $(TEST_TARGET)

clean:
	rm -rf $(BUILD_DIR) $(PLAYER_TARGET) $(CRUNCHER_TARGET) $(RELEASE_TARGET) *.sna

ym:
	$(FAP_CRUNCH) "Samples/ym/FenyxKell - Bobline.ym" "Samples/fap/FenyxKell - Bobline.fap"
	$(FAP_CRUNCH) "Samples/ym/Targhan - Hocus Pocus.ym" "Samples/fap/Targhan - Hocus Pocus.fap"
	$(FAP_CRUNCH) "Samples/ym/Tom&Jerry - From Scratch - Part 1.ym" "Samples/fap/Tom&Jerry - From Scratch - Part 1.fap"
	$(FAP_CRUNCH) "Samples/ym/Targhan - A Harmless Grenade.ym" "Samples/fap/Targhan - A Harmless Grenade.fap"
	$(FAP_CRUNCH) "Samples/ym/Tom&Jerry - Boules Et Bits (Extended).ym" "Samples/fap/Tom&Jerry - Boules Et Bits (Extended).fap"
	$(FAP_CRUNCH) "Samples/ym/UltraSyd - Fractal.ym" "Samples/fap/UltraSyd - Fractal.fap"
