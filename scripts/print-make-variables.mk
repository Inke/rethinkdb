#!/usr/bin/make -nf

# Given a Makefile as argument, this script lists all the variable names defined in the file

.SILENT:

define nl


endef

if_no_target_show_usage:
	$(error "Usage: print-make-variables.mk Makefile$(nl)   export variables defined in a makefile as a shell script")

output-type ?= shell

otherwise_list_the_variables: SHELL=echo
otherwise_list_the_variables:
	$(all_the_new_variables)

.PHONY: $(MAKECMDGOALS)
$(MAKECMDGOALS): otherwise_list_the_variables

the_predefined_variables := $(.VARIABLES)

include $(MAKECMDGOALS)

all_the_new_variables := $(filter-out $(the_predefined_variables) the_predefined_variables,$(.VARIABLES))