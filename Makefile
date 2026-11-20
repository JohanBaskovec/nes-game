# ULTRA DEATH COP III: MAXIMUM JUSTICE — construction de la ROM.
# Prérequis : cc65 (ca65 + ld65) et Python 3.

ROM    := build/udc3.nes
SRC    := $(wildcard src/*.s src/*.inc)
ASSETS := $(wildcard assets/*.txt)

all: $(ROM)

build/assets.inc build/level1.inc build/chr.bin: $(ASSETS) tools/build_assets.py
	python3 tools/build_assets.py

build/main.o: $(SRC) build/assets.inc build/level1.inc build/chr.bin
	ca65 -I src -I build --bin-include-dir build -g src/main.s -o build/main.o

$(ROM): build/main.o cfg/mmc3.cfg
	ld65 -C cfg/mmc3.cfg -o $(ROM) --dbgfile build/udc3.dbg -m build/udc3.map -Ln build/udc3.lbl build/main.o
	@echo "ROM prête : $(ROM)"

clean:
	rm -rf build

.PHONY: all clean
