.PHONY: build test run debug setup

build:
	swift build

test:
	swift test

run:
	swift run Promptty

debug:
	log stream --predicate 'subsystem == "com.soel.promptty"' --level debug &
	swift run Promptty; kill %1 2>/dev/null || true

setup:
	git config core.hooksPath .githooks
