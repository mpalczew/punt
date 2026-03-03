APP_NAME    := Punt
BUILD_DIR   := .build
APP_BUNDLE  := $(BUILD_DIR)/$(APP_NAME).app
CONTENTS    := $(APP_BUNDLE)/Contents
MACOS_DIR   := $(CONTENTS)/MacOS
VERSION     := $(shell /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)

SIGNING_IDENTITY ?= Developer ID Application: Michal Palczewski (FS3CWH8867)

.PHONY: build build-universal run clean install app

build:
	swift build -c release
	$(MAKE) app

app:
	mkdir -p $(MACOS_DIR) $(CONTENTS)/Resources
	cp $(BUILD_DIR)/release/$(APP_NAME) $(MACOS_DIR)/$(APP_NAME)
	cp Resources/Info.plist $(CONTENTS)/Info.plist
	cp Resources/AppIcon.icns $(CONTENTS)/Resources/AppIcon.icns

build-universal:
	swift build -c release --arch arm64
	swift build -c release --arch x86_64
	mkdir -p $(MACOS_DIR) $(CONTENTS)/Resources
	lipo -create \
		$(BUILD_DIR)/arm64-apple-macosx/release/$(APP_NAME) \
		$(BUILD_DIR)/x86_64-apple-macosx/release/$(APP_NAME) \
		-output $(MACOS_DIR)/$(APP_NAME)
	cp Resources/Info.plist $(CONTENTS)/Info.plist

run: build
	open $(APP_BUNDLE)

install: build
	rm -rf /Applications/$(APP_NAME).app
	cp -R $(APP_BUNDLE) /Applications/$(APP_NAME).app
	@echo "Installed $(APP_NAME).app to /Applications"

clean:
	swift package clean
	rm -rf $(APP_BUNDLE)
	rm -f $(BUILD_DIR)/*.zip

sign:
	codesign --force --options runtime \
		--sign "$(SIGNING_IDENTITY)" \
		--timestamp \
		$(APP_BUNDLE)
	codesign --verify --verbose $(APP_BUNDLE)

release-universal: build-universal sign
	cd $(BUILD_DIR) && zip -r -y $(APP_NAME)-$(VERSION)-universal.zip $(APP_NAME).app
	@echo "Created $(BUILD_DIR)/$(APP_NAME)-$(VERSION)-universal.zip"
