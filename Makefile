PROJECT_DIR 				:= $(dir $(realpath $(firstword $(MAKEFILE_LIST))))
PROJECT_NAME 				:= $(shell basename $(PROJECT_DIR))
DOCS_DIR            := $(PROJECT_DIR)/docs
BUILD_DIR 					:= $(PROJECT_DIR)/.build
DEBUG_DIR 					:= $(BUILD_DIR)/debug
RELEASE_DIR		 			:= $(BUILD_DIR)/release

.DEFAULT_GOAL: default
.PHONY: FORCE

FORCE:

################################################################################
# Top-level Tool Targets

.PHONY: default debug release

default: debug

debug:
	swift build -c debug

release:
	swift build -c release

################################################################################
# Documentation Targets

.PHONY: docs

modules := PwZ

docs: clean-docs $(patsubst %,docs/%.json, $(modules))
	jazzy --sourcekitten-sourcefile "`echo $(filter-out $<,$^) | sed 's/ /,/g'`"

docs/%.json: FORCE
	@if [ ! -d "$(@D)" ]; then mkdir -p "$(@D)"; fi
	sourcekitten doc --spm --module-name $(basename $(notdir $@)) > $@

################################################################################
# Cleaning Targets

.PHONY: clean clean-docs clean-all clean-debug clean-release clean-executable

clean: clean-debug clean-release clean-executable

clean-docs:
	$(RM) -R $(DOCS_DIR)/*

clean-all:
	$(RM) -R $(BUILD_DIR)/*

clean-debug:
	$(RM) -R $(DEBUG_DIR)/*

clean-release:
	$(RM) -R $(RELEASE_DIR)/*
