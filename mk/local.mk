
# This file must be included last

##### Generate Makefiles in subdirectories

# Do not overwrite the top-level Makefile or the template
$/Makefile:
$/mk/Makefile:

%/Makefile:
	$P CP
	cp $/mk/Makefile $@

##### Rewrite target paths so make can find them when called from a subdirectory

ifeq (/,$(firstword $(subst /,/ ,$/)))
  # if $/ is absolute, make CWD absolute
  CWD := $(shell pwd)
else
  # if $/ is relative, make CWD relative
  CWD_ABSPATH := $(shell pwd)
  ROOT_ABSPATH := $(abspath $(CWD_ABSPATH)/$/)
  CWD := $(patsubst $(ROOT_ABSPATH)%,$(patsubst %/,%,$/)%,$(CWD_ABSPATH))
endif

ifneq ($(CWD),)
%: $(CWD)/%
	@true

$(CWD)/%: 
	$(error No rule to make target `$(patsubst $(CWD)/%,%,$@)') #`
endif

##### Subdirectory-specific targets

# all, clean and distclean work on a per-directory basis:
# 'cd foo; make clean' should only clean the foo directory
# How to use:
# - a dash and the directory path should be added to the rule
# - the directory should be appended to the corresponding variable
# Example:
# CLEAN += $/foo
# clean-$/foo:
# 	rm $/foo/bar

CLEAN_PARTIAL := $(lastword $(foreach dir,$(sort $(CLEAN)),$(patsubst %,-$(dir),$(filter $(dir)%,$(CWD)))))

ifeq (,$(CLEAN_PARTIAL))
	CLEAN_PARTIAL := $(patsubst %,-%,$(CLEAN)) -$/
endif

.PHONY: clean clean-$/ $(patsubst %,clean-%,$(CLEAN))
clean-$/:
clean: $(foreach dir,$(CLEAN_PARTIAL),clean$(dir))

DISTCLEAN_PARTIAL := $(lastword $(foreach dir,$(sort $(DISTCLEAN)),$(patsubst %,-$(dir),$(filter $(dir)%,$(CWD)))))

ifeq (,$(DISTCLEAN_PARTIAL))
	DISTCLEAN_PARTIAL := $(patsubst %,-%,$(DISTCLEAN)) -$/
endif

.PHONY: distclean distclean-$/ $(patsubst %,distclean-%,$(DISTCLEAN))
distclean-$/:
distclean: $(foreach dir,$(DISTCLEAN_PARTIAL),distclean$(dir))

ALL_PARTIAL := $(lastword $(foreach dir,$(sort $(ALL)),$(patsubst %,-$(dir),$(filter $(dir)%,$(CWD)))))

ifeq (,$(ALL_PARTIAL))
	ALL_PARTIAL := $(patsubst %,-%,$(ALL)) -$/
endif

.PHONY: all all-$/ $(patsubst %,all-%,$(ALL))
all-$/:
all: $(foreach dir,$(ALL_PARTIAL),all$(dir))
