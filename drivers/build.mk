# Copyright 2010-2013 RethinkDB, all rights reserved.

. := $/drivers

PROTOC_BASE := $(dir $(patsubst %/,%,$(dir $(PROTOC))))

PYTHON_PBDIR := $(BUILD_DIR)/python
PYTHON_PBFILE := query_language_pb2.py
RUBY_PBDIR := $(BUILD_DIR)/ruby
RUBY_PBFILE := query_language.pb.rb
PROTOCFLAGS := --proto_path=$(SOURCE_DIR)

include $./javascript/build.mk
# TODO
# include $./python/build.mk
# include $./ruby/build.mk

.PHONY: drivers
ifeq ($(BUILD_DRIVERS), 1)
  drivers: js-driver # TODO: driver-ruby driver-python 
else
  drivers: js-driver
endif

ALL += $.
all-$.: drivers
