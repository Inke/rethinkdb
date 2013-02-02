# Copyright 2010-2013 RethinkDB, all rights reserved.

##### Configuring stuff

CONFIG ?= config.mk

MAKECMDGOALS ?=

COUNTDOWN_JUST_COUNT ?= 0

ifeq (,$(filter config,$(MAKECMDGOALS)))
  -include $/$(CONFIG)
  CONFIGURE_STATUS ?= pending
  ifneq (,$(filter started failed,$(CONFIGURE_STATUS)))
    $(warning CONFIGURE ERROR: $(CONFIGURE_ERROR))
    $(error run ./configure again or edit $/$(CONFIG))
  endif
endif

ifneq (1,$(COUNTDOWN_JUST_COUNT))
  $/$(CONFIG):
	$P CONFIGURE $@
	./$/configure --config=$@ $(CONFIGURE_FLAGS)
endif

.PHONY: config
config:
	$P RM $/$(CONFIG)
	rm $/$(CONFIG) 2>/dev/null || :
	$(MAKE) $/$(CONFIG)

DISTCLEAN += $/
.PHONY: distclean-$/
distclean-$/:
	$P RM $/$(CONFIG)
	rm -$/$(CONFIG)

##### Some variables defined by the configure script

# listed here to avoid undefined variable warnings

COMPILER ?= NO
OS ?= NO
PREFIX ?= NO
ALLOW_INTERNAL_TOOLS ?= NO
SYSCONFDIR ?= NO
LOCALSTATEDIR ?= NO
LIB_SEARCH_PATHS ?= NO
PROTOC ?= NO
BUILD_DRIVERS ?= NO
HANDLEBARS ?= NO
COFFEE ?= NO
LESSC ?= NO