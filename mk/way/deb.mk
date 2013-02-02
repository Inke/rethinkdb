# RethinkDB configuration for building a deb package

STRIP_ON_INSTALL ?= 1
CONFIGURE_FLAGS ?= --disable-drivers

ALL += $/
all-$/: build-deb