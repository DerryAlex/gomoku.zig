.PHONY: all

all: pbrain manager human

ZIG ?= zig

pbrain: *.zig lib/*.zig ai/*.zig ai/pattern.bin ai/score.bin
	$(ZIG) build-exe main.zig -O ReleaseSafe
	mv main pbrain

ai/pattern_generator: ai/pattern.zig ai/pattern_generator.zig
	cd ai && $(ZIG) build-exe pattern_generator.zig -O ReleaseFast

ai/pattern.bin ai/score.bin: ai/pattern_generator
	cd ai && ./pattern_generator

lib/referee.a: lib/referee.zig
	cd lib && $(ZIG) build-lib referee.zig -O ReleaseSafe -fPIE

manager: ui/pseudo_manager.c ui/pty.c ui/pty.h lib/referee.a lib/referee.h
	$(CC) ui/pseudo_manager.c ui/pty.c lib/libreferee.a -o manager

human: ui/human.c
	$(CC) ui/human.c -o human
