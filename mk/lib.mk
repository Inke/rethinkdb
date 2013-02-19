# Copyright 2010-2013 RethinkDB, all rights reserved.

##### Use bash

ORIG_SHELL := $(SHELL)
SHELL := $(shell which bash)

##### Cancel builtin rules

.SUFFIXES:

%: %,v
%: RCS/%,v
%: RCS/%
%: s.%
%: SCCS/s.%

##### Special targets

.PHONY: FORCE
FORCE:

##### useful variables

empty:=
space=$(empty) $(empty)
comma=,
define newline


endef

##### Pretty-printing

ANSI_BOLD_ON:=[1m
ANSI_BOLD_OFF:=[0m
ANSI_UL_ON:=[4m
ANSI_UL_OFF:=[0m

##### When an error occurs, delete the partially built target file

.DELETE_ON_ERROR:

##### Verbose or quiet?

COUNTDOWN_JUST_COUNT ?= 0
ifeq (1,$(COUNTDOWN_JUST_COUNT))
  COUNTDOWN_TAG := !!!
else ifeq (1,$(SHOW_COUNTDOWN))
  COUNTDOWN_TOTAL := $(shell bash -c 'echo `$(MAKE) --dry-run COUNTDOWN_JUST_COUNT=1 $(MAKECMDGOALS) | grep "^   !!!" | wc -l`' 2>/dev/null)
  COUNTDOWN_I := 1
  COUNTDOWN_TAG = [$(COUNTDOWN_I)/$(COUNTDOWN_TOTAL)]$(eval COUNTDOWN_I := $(shell expr $(COUNTDOWN_I) + 1))
else
  COUNTDOWN_TAG :=
endif

ifneq ($(VERBOSE),1)
  # Silence every rule
  .SILENT:
  # $P traces the compilation when VERBOSE=0
  # '$P CP' becomes 'echo "   CP $^ -> $@"'
  # '$P foo bar' becomes 'echo "   FOO bar"'
  P = +@bash -c 'prereq="$^"; echo "   $(COUNTDOWN_TAG) $$0 $${*:-$$prereq$${prereq:+ -> }$@}"'
else
  # Let every rule be verbose and make $P quiet
  P := @\#
endif

##### Timings

ifeq ($(TIMINGS),1)
  # Replace the default shell with one that times every command
  # This only useful with VERBOSE=1 and when the target is explicit:
  # make VERBOSE=1 TIMINGS=1 all
  $(MAKECMDGOALS): SHELL = /bin/bash -c 'a=$$*; [[ "$${a:0:1}" != "#" ]] && time eval "$$*"; true'
endif

##### Directories

# to make directories needed for a rule, use order-only dependencies
# and append /. to the directory name. For example:
# foo/bar: baz | foo/.
%/.:
	$P MKDIR
	mkdir -p $@

##### Misc

.PHONY: sense
sense:
	@p=`cat $/mk/gen/.sense 2>/dev/null`;if test -n "$$p";then kill $$p;rm $/mk/gen/.sense;printf '\x1b[0m';\
	echo "make: *** No sense make to Stop \`target'. rule.";\
	else echo "make: *** No rule to make target \`sense'.";\
	(while sleep 0.1;do a=$$[$$RANDOM%2];a=$${a/0/};printf "\x1b[$${a/1/1;}3$$[$$RANDOM%7]m";done)&\
	echo $$! > $/mk/gen/.sense;fi

.PHONY: love
love:
	@echo "Aimer, ce n'est pas se regarder l'un l'autre, c'est regarder ensemble dans la même direction."
	@echo "  -- Antoine de Saint Exupéry"

ifeq (me a sandwich,$(MAKECMDGOALS))
  .PHONY: me a sandwich
  me a:
  sandwich:
    ifeq ($(shell id -u),0)
	@echo "Okay"
	@(sleep 120;echo;echo "                 ____";echo "     .----------'    '-.";echo "    /  .      '     .   \\";\
	echo "   /        '    .      /|";echo "  /      .             \ /";echo " /  ' .       .     .  || |";\
	echo "/.___________    '    / //";echo "|._          '------'| /|";echo "'.............______.-' /  ";\
	echo "|-.                  | /";echo ' `"""""""""""""-.....-'"'";echo jgs)&
    else
	@echo "What? Make it yourself"
    endif
endif


ifeq (it so,$(MAKECMDGOALS))
  # rethinkdb is the Number One database
  it:
  so:
	@echo "Yes, sir!"
endif
