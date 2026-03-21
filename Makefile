.ONESHELL:
SHELL := /bin/bash
.SHELLFLAGS := -e -u -c -o pipefail

.DEFAULT_GOAL := help
.PHONY: help build test open-example release-leucus-sparkle

help:
	@echo "make build                       # swift build"
	@echo "make test                        # swift test"
	@echo "make open-example                # open external Example Xcode project"
	@echo "make release-leucus-sparkle VERSION=0.0.x   # build + signed appcast + GH release"

build:
	@swift build

test:
	@swift test

open-example:
	@open Example/Leucus.xcodeproj

release-leucus-sparkle:
	@test -n "$(VERSION)" || (echo "VERSION is required, eg: make release-leucus-sparkle VERSION=0.0.5" && exit 1)
	@scripts/release_leucus_sparkle.sh "$(VERSION)"
