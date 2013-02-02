# Copyright 2010-2013 RethinkDB, all rights reserved.

SCRIPTS_DIR := $/scripts
SOURCE_DIR := $/src
BUILD_ROOT_DIR := $/build
PACKAGING_DIR := $/packaging
PACKAGES_DIR := $(BUILD_ROOT_DIR)/packages

ifeq ($(BUILD_DIR),)
  ifeq ($(DEBUG),1)
    BUILD_DIR := $(BUILD_ROOT_DIR)/debug
  else
    BUILD_DIR := $(BUILD_ROOT_DIR)/release
  endif

  ifeq ($(COMPILER), CLANG)
    BUILD_DIR += clang
  else ifeq ($(COMPILER), INTEL)
      BUILD_DIR += intel
  endif

  ifeq (1,$(SEMANTIC_SERIALIZER_CHECK))
    BUILD_DIR += scs
  endif

  ifeq (1,$(MOCK_CACHE_CHECK))
    BUILD_DIR += mockcache
  endif

  ifeq (1,$(LEGACY_LINUX))
    BUILD_DIR += legacy
  endif

  ifeq (1,$(LEGACY_GCC))
    BUILD_DIR += legacy-gcc
  endif

  ifeq (1,$(NO_EVENTFD))
    BUILD_DIR += noeventfd
  endif

  ifeq (1,$(NO_EPOLL))
    BUILD_DIR += noepoll
  endif

  ifeq (1,$(VALGRIND))
    BUILD_DIR += valgrind
  endif

  ifeq (1,$(AIOSUPPORT))
    BUILD_DIR += aiosupport
  endif

  BUILD_DIR := $(subst $(space),_,$(BUILD_DIR))
endif

$(shell mkdir -p $(BUILD_DIR))
$(shell rm -f $(BUILD_ROOT_DIR)/last 2>/dev/null || : )
$(shell ln -s $(abspath $(BUILD_DIR)) $(BUILD_ROOT_DIR)/last)

GDB_FUNCTIONS_NAME := rethinkdb-gdb.py

PACKAGE_NAME := $(VANILLA_PACKAGE_NAME)
SERVER_UNIT_TEST_NAME := $(SERVER_EXEC_NAME)-unittest

EXTERNAL_DIR := $/external
EXTERNAL_DIR_ABS := $(abspath $(EXTERNAL_DIR))
COLONIZE_SCRIPT := $(EXTERNAL_DIR)/colonist/colonize.sh
COLONIZE_SCRIPT_ABS := $(EXTERNAL_DIR_ABS)/colonist/colonize.sh

PROTO_DIR := $(BUILD_DIR)/proto

DEP_DIR := $(BUILD_DIR)/dep
OBJ_DIR := $(BUILD_DIR)/obj

WEB_ASSETS_DIR_NAME := rethinkdb_web_assets
WEB_ASSETS_BUILD_DIR := $(BUILD_DIR)/rethinkdb_web_assets

##### To rebuild when Makefiles change

ifeq ($(IGNORE_MAKEFILE_CHANGES),1)
  MAKEFILE_DEPENDENCY := 
else
  MAKEFILE_DEPENDENCY = $(filter %Makefile,$(MAKEFILE_LIST)) $(filter %.mk,$(MAKEFILE_LIST))
endif