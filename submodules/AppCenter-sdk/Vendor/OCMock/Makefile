# This makefile is mainly intended for use on the CI server (Travis). It
# requires xcpretty to be installed.

# If you are trying to build a release locally consider using the build.rb
# script in the Tools directory instead.


BUILD_DIR = OBJROOT="$(CURDIR)/build" SYMROOT="$(CURDIR)/build"
SHELL = /bin/bash -e -o pipefail
IOS32 = -scheme OCMockLib -destination 'platform=iOS Simulator,OS=10.3.1,name=iPad (5th generation)' $(BUILD_DIR)
IOS64 = -scheme OCMockLib -destination 'platform=iOS Simulator,OS=latest,name=iPhone 11' $(BUILD_DIR)
MACOSX = -scheme OCMock -sdk macosx $(BUILD_DIR)
XCODEBUILD = xcodebuild -project "$(CURDIR)/Source/OCMock.xcodeproj"

ci: clean test

clean:
	$(XCODEBUILD) clean
	rm -rf "$(CURDIR)/build"

test: test-ios test-macosx

test-ios: test-ios32 test-ios64

test-ios32:
	@echo "Running 32-bit iOS tests..."
	$(XCODEBUILD) $(IOS32) test | xcpretty -c

test-ios64:
	@echo "Running 64-bit iOS tests..."
	$(XCODEBUILD) $(IOS64) test | xcpretty -c

test-macosx:
	@echo "Running OS X tests..."
	$(XCODEBUILD) $(MACOSX) test | xcpretty -c
