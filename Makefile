.ONESHELL:
SHELL := /bin/bash
.SHELLFLAGS := -e -u -c -o pipefail

.DEFAULT_GOAL := help
.PHONY: help build test open-example

help:
	@echo "make build                       # swift build"
	@echo "make test                        # swift test"
	@echo "make open-example                # open external Example Xcode project"

build:
	@swift build

test:
	@swift test

open-example:
	@open Example/Leucus.xcodeproj
