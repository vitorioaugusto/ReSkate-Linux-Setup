CC ?= gcc
CFLAGS ?= -O2 -Wall -Wextra
TARGET := ReSkate-Setup-x86_64
BUILD_DIR := build
SCRIPT := scripts/reskate-setup.sh
HEADER := $(BUILD_DIR)/embedded_setup.h
LAUNCHER := src/launcher.c
EMBED := src/embed.py

.PHONY: all clean static

all: $(TARGET)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(HEADER): $(SCRIPT) $(EMBED) | $(BUILD_DIR)
	python3 $(EMBED) $(SCRIPT) $(HEADER)

$(TARGET): $(LAUNCHER) $(HEADER)
	$(CC) $(CFLAGS) -I$(BUILD_DIR) -s -o $@ $(LAUNCHER)

static: $(LAUNCHER) $(HEADER)
	$(CC) $(CFLAGS) -I$(BUILD_DIR) -static -s -o $(TARGET) $(LAUNCHER)

clean:
	rm -rf $(BUILD_DIR) $(TARGET)
