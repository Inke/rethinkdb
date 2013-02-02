# parts removed from the old makefile

ifeq ($(LIBCRYPTO),1)
RT_LDFLAGS+=-lcrypto 
endif

# Profiling
OPROF_TARGETS=oprof-start oprof-dump oprof-stop oprof-report oprof-build
.PHONY: $(OPROF_TARGETS)

# TODO: ifeq(OPROFILE,1)

oprof-build:
	$(MAKE) DEBUG=0 SYMBOLS=1 NO_OMIT_FRAME_POINTER=1

oprof-start: OPROF_NO_KERNEL:=0
oprof-start: OPROF_SESSION:=../oprofile.$(RETHINKDB_VERSION).$(shell date +%F-%T)
oprof-start:
	@echo no kernel: $(OPROF_NO_KERNEL)
ifeq ($(OPROF_NO_KERNEL),1)
	@echo "    OPROFILE[init] (no kernel profiling)"
	$(QUIET) opcontrol --no-vmlinux
else
	@echo "    OPROFILE[init] (with kernel profiling, set OPROF_NO_KERNEL to 1 to turn off)"
	$(QUIET) opcontrol --vmlinux=/usr/lib/debug/boot/vmlinux-`uname -r`
endif
	@echo "    OPROFILE[start] -> $(abspath $(OPROF_SESSION))"
	@echo "      (if you want to use a different location, set OPROF_SESSION make variable to a directory path"
	$(QUIET) opcontrol --start --callgraph=2 --event=CPU_CLK_UNHALTED:90000:0:1:1 --buffer-size=10485760 --buffer-watershed=524288 "--session-dir=$(abspath $(OPROF_SESSION))"

oprof-dump:
	@echo "    OPROFILE[dump]"
	$(QUIET) opcontrol --dump

oprof-stop: oprof-dump
	@echo "    OPROFILE[shutdown]"
	$(QUIET) opcontrol --shutdown

oprof-report: OPROF_SESSION:=$(shell ls -dt ../oprofile.* 2> /dev/null | head -1)
oprof-report: OPROF_BINARY:=../build/release/rethinkdb
oprof-report: OPROF_RESULT:=$(OPROF_SESSION)/report.txt
oprof-report:
	@if [ ! -d "$(OPROF_SESSION)" ]; then \
			echo "error: OPROF_SESSION is not set and no oprofile sessions could be found in the repository root."; \
			exit 1; \
		fi
	@if [ ! -x "$(OPROF_BINARY)" ]; then \
			echo "error: OPROF_BINARY is not set or '$(OPROF_BINARY)' is not an executable."; \
			exit 1; \
		fi
	@echo "    OPREPORT[$(OPROF_BINARY)] -> $(OPROF_RESULT)"
	$(QUIET) opreport --merge=lib,unitmask -a --symbols --callgraph --threshold 1 --sort sample "--session-dir=$(realpath $(OPROF_SESSION))" -l "$(realpath $(OPROF_BINARY))" > $(OPROF_RESULT)

sembuild: clean
	make SEMANTIC_SERIALIZER_CHECK=1 all


