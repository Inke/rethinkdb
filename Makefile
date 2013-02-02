# Copyright 2010-2013 RethinkDB, all rights reserved.

# TODO:
# if build_portable, then static v8
# libunwind
# tcmalloc doesn't link
# remove colonizer
# uninstall
# build-deb-src doesn't build a portable package
# is BUILD_PORTABLE needed?
# test osx and other packages (including rpm)
# warn if configure options are missing the CONFIGURE_FLAGS
# make brew
# precompile web assets and protoc
# python on arch: /usr/bin/python is v3

# Test make features
ifeq (,$(filter else-if,$(.FEATURES)))
	$(error GNU Make >= 3.8.1 is required)
endif

MAKEFLAGS += --no-print-directory
MAKEFLAGS += --warn-undefined-variables 

# Root of the rethinkdb source tree
/ ?=

# The default target
.PHONY: all
all:

# all, clean and distclean targets are defined in mk/local.mk
ALL :=
CLEAN :=
DISTCLEAN :=

# Two ways to Override the default settings:
CUSTOM ?= $/custom.mk
include $/mk/check-env.mk
  # Settings local to this repository
  -include $(CUSTOM)
  # Pre-configured ways to build
  WAY ?= default
  include $/mk/way/$(WAY).mk
include $/mk/check-env.mk

# Generate and include the config file
include $/mk/configure.mk

# Default values for target-independant settings
include $/mk/way/default.mk

# Makefile related definitions
include $/mk/lib.mk

# Paths, build rules and other tools
include $/mk/paths.mk
include $/mk/support.mk
include $/mk/install.mk
include $/drivers/build.mk
include $/mk/webui.mk
include $/mk/build.mk
include $/mk/packaging.mk
include $/mk/tools.mk

# Targets that behave differently based on the current directory (must be included last)
include $/mk/local.mk