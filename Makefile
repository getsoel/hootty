.PHONY: build test run debug setup release dmg install uninstall

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
	./scripts/setup.sh

release:
	$(XCODEBUILD) -configuration Release build
	rm -rf "$(RELEASE_APP_BUNDLE)"
	mkdir -p "$(RELEASE_APP_BUNDLE)/Contents/MacOS"
	mkdir -p "$(RELEASE_APP_BUNDLE)/Contents/Resources"
	cp "$(RELEASE_PRODUCTS)/$(APP_NAME)" "$(RELEASE_APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	cp Sources/Hootty/Info.plist "$(RELEASE_APP_BUNDLE)/Contents/Info.plist"
	cp -R Assets/AppIcon.icon "$(RELEASE_APP_BUNDLE)/Contents/Resources/AppIcon.icon"
	cp -R "$(RELEASE_PRODUCTS)/Hootty_Hootty.bundle" "$(RELEASE_APP_BUNDLE)/Contents/Resources/Hootty_Hootty.bundle"
	codesign -s - --deep --force "$(RELEASE_APP_BUNDLE)"
	@echo "Built $(RELEASE_APP_BUNDLE)"

DMG_NAME := $(APP_NAME).dmg
DMG_STAGING := .build/dmg-staging

dmg: release
	rm -rf "$(DMG_STAGING)" "$(DMG_NAME)"
	mkdir -p "$(DMG_STAGING)"
	cp -R "$(RELEASE_APP_BUNDLE)" "$(DMG_STAGING)/$(APP_NAME).app"
	ln -s /Applications "$(DMG_STAGING)/Applications"
	hdiutil create -volname "$(APP_NAME)" -srcfolder "$(DMG_STAGING)" \
		-ov -format UDZO "$(DMG_NAME)"
	rm -rf "$(DMG_STAGING)"
	@echo "Created $(DMG_NAME)"

install: release
	-killall -w $(APP_NAME) 2>/dev/null || true
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	cp -R "$(RELEASE_APP_BUNDLE)" "$(INSTALL_DIR)/$(APP_NAME).app"
	/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "Installed to $(INSTALL_DIR)/$(APP_NAME).app"

uninstall:
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "Removed $(INSTALL_DIR)/$(APP_NAME).app"
