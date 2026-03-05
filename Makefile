.PHONY: build test run debug setup

build:
	swift build

test:
	swift test

run:
	swift run Klaude

debug:
	log stream --predicate 'subsystem == "com.soel.klaude"' --level debug &
	swift run Klaude; kill %1 2>/dev/null || true

setup:
	git config core.hooksPath .githooks
