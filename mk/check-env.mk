# Copyright 2013 RethinkDB, all rights reserved.

check-env-state ?= before
old-env-variables ?=
old-makefiles ?=

ifeq ($(check-env-state),before)
  old-env-variables := $(.VARIABLES)
  old-makefiles := $(MAKEFILE_LIST)
  check-env-state := after
else ifeq ($(check-env-state),after)
  ifeq (1,$(MAKE_VARIABLE_CHECK))
    new-env-variables := $(filter-out $(old-env-variables),$(.VARIABLES))

    $/mk/gen/allowed-variables.mk: $/mk/way/default.mk
	echo "allowed-variables := $$(MAKEFLAGS= ./$/scripts/print-make-variables.mk -j1 --no-print-directory $<)" > $@

    allowed-variables :=
    -include $/mk/gen/allowed-variables.mk

    ifneq (,$(allowed-variables))
      remaining-variables := $(filter-out $(allowed-variables) WAY,$(new-env-variables))
      checked-makefiles := $(filter-out $(old-makefiles) $/mk/gen/allowed-variables.mk,$(MAKEFILE_LIST))

      ifneq (,$(remaining-variables))
        ifeq (1,$(STRICT_MAKE_VARIABLE_CHECK))
          $(error Possibly unknown variables defined in $(checked-makefiles): $(remaining-variables))
        else
          $(warning Possibly unknown variables defined in $(checked-makefiles): $(remaining-variables))
        endif
      endif
    endif
    check-env-state := done
  endif
else
  $(error Cannot include check-env more than twice)
endif
