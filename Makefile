# Signing is ad-hoc (works anywhere, but macOS forgets its permissions on every rebuild) unless TEAM is set:
# then it's your "Apple Development" certificate, which keeps them. Set it once in Local.mk (gitignored):
#   TEAM = ABCDE12345
# or per invocation: make build TEAM=ABCDE12345
-include Local.mk
TEAM ?=
SIGN_IDENTITY ?= $(if $(TEAM),Apple Development,-)
CONFIG ?= Debug
# Builds are for this Mac's chip; make release builds for Apple silicon and Intel.
DESTINATION ?= platform=macOS,arch=$(shell uname -m)
ACTIVE_ARCH_ONLY ?= YES

APP = build/Build/Products/$(CONFIG)/Copperlight.app
XCODEBUILD = xcodebuild -quiet -project Copperlight.xcodeproj -scheme Copperlight -configuration $(CONFIG) -derivedDataPath build \
	-destination "$(DESTINATION)" ONLY_ACTIVE_ARCH=$(ACTIVE_ARCH_ONLY) \
	CODE_SIGN_IDENTITY="$(SIGN_IDENTITY)" $(if $(TEAM),DEVELOPMENT_TEAM=$(TEAM))

# The self-signed certificate releases are signed with (DEVELOPMENT.md, "Releasing").
RELEASE_IDENTITY ?= Copperlight
# Always this name: copperlight.app links to releases/latest/download/Copperlight.zip. The version lives in the tag.
ZIP = build/Copperlight.zip

.PHONY: project build run install release test clean strings language translations

# XcodeGen lists source files explicitly, so regenerate every time to pick up added/removed files.
project:
	xcodegen generate --quiet

build: project
	$(XCODEBUILD) build

run: build
	@pkill -x Copperlight && while pgrep -qx Copperlight; do sleep 0.1; done || true
	open $(APP)

# The copy to keep: ~/Applications/Copperlight.app, which "Launch at Login" should point at
# (build/ goes away with make clean). Turn Launch at Login on from this copy's menu.
# It's the optimized Release build; make run and make test stay Debug.
install: CONFIG = Release
install: build
	@pkill -x Copperlight && while pgrep -qx Copperlight; do sleep 0.1; done || true
	rm -rf ~/Applications/Copperlight.app
	mkdir -p ~/Applications
	cp -R $(APP) ~/Applications/
	open ~/Applications/Copperlight.app

# The zip for GitHub Releases: built ad-hoc without your team (Xcode won't sign with a self-signed certificate), then
# signed with the release certificate. Not notarized, so people open it once with Open Anyway; the same certificate
# every time keeps their permissions across updates.
release: CONFIG = Release
release: TEAM =
release: SIGN_IDENTITY = -
release: DESTINATION = generic/platform=macOS
release: ACTIVE_ARCH_ONLY = NO
release: build
	codesign --force --sign "$(RELEASE_IDENTITY)" $(APP)
	codesign --verify --strict --deep $(APP)
	rm -f $(ZIP)
	ditto -c -k --keepParent $(APP) $(ZIP)
	@shasum -a 256 $(ZIP)

# In English, whatever this Mac's language: the tests check English text.
test: project
	$(XCODEBUILD) test -testLanguage en

# The English list of every piece of text (Resources/en.lproj/Localizable.strings), from the compiler: a build of its
# own, so text from deleted files doesn't linger. CI fails when the committed list is out of date.
strings: project
	rm -rf build/strings
	xcodebuild -quiet -project Copperlight.xcodeproj -scheme Copperlight -configuration Debug -derivedDataPath build/strings \
		-destination "$(DESTINATION)" ONLY_ACTIVE_ARCH=YES CODE_SIGN_IDENTITY="-" SWIFT_EMIT_LOC_STRINGS=YES build
	xcrun swift Tools/Strings.swift english build/strings Resources/en.lproj/Localizable.strings

# A new language's folder, ready to translate: make language CODE=pt-BR
language:
	xcrun swift Tools/Strings.swift new $(CODE)

# How much of each language is translated, and what's missing or no longer in English.
translations:
	xcrun swift Tools/Strings.swift report

clean:
	rm -rf build Copperlight.xcodeproj
