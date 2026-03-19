.ONESHELL:
SHELL := /bin/bash
.SHELLFLAGS := -e -u -c -o pipefail

.DEFAULT_GOAL := help
.PHONY: help build run-demo

help:
	@echo "make build                       # swift build"
	@echo "make run-demo                    # swift run CanvasTerminalDemo"

build:
	@swift build

run-demo:
	@swift run CanvasTerminalDemo
