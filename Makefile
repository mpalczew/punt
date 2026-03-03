APP_NAME    := Punt
BUILD_DIR   := .build
APP_BUNDLE  := $(BUILD_DIR)/$(APP_NAME).app
CONTENTS    := $(APP_BUNDLE)/Contents
MACOS_DIR   := $(CONTENTS)/MacOS
VERSION     := $(shell /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)

SIGNING_IDENTITY ?= Developer ID Application: Michal Palczewski (FS3CWH8867)

.PHONY: build build-universal run clean install app restart

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
	cp Resources/AppIcon.icns $(CONTENTS)/Resources/AppIcon.icns

run: build
	open $(APP_BUNDLE)

install: build
	@was_running=false; \
	if pgrep -x $(APP_NAME) >/dev/null 2>&1; then \
		was_running=true; \
		pkill -x $(APP_NAME); \
		while pgrep -x $(APP_NAME) >/dev/null 2>&1; do sleep 0.1; done; \
	fi; \
	rm -rf /Applications/$(APP_NAME).app; \
	cp -R $(APP_BUNDLE) /Applications/$(APP_NAME).app; \
	echo "Installed $(APP_NAME).app to /Applications"; \
	if $$was_running; then \
		open /Applications/$(APP_NAME).app; \
		sleep 0.5; \
		if pgrep -x $(APP_NAME) >/dev/null 2>&1; then \
			echo "Restarted $(APP_NAME) (pid $$(pgrep -x $(APP_NAME)))"; \
		else \
			echo "WARNING: $(APP_NAME) failed to start"; \
		fi; \
	fi

restart:
	@pkill -x $(APP_NAME) 2>/dev/null; \
	while pgrep -x $(APP_NAME) >/dev/null 2>&1; do sleep 0.1; done; \
	open /Applications/$(APP_NAME).app; \
	sleep 0.5; \
	if pgrep -x $(APP_NAME) >/dev/null 2>&1; then \
		echo "Restarted $(APP_NAME) (pid $$(pgrep -x $(APP_NAME)))"; \
	else \
		echo "WARNING: $(APP_NAME) failed to start"; \
	fi

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
