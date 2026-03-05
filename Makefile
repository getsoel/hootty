.PHONY: build test run debug setup release install uninstall

APP_NAME := Hootty
BUILD_DIR := .build/release
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
INSTALL_DIR := /Applications

build:
	swift build

test:
	swift test

run:
	swift run Hootty

debug:
	log stream --predicate 'subsystem == "com.soel.hootty"' --level debug &
	swift run Hootty; kill %1 2>/dev/null || true

setup:
	git config core.hooksPath .githooks

release:
	swift build -c release
	rm -rf "$(APP_BUNDLE)"
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	cp "$(BUILD_DIR)/$(APP_NAME)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	cp Sources/Hootty/Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	@echo "Built $(APP_BUNDLE)"

install: release
	cp -R "$(APP_BUNDLE)" "$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "Installed to $(INSTALL_DIR)/$(APP_NAME).app"

uninstall:
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "Removed $(INSTALL_DIR)/$(APP_NAME).app"
