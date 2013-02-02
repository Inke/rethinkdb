# Copyright 2010-2013 RethinkDB, all rights reserved.

V8_DEP :=
NPM_DEP :=
TCMALLOC_DEP :=
PROTOC_DEP :=

ifeq (1,$(ALLOW_INTERNAL_TOOLS))

# TODO: wget or curl
GETURL := wget --quiet --output-document=-

SUPPORT_DIR := $/support
SUPPORT_DIR_ABS := $(abspath $(SUPPORT_DIR))
SUPPORT_INST_DIR := $(SUPPORT_DIR)/usr
SUPPORT_LOG_DIR := $(SUPPORT_DIR_ABS)/log
TC_BUILD_DIR := $(SUPPORT_DIR)/build
TC_SRC_DIR := $(SUPPORT_DIR)/src
TOOLCHAIN_DIR := $(SUPPORT_DIR)/toolchain
NODE_MODULES_DIR := $(TOOLCHAIN_DIR)/node_modules
NODE_DIR := $(TC_BUILD_DIR)/node
NODE_SRC_DIR := $(TC_SRC_DIR)/node
PROTOC_DIR := $(TC_BUILD_DIR)/protobuf
PROTOC_SRC_DIR := $(TC_SRC_DIR)/protobuf
GPERFTOOLS_DIR := $(TC_BUILD_DIR)/gperftools
GPERFTOOLS_SRC_DIR := $(TC_SRC_DIR)/gperftools
LIBUNWIND_DIR := $(TC_BUILD_DIR)/libunwind
LIBUNWIND_SRC_DIR := $(TC_SRC_DIR)/libunwind
UNWIND_INT_LIB := # TODO
TCMALLOC_MINIMAL_INT_LIB := $(SUPPORT_INST_DIR)/lib/libtcmalloc_minimal.a
TC_PROTOC_INT_EXE := $(SUPPORT_INST_DIR)/bin/protoc
TC_PROTOC_INT_BIN_DIR := $(SUPPORT_INST_DIR)/bin
TC_PROTOC_INT_LIB_DIR := $(SUPPORT_INST_DIR)/lib
TC_PROTOC_INT_INC_DIR := $(SUPPORT_INST_DIR)/include
PROTOBUF_INT_LIB := $(TC_PROTOC_INT_LIB_DIR)/libprotobuf.a
TC_NODE_INT_EXE := $(SUPPORT_DIR)/usr/bin/node
TC_NPM_INT_EXE := $(SUPPORT_DIR)/usr/bin/npm
TC_LESSC_INT_EXE := $(SUPPORT_DIR)/usr/bin/lessc
TC_COFFEE_INT_EXE := $(SUPPORT_DIR)/usr/bin/coffee
TC_HANDLEBARS_INT_EXE := $(SUPPORT_DIR)/usr/bin/handlebars
V8_SRC_DIR := $(TC_SRC_DIR)/v8
V8_DIR := $(TC_BUILD_DIR)/v8
V8_INT_LIB := $(V8_DIR)/libv8.a

.PHONY: support
support: $(foreach v,$(shell echo $(FETCH_LIST) | tr a-z A-Z), \
            $(patsubst %,$($(v)),$(filter-out undefined,$(origin $(v)))))

DISTCLEAN += $(SUPPORT_DIR)
.PHONY: distclean-$(SUPPORT_DIR)
distclean-$(SUPPORT_DIR):
	$P RM $(SUPPORT_DIR)
	rm -rf $(SUPPORT_DIR)

$(shell mkdir -p $(SUPPORT_DIR) $(TOOLCHAIN_DIR) $(TC_BUILD_DIR) $(TC_SRC_DIR))

ifeq (0,$(VERBOSE))
  $(shell mkdir -p $(SUPPORT_LOG_DIR))
  SUPPORT_LOG_PATH = $(SUPPORT_LOG_DIR)/$(notdir $@).log
  SUPPORT_LOG_REDIRECT = > $(SUPPORT_LOG_PATH) 2>&1 || ( echo Error log: $(SUPPORT_LOG_PATH) ; tail -n 40 $(SUPPORT_LOG_PATH) ; false )
else
  SUPPORT_LOG_REDIRECT :=
endif

ifneq (,$(filter protoc,$(FETCH_LIST)))
  LD_LIBRARY_PATH ?=
  PROTOC_DEP := $(TC_PROTOC_INT_EXE)
  PROTOC := env LD_LIBRARY_PATH=$(TC_PROTOC_INT_LIB_DIR):$(LD_LIBRARY_PATH) PATH=$(TC_PROTOC_INT_BIN_DIR):$(PATH) $(PROTOC)
  TC_PROTOC_CFLAGS := -isystem $(TC_PROTOC_INT_INC_DIR)
  CXXPATHDS += $(TC_PROTOC_CFLAGS)
  CPATHDS += $(TC_PROTOC_CFLAGS)
endif

ifneq (,$(filter v8,$(FETCH_LIST)))
  V8_DEP := $(V8_DIR)
endif

ifneq (,$(filter npm,$(FETCH_LIST)))
  NPM_DEP := $(NPM)
endif

ifneq (,$(filter tcmalloc_minimal,$(FETCH_LIST)))
  TCMALLOC_DEP := $(TCMALLOC_MINIMAL_INT_LIB)
endif

$(TC_BUILD_DIR)/%: $(TC_SRC_DIR)/%
	$P CP
	rm -rf $@
	cp -pRP $< $@

$(TC_LESSC_INT_EXE): $(NODE_MODULES_DIR)/less
	$P LN
	rm -f $@
	ln -s $(abspath $</bin/lessc) $@
	touch $@

$(NODE_MODULES_DIR)/less: $(NPM_DEP)
	$P NPM-I less
	cd $(TOOLCHAIN_DIR) && $(abspath $(NPM)) install less $(SUPPORT_LOG_REDIRECT)

$(TC_COFFEE_INT_EXE): $(NODE_MODULES_DIR)/coffee-script
	$P LN
	rm -f $@
	ln -s $(abspath $</bin/coffee) $@
	touch $@

$(NODE_MODULES_DIR)/coffee-script: $(NPM_DEP)
	$P NPM-I coffee-script
	cd $(TOOLCHAIN_DIR) && \
	  $(abspath $(NPM)) install coffee-script $(SUPPORT_LOG_REDIRECT)

$(TC_HANDLEBARS_INT_EXE): $(NODE_MODULES_DIR)/handlebars
	$P LN
	rm -f $@
	ln -s $(abspath $</bin/handlebars) $@
	touch $@

$(NODE_MODULES_DIR)/handlebars: $(NPM_DEP)
	$P NPM-I handlebars
	cd $(TOOLCHAIN_DIR) && \
	  $(abspath $(NPM)) install handlebars $(SUPPORT_LOG_REDIRECT)

$(V8_SRC_DIR):
	$P SVN-CO v8
	( cd $(TC_SRC_DIR) && \
	  svn checkout http://v8.googlecode.com/svn/trunk/ v8 ) $(SUPPORT_LOG_REDIRECT)
	$P MAKE v8 dependencies
	$(MAKE) -C $(V8_SRC_DIR) dependencies $(SUPPORT_LOG_REDIRECT)

$(V8_INT_LIB): $(V8_DIR)
	$P MAKE v8
	$(MAKE) -C $(V8_DIR) prefix=$(SUPPORT_DIR_ABS)/usr DESTDIR=/ native $(SUPPORT_LOG_REDIRECT)
	$P AR $@
	find $(V8_DIR) -iname "*.o" | grep -v '\/preparser_lib\/' | xargs ar cqs $(V8_INT_LIB);

$(NODE_SRC_DIR):
	$P DOWNLOAD node
	$(GETURL) http://nodejs.org/dist/v0.8.11/node-v0.8.11.tar.gz | ( \
	  cd $(TC_SRC_DIR) && tar -xzf - && rm -rf node && mv node-v0.8.11 node )

$(TC_NPM_INT_EXE): $(TC_NODE_INT_EXE)

$(TC_NODE_INT_EXE): $(NODE_DIR)
	$P MAKE node
	( unset prefix PREFIX DESTDIR MAKEFLAGS MFLAGS && \
	  cd $(NODE_DIR) && \
	  ./configure --prefix=$(SUPPORT_DIR_ABS)/usr && \
	  $(MAKE) prefix=$(SUPPORT_DIR_ABS)/usr DESTDIR=/ && \
	  $(MAKE) install prefix=$(SUPPORT_DIR_ABS)/usr DESTDIR=/ ) $(SUPPORT_LOG_REDIRECT)
	touch $@

$(PROTOC_SRC_DIR):
	$P DOWNLOAD protoc
	$(GETURL) http://protobuf.googlecode.com/files/protobuf-2.4.1.tar.bz2 | ( \
	  cd $(TC_SRC_DIR) && \
	  tar -xjf - && \
	  rm -rf protobuf && \
	  mv protobuf-2.4.1 protobuf )

$(PROTOBUF_INT_LIB): $(TC_PROTOC_INT_EXE)
$(TC_PROTOC_INT_EXE): $(PROTOC_DIR)
	$P MAKE protoc
	( cd $(PROTOC_DIR) && \
	  ./configure --prefix=$(SUPPORT_DIR_ABS)/usr && \
	  $(MAKE) PREFIX=$(SUPPORT_DIR_ABS)/usr prefix=$(SUPPORT_DIR_ABS)/usr DESTDIR=/ && \
	  $(MAKE) install PREFIX=$(SUPPORT_DIR_ABS)/usr prefix=$(SUPPORT_DIR_ABS)/usr DESTDIR=/ ) \
	    $(SUPPORT_LOG_REDIRECT)

$(GPERFTOOLS_SRC_DIR):
	$P DOWNLAOD gperftools
	$(GETURL) http://gperftools.googlecode.com/files/gperftools-2.0.tar.gz | ( \
	  cd $(TC_SRC_DIR) && \
	  tar -xzf - && \
	  rm -rf gperftools && \
	  mv gperftools-2.0 gperftools )

$(LIBUNWIND_SRC_DIR):
	$P DOWNLOAD libunwind
	$(GETURL) http://download.savannah.gnu.org/releases/libunwind/libunwind-1.1.tar.gz | ( \
	  tar -xzf - && \
	  rm -rf libunwind && \
	  mv libunwind-1.1 libunwind )

$(LIBUNWIND_DIR): $(LIBUNWIND_SRC_DIR)

# TODO: don't use colonize.sh
# TODO: seperate step and variable for building $(UNWIND_INT_LIB)
$(TCMALLOC_MINIMAL_INT_LIB): $(LIBUNWIND_DIR) $(GPERFTOOLS_DIR)
	$P MAKE libunwind gperftools
	$(QUIET) cd ../support/build && rm -f native_list.txt semistaged_list.txt staged_list.txt boost_list.txt post_boost_list.txt && touch native_list.txt semistaged_list.txt staged_list.txt boost_list.txt post_boost_list.txt && echo libunwind >> semistaged_list.txt && echo gperftools >> semistaged_list.txt && cp -pRP $(COLONIZE_SCRIPT_ABS) ./ && ( unset PREFIX && unset prefix && unset MAKEFLAGS && unset MFLAGS && unset DESTDIR && bash ./colonize.sh ; )

endif # ALLOW_INTERNAL_TOOLS