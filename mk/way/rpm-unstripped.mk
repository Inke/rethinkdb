# Unstripped RPM configuration

STRIP_ON_INSTALL ?= 0
PVERSION=$(RETHINKDB_VERSION)-unstripped

ALL += $/
all-$/: build-rpm