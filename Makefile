# Lumi Browser - Build & Package Makefile
# Requires: macOS, Xcode 15+, hdiutil (built-in), create-dmg (optional)

APP_NAME     = LumiBrowser
SCHEME       = LumiBrowser
PROJECT      = LumiBrowser.xcodeproj
BUILD_DIR    = build
ARCHIVE_PATH = $(BUILD_DIR)/$(APP_NAME).xcarchive
APP_PATH     = $(BUILD_DIR)/$(APP_NAME).app
DMG_PATH     = $(BUILD_DIR)/$(APP_NAME).dmg
VERSION     := $(shell /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" \
                 "$(APP_NAME)/Resources/Info.plist" 2>/dev/null || echo "1.0.0")

.PHONY: all build archive export dmg clean open help

all: dmg

## Build the app (Debug)
build:
	@echo "▸ Building $(APP_NAME) (Debug)..."
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Debug \
		-derivedDataPath $(BUILD_DIR)/DerivedData \
		build | xcpretty || xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Debug \
		-derivedDataPath $(BUILD_DIR)/DerivedData \
		build
	@echo "✓ Build complete"

## Archive the app (Release)
archive:
	@echo "▸ Archiving $(APP_NAME) (Release)..."
	@mkdir -p $(BUILD_DIR)
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-archivePath $(ARCHIVE_PATH) \
		archive | xcpretty 2>/dev/null || \
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-archivePath $(ARCHIVE_PATH) \
		archive
	@echo "✓ Archive created at $(ARCHIVE_PATH)"

## Export the .app from archive (no code signing required for local distribution)
export: archive
	@echo "▸ Exporting .app..."
	@mkdir -p $(BUILD_DIR)/export
	xcodebuild \
		-exportArchive \
		-archivePath $(ARCHIVE_PATH) \
		-exportPath $(BUILD_DIR)/export \
		-exportOptionsPlist scripts/ExportOptions.plist
	@cp -R "$(BUILD_DIR)/export/$(APP_NAME).app" "$(APP_PATH)"
	@echo "✓ Exported to $(APP_PATH)"

## Build a DMG for distribution
dmg: export
	@echo "▸ Creating DMG..."
	@bash scripts/create-dmg.sh "$(APP_PATH)" "$(DMG_PATH)" "$(APP_NAME)" "$(VERSION)"
	@echo "✓ DMG created at $(DMG_PATH)"

## Quick DMG using hdiutil only (no export step — for testing)
dmg-quick:
	@echo "▸ Creating quick DMG from existing .app..."
	@test -d "$(APP_PATH)" || (echo "Run 'make export' first"; exit 1)
	@bash scripts/create-dmg.sh "$(APP_PATH)" "$(DMG_PATH)" "$(APP_NAME)" "$(VERSION)"
	@echo "✓ DMG created at $(DMG_PATH)"

## Open the project in Xcode
open:
	open $(PROJECT)

## Clean build artifacts
clean:
	@echo "▸ Cleaning build directory..."
	@rm -rf $(BUILD_DIR)
	@echo "✓ Clean complete"

## Run the app (Debug build)
run: build
	@echo "▸ Running $(APP_NAME)..."
	open "$(BUILD_DIR)/DerivedData/Build/Products/Debug/$(APP_NAME).app"

## Show help
help:
	@echo "Lumi Browser Build System"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  all      - Build and package as DMG (default)"
	@echo "  build    - Build Debug configuration"
	@echo "  archive  - Archive Release configuration"
	@echo "  export   - Export .app from archive"
	@echo "  dmg      - Create distributable DMG"
	@echo "  open     - Open project in Xcode"
	@echo "  clean    - Remove build artifacts"
	@echo "  run      - Build and run (Debug)"
	@echo "  help     - Show this help"
	@echo ""
	@echo "Version: $(VERSION)"
