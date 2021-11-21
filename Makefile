PROJECT_DIR 				:= $(dir $(realpath $(firstword $(MAKEFILE_LIST))))
PROJECT_NAME 				:= $(shell basename $(PROJECT_DIR))
DOCS_DIR            := $(PROJECT_DIR)/docs
BUILD_DIR 					:= $(PROJECT_DIR)/.build
DEBUG_DIR 					:= $(BUILD_DIR)/debug
RELEASE_DIR		 			:= $(BUILD_DIR)/release

.DEFAULT_GOAL: default

################################################################################
# Top-level Tool Targets

.PHONY: default debug release test repl

default: debug

debug:
	swift build -c debug

release:
	swift build -c release

test:
	swift test

repl:
	swift run --repl

################################################################################
# Documentation Targets

.PHONY: docs

modules := PwZ
protected_docs := documentation abstracts

docs: clean-docs $(patsubst %,docs/%.json,$(modules))
	jazzy --sourcekitten-sourcefile "`echo $(filter-out $<,$^) | sed 's/ /,/g'`"

docs/%.json: FORCE
	@if [ ! -d "$(@D)" ]; then mkdir -p "$(@D)"; fi
	sourcekitten doc --spm --module-name $(basename $(notdir $@)) > $@

################################################################################
# Cleaning Targets

.PHONY: clean clean-docs clean-all clean-debug clean-release clean-executable

clean: clean-debug clean-release clean-executable

clean-docs:
	@if [ ! -d "$(DOCS_DIR)" ]; then mkdir -p "$(DOCS_DIR)"; fi
	find $(DOCS_DIR) -mindepth 1 -maxdepth 1 $(patsubst %,! -name '%',$(protected_docs)) -exec rm -rf {} +

clean-all:
	$(RM) -R $(BUILD_DIR)/*

clean-debug:
	$(RM) -R $(DEBUG_DIR)/*

clean-release:
	$(RM) -R $(RELEASE_DIR)/*
