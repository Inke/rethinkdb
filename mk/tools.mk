# Copyright 2010-2013 RethinkDB, all rights reserved.

##### Generate ctags or etags file

CTAGSPROG ?= ctags
ETAGSPROG ?= etags

TAGSFILE  ?= $/src/.tags
ETAGSFILE ?= $/src/TAGS

CTAGFLAGS ?= -R --c++-kinds=+p --fields=+iaS --extra=+q --langmap="c++:.cc.tcc.hpp"

.PHONY: tags etags
tags: $(TAGSFILE)
etags: $(ETAGSFILE)

$(TAGSFILE): FORCE
	$P TAGS $@
	$(CTAGSPROG) $(CTAGFLAGS) -f $@ $/src

$(ETAGSFILE): FORCE
	$P ETAGS $@
	rm -rf $@
	touch $@
	find $/src \( -name \*.hpp -or -name \*.cc -or -name \*.tcc \) -print0 \
	  | xargs -0 $(ETAGSPROG) -l c++ -a -o $@

##### cscope

CSCOPE_XREF ?= $/src/.cscope

.PHONY: cscope
cscope:
	$P CSCOPE
	cscope -bR -f $(CSCOPE_XREF)

##### Valgrind

VALGRIND_FLAGS ?= --leak-check=full --db-attach=yes --show-reachable=yes --suppressions=../scripts/rethinkdb-valgrind-suppressions.supp

# TODO: valgrind

##### Coverage report

ifeq (1,$(COVERAGE))
  .PHONY: coverage
  coverage: $(BUILD_DIR)/$(SERVER_UNIT_TEST_NAME)
	$P RUN $<
	$(BUILD_DIR)/$(SERVER_UNIT_TEST_NAME) --gtest_filter=$(UNIT_TEST_FILTER)
	$P LCOV $(BUILD_DIR)/coverage.full.info
	lcov --directory $(OBJ_DIR) --base-directory "`pwd`" --capture --output-file $(BUILD_DIR)/coverage.full.info
	$P LCOV $(BUILD_DIR)/converage.info
	lcov --remove $(BUILD_DIR)/coverage.full.info /usr/\* -o $(BUILD_DIR)/coverage.info
	$P GENHTML $(BUILD_DIR)/coverage
	genhtml --demangle-cpp --no-branch-coverage --no-prefix -o $(BUILD_DIR)/coverage $(BUILD_DIR)/coverage.info 
	echo "Wrote unit tests coverage report to $(BUILD_DIR)/coverage"
endif

##### Code information

analyze: $(SOURCES)
	$P CLANG-ANALYZE
	clang --analyze $(RT_CXXFLAGS) $(SOURCES)

coffeelint:
	$P COFFEELINT ""
	-coffeelint -f $/scripts/coffeelint.json -r $/admin/

style: coffeelint
	$P CHECK-STYLE ""
	$/scripts/check_style.sh

showdefines:
	$P SHOW-DEFINES ""
	$(RT_CXX) $(RT_CXXFLAGS) -m32 -E -dM - < /dev/null
