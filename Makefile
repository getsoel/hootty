.PHONY: build test run debug setup release install uninstall

APP_NAME := Hootty
INSTALL_DIR := /Applications
DERIVED_DATA := .build/DerivedData
DEBUG_PRODUCTS := $(DERIVED_DATA)/Build/Products/Debug
RELEASE_PRODUCTS := $(DERIVED_DATA)/Build/Products/Release
RELEASE_APP_BUNDLE := .build/release/$(APP_NAME).app

XCODEBUILD := xcodebuild -scheme $(APP_NAME) -destination 'platform=macOS' -derivedDataPath $(DERIVED_DATA)

build:
	$(XCODEBUILD) -configuration Debug build

test:
	swift test

run: build
	"$(DEBUG_PRODUCTS)/$(APP_NAME)"

debug: build
	log stream --predicate 'subsystem == "com.soel.hootty"' --level debug &
	"$(DEBUG_PRODUCTS)/$(APP_NAME)"; kill %1 2>/dev/null || true

setup:
	git config core.hooksPath .githooks

release:
	$(XCODEBUILD) -configuration Release build
	rm -rf "$(RELEASE_APP_BUNDLE)"
	mkdir -p "$(RELEASE_APP_BUNDLE)/Contents/MacOS"
	mkdir -p "$(RELEASE_APP_BUNDLE)/Contents/Resources"
	cp "$(RELEASE_PRODUCTS)/$(APP_NAME)" "$(RELEASE_APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	cp Sources/Hootty/Info.plist "$(RELEASE_APP_BUNDLE)/Contents/Info.plist"
	cp -R Assets/AppIcon.icon "$(RELEASE_APP_BUNDLE)/Contents/Resources/AppIcon.icon"
	@echo "Built $(RELEASE_APP_BUNDLE)"

install: release
	-killall -w $(APP_NAME) 2>/dev/null || true
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	cp -R "$(RELEASE_APP_BUNDLE)" "$(INSTALL_DIR)/$(APP_NAME).app"
	/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "Installed to $(INSTALL_DIR)/$(APP_NAME).app"

uninstall:
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "Removed $(INSTALL_DIR)/$(APP_NAME).app"
