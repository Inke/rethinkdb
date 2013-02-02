##### Packaging

# TODO: make dist

RPM_PACKAGE_DIR := $(PACKAGES_DIR)/rpm
DEB_PACKAGE_DIR := $(PACKAGES_DIR)/deb

RPM_SPEC_INPUT := $(PACKAGING_DIR)/rpm.spec
DEBIAN_PKG_DIR := $(PACKAGING_DIR)/debian
SUPPRESSED_LINTIAN_TAGS := new-package-should-close-itp-bug
RPM_BUILD_ROOT := $(RPM_PACKAGE_DIR)/BUILD
DEB_CONTROL_ROOT := $(DEB_PACKAGE_DIR)/DEBIAN
RPM_SPEC_FILE := $(RPM_PACKAGE_DIR)/SPECS/rethinkdb.spec

RETHINKDB_VERSION_RPM := $(subst -,_,$(RETHINKDB_PACKAGING_VERSION))

# Ubuntu quantal and later require nodejs-legacy.
ifeq ($(shell echo $(UBUNTU_RELEASE) | grep '^[q-zQ-Z]'),)
  NODEJS_NEW := 0
else
  NODEJS_NEW := 1
endif

# We have facilities for converting between toy names and Debian release numbers.

DEB_NUM_TO_TOY := sed -e 's/^1$$/buzz/g' -e 's/^2$$/rex/g' -e 's/^3$$/bo/g' -e 's/^4$$/hamm/g' -e 's/^5$$/slink/g' -e 's/^6$$/potato/g' -e 's/^7$$/woody/g' -e 's/^8$$/sarge/g' -e 's/^9$$/etch/g' -e 's/^10$$/lenny/g' -e 's/^11$$/squeeze/g' -e 's/^12$$/wheezy/g' -e 's/^13$$/jessie/g'
DEB_TOY_TO_NUM := sed -e 's/^buzz$$/1/g' -e 's/^rex$$/2/g' -e 's/^bo$$/3/g' -e 's/^hamm$$/4/g' -e 's/^slink$$/5/g' -e 's/^potato$$/6/g' -e 's/^woody$$/7/g' -e 's/^sarge$$/8/g' -e 's/^etch$$/9/g' -e 's/^lenny$$/10/g' -e 's/^squeeze$$/11/g' -e 's/^wheezy$$/12/g' -e 's/^jessie$$/13/g'
DEB_NUM_MAX := 13

# We can accept a toy name via DEB_RELEASE or a number via DEB_NUM_RELEASE.
# Note that the numeric release does not correspond to the Debian version but to the sequence of major releases. Version 1.3 is number 3, and version 2 is number 4.
# DEB_REAL_NUM_RELEASE is a scrubbed version of DEB_NUM_RELEASE.
# In order to provide bijective mappings, we must reject numbers that are out of bounds. So we accept 1 (buzz) to 13 (jessie) at this time.

DEB_RELEASE_NUM := $(shell echo "$(DEB_RELEASE)" | $(DEB_TOY_TO_NUM) | grep '^[0-9]*$$')
DEB_REAL_NUM_RELEASE := $(shell echo "$(DEB_RELEASE_NUM)" | grep '^[0-9]*$$' | awk '{ if ( ( NF >= 1 ) && ( $$1 >=1 ) && ( $$1 <= 13 ) ) { printf "%d" , $$1 ; } }' )

ifneq ($(DEB_RELEASE_NUM),)
  ifeq ($(DEB_REAL_NUM_RELEASE),)
    $(warning The Debian version specification is invalid. We will ignore it.)
  endif
  ifneq ($(UBUNTU_RELEASE),)
    $(warning We seem to have received an Ubuntu release specification and a Debian release specification. We will ignore the Debian release specification.)
  endif
endif

DEB_PACKAGE_REVISION := $(shell env UBUNTU_RELEASE="$(UBUNTU_RELEASE)" DEB_RELEASE="$(DEB_RELEASE)" DEB_RELEASE_NUM="$(DEB_RELEASE_NUM)" PACKAGE_VERSION="" $/scripts/gen-trailer.sh)
RETHINKDB_VERSION_DEB := $(RETHINKDB_PACKAGING_VERSION)$(DEB_PACKAGE_REVISION)

.PHONY: prepare_deb_package_dirs
prepare_deb_package_dirs:
	$P MKDIR $(DEB_PACKAGE_DIR) $(DEB_CONTROL_ROOT)
	mkdir -p $(DEB_PACKAGE_DIR)
	mkdir -p $(DEB_CONTROL_ROOT)

.PHONY: prepare_rpm_package_dirs
prepare_rpm_package_dirs: | $(RPM_PACKAGE_DIR)/.
	for d in BUILD RPMS/$(GCC_ARCH_REDUCED) SOURCES SPECS SRPMS; do mkdir -p $(RPM_PACKAGE_DIR)/$$d; done

.PHONY: install-rpm
install-rpm: DESTDIR = $(RPM_BUILD_ROOT)
install-rpm: install

.PHONY: install-deb
install-deb: DESTDIR = $(DEB_PACKAGE_DIR)
install-deb: install
	$P INSTALL $(DESTDIR)$(doc_dir)/changelog.Debian.gz
	install -m755 -d $(DESTDIR)$(doc_dir)
	sed -e 's/PACKAGING_VERSION/$(RETHINKDB_VERSION_DEB)/' $(ASSETS_DIR)/docs/changelog.Debian | \
	  gzip -c9 | \
	  install -m644 -T /dev/stdin $(DESTDIR)$(doc_dir)/changelog.Debian.gz

.PHONY: build-deb-support
ifeq ($(BUILD_PORTABLE),1)
  build-deb-support: $(LESSC) $(COFFEE) $(HANDLEBARS) $(V8_SRC_DIR) $(NODE_SRC_DIR) $(PROTOC_SRC_DIR) $(GPERFTOOLS_SRC_DIR) $(LIBUNWIND_SRC_DIR)
else
  build-deb-support: $(LESSC) $(COFFEE) $(HANDLEBARS)
endif

# TODO: the resulting package will not use the internal tools
.PHONY: build-deb-src
build-deb-src: build-deb-src-control build-deb-support
	rm -rf build support/build support/usr
	yes | debuild -S -sa

.PHONY: build-deb-src-control
build-deb-src-control:
	$P CP $(PACKAGING_DIR)/debian.template $/debian
	if [ -e $/debian ] ; then rm -rf $/debian ; fi
	cp -pRP $(PACKAGING_DIR)/debian.template $/debian
	env UBUNTU_RELEASE=$(UBUNTU_RELEASE) DEB_RELEASE=$(DEB_RELEASE) DEB_RELEASE_NUM=$(DEB_RELEASE_NUM) PACKAGE_NAME=$(PACKAGE_NAME) VERSIONED_PACKAGE_NAME=$(VERSIONED_PACKAGE_NAME) VERSIONED_QUALIFIED_PACKAGE_NAME=$(VERSIONED_QUALIFIED_PACKAGE_NAME) VANILLA_PACKAGE_NAME=$(VANILLA_PACKAGE_NAME) PACKAGE_VERSION_EXTENDED=$(RETHINKDB_VERSION_DEB) PACKAGE_VERSION=$(RETHINKDB_PACKAGING_VERSION) $/scripts/gen-changelog.sh ;
	$P M4 $(DEBIAN_PKG_DIR)/control $/debian/control
	env disk_size=0 \
	  m4 -D "PACKAGE_NAME=$(PACKAGE_NAME)" \
	     -D "VERSIONED_PACKAGE_NAME=$(VERSIONED_PACKAGE_NAME)" \
	     -D "VANILLA_PACKAGE_NAME=$(VANILLA_PACKAGE_NAME)" \
	     -D "VERSIONED_QUALIFIED_PACKAGE_NAME=$(VERSIONED_QUALIFIED_PACKAGE_NAME)" \
	     -D "PACKAGE_VERSION=$(RETHINKDB_VERSION_DEB)" \
	     -D "LEGACY_PACKAGE=$(LEGACY_PACKAGE)" \
	     -D "STATIC_V8=$(STATIC_V8)" \
	     -D "TC_BUNDLED=$(BUILD_PORTABLE)" \
	     -D "BUILD_DRIVERS=$(BUILD_DRIVERS)" \
	     -D "DISK_SIZE=$${disk_size}" \
	     -D "SOURCEBUILD=1" \
	     -D "NODEJS_NEW=$(NODEJS_NEW)" \
	     -D "CURRENT_ARCH=$(DEB_ARCH)" \
	     $(DEBIAN_PKG_DIR)/control > $/debian/control
	$P M4 preinst postinst prerm postrm $/debian
	for script in preinst postinst prerm postrm; do \
	  m4 -D "BIN_DIR=$(bin_dir)" \
	     -D "MAN1_DIR=$(man1_dir)" \
	     -D "BASH_COMPLETION_DIR=$(bash_completion_dir)" \
	     -D "INTERNAL_BASH_COMPLETION_DIR=$(internal_bash_completion_dir)" \
	     -D "SERVER_EXEC_NAME=$(SERVER_EXEC_NAME)" \
	     -D "SERVER_EXEC_NAME_VERSIONED=$(SERVER_EXEC_NAME_VERSIONED)" \
	     -D "UPDATE_ALTERNATIVES=$(NAMEVERSIONED)" \
	     -D "PRIORITY=$(PACKAGING_ALTERNATIVES_PRIORITY)" \
	     $(DEBIAN_PKG_DIR)/$${script} > $/debian/$${script}; \
	  chmod 0755 $/debian/$${script}; \
	done
	$P CP $(DEBIAN_PKG_DIR)/copyright > $/debian/copyright
	cat $(DEBIAN_PKG_DIR)/copyright > $/debian/copyright

.PHONY: build-deb
build-deb: all prepare_deb_package_dirs install-deb
	$P MD5SUMS $(DEB_PACKAGE_DIR)
	find $(DEB_PACKAGE_DIR) -path $(DEB_CONTROL_ROOT) -prune -o -path $(DEB_PACKAGE_DIR)/etc -prune -o -type f -printf "%P\\0" | \
	   (cd $(DEB_PACKAGE_DIR) && xargs -0 md5sum) > $(DEB_CONTROL_ROOT)/md5sums
	$P FIND $(DEB_CONTROL_ROOT)/conffiles
	find $(DEB_PACKAGE_DIR) -type f -printf "/%P\n" | (grep '^/etc/' | grep -v '^/etc/init\.d' || true) > $(DEB_CONTROL_ROOT)/conffiles
	$P M4 preinst postinst prerm postrm $(DEB_CONTROL_ROOT) 
	for script in preinst postinst prerm postrm; do \
	  m4 -D "BIN_DIR=$(bin_dir)" \
	     -D "MAN1_DIR=$(man1_dir)" \
	     -D "BASH_COMPLETION_DIR=$(bash_completion_dir)" \
	     -D "INTERNAL_BASH_COMPLETION_DIR=$(internal_bash_completion_dir)" \
	     -D "SERVER_EXEC_NAME=$(SERVER_EXEC_NAME)" \
	     -D "SERVER_EXEC_NAME_VERSIONED=$(SERVER_EXEC_NAME_VERSIONED)" \
	     -D "UPDATE_ALTERNATIVES=$(NAMEVERSIONED)" \
	     -D "PRIORITY=$(PACKAGING_ALTERNATIVES_PRIORITY)" \
	     $(DEBIAN_PKG_DIR)/$${script} > $(DEB_CONTROL_ROOT)/$${script}; \
	  chmod 0755 $(DEB_CONTROL_ROOT)/$${script}; \
	done
	$P M4 $(DEBIAN_PKG_DIR)/control $(DEB_CONTROL_ROOT)/control
	env disk_size=$$(du -s -k $(DEB_PACKAGE_DIR) | cut -f1); \
	  m4 -D "PACKAGE_NAME=$(PACKAGE_NAME)" \
	     -D "VERSIONED_PACKAGE_NAME=$(VERSIONED_PACKAGE_NAME)" \
	     -D "VANILLA_PACKAGE_NAME=$(VANILLA_PACKAGE_NAME)" \
	     -D "PACKAGE_VERSION=$(RETHINKDB_VERSION_DEB)" \
	     -D "VERSIONED_QUALIFIED_PACKAGE_NAME=$(VERSIONED_QUALIFIED_PACKAGE_NAME)" \
	     -D "LEGACY_PACKAGE=$(LEGACY_PACKAGE)" \
	     -D "STATIC_V8=$(STATIC_V8)" \
	     -D "TC_BUNDLED=$(BUILD_PORTABLE)" \
	     -D "BUILD_DRIVERS=$(BUILD_DRIVERS)" \
	     -D "DISK_SIZE=$${disk_size}" \
	     -D "SOURCEBUILD=0" \
	     -D "NODEJS_NEW=$(NODEJS_NEW)" \
	     -D "CURRENT_ARCH=$(DEB_ARCH)" \
	     $(DEBIAN_PKG_DIR)/control > $(DEB_CONTROL_ROOT)/control
	$P CP $(DEBIAN_PKG_DIR)/copyright $(DEB_CONTROL_ROOT)/copyright
	cat $(DEBIAN_PKG_DIR)/copyright > $(DEB_CONTROL_ROOT)/copyright
	$P DPKG-DEB $(DEB_PACKAGE_DIR) $(PACKAGES_DIR)
	fakeroot dpkg-deb -b $(DEB_PACKAGE_DIR) $(PACKAGES_DIR)

.PHONY: deb
deb: prepare_deb_package_dirs
	$P MAKE WAY=deb
	$(MAKE) WAY=deb
	for deb_name in $(PACKAGES_DIR)/*.deb; do \
	  if [ $(LINT) = 1]; then \
	    $P LINTIAN $$deb_name ; \
	    lintian --color auto --suppress-tags "no-copyright-file,$(subst $(space),$(comma),$(SUPPRESSED_LINTIAN_TAGS))" $${deb_name} || true ; \
	  fi \
	  $P DEB $$deb_name
	done

.PHONY: build-rpm
build-rpm: all prepare_rpm_package_dirs install-rpm
	$P M4 $(RPM_SPEC_INPUT) $(RPM_SPEC_FILE)
	m4 -D "RPM_PACKAGE_DIR=`readlink -f $(RPM_PACKAGE_DIR)`" \
	   -D "SERVER_EXEC_NAME=$(SERVER_EXEC_NAME)" \
	   -D "SERVER_EXEC_NAME_VERSIONED=$(SERVER_EXEC_NAME_VERSIONED)" \
	   -D "PACKAGE_NAME=$(PACKAGE_NAME)" \
	   -D "VERSIONED_PACKAGE_NAME=$(VERSIONED_PACKAGE_NAME)" \
	   -D "VERSIONED_QUALIFIED_PACKAGE_NAME=$(VERSIONED_QUALIFIED_PACKAGE_NAME)" \
	   -D "VANILLA_PACKAGE_NAME=$(VANILLA_PACKAGE_NAME)" \
	   -D "PACKAGE_VERSION=$(RETHINKDB_VERSION_DEB)" \
	   -D "PACKAGE=$(PACKAGE)" \
	   -D "PACKAGE_FOR_SUSE_10=$(PACKAGE_FOR_SUSE_10)" \
	   -D "BIN_DIR=$(bin_dir)" \
	   -D "DOC_DIR=$(doc_dir)" \
	   -D "MAN1_DIR=$(man1_dir)" \
	   -D "SHARE_DIR=$(share_dir)" \
	   -D "WEB_RES_DIR=$(web_res_dir)" \
	   -D "BASH_COMPLETION_DIR=$(bash_completion_dir)" \
	   -D "INTERNAL_BASH_COMPLETION_DIR=$(internal_bash_completion_dir)" \
	   -D "SCRIPTS_DIR=$(scripts_dir)" \
	   -D "PRIORITY=$(PACKAGING_ALTERNATIVES_PRIORITY)" \
	  $(RPM_SPEC_INPUT) > $(RPM_SPEC_FILE)
	$P RPMBUILD $(RPM_SPEC_FILE)
	rpmbuild -bb --target=$(GCC_ARCH_REDUCED) --buildroot `readlink -f $(RPM_BUILD_ROOT)` $(RPM_SPEC_FILE) \
	  > $(RPM_PACKAGE_DIR)/rpmbuild.stdout \
	  || ( tail -n 40 $(RPM_PACKAGE_DIR)/rpmbuild.stdout >&2 ; false )

# RPM for redhat and centos
.PHONY: rpm
rpm:
	$P MAKE WAY=rpm
	$(MAKE) WAY=rpm
	$P MAKE WAY=rpm-unstripped
	$(MAKE) WAY=rpm-unstripped
	for f in $(RPM_PACKAGE_DIR)/RPMS/$(GCC_ARCH_REDUCED)/*.rpm; do \
			rpm_name=$(PACKAGES_DIR)/$$(basename $$f) ; \
			mv $$f $$rpm_name ; \
			$P RPM $$rpm_name ; \
		done

.PHONY: rpm-suse10
rpm-suse10:
	$P MAKE WAY=rpm-suse10
	$(MAKE) WAY=rpm-suse10

.PHONY: install-osx
install-osx: DESTDIR = $(PACKAGING_DIR)/osx/pkg
install-osx: install-binaries install-web

.PHONY: build-osx
build-osx: install-osx
	mkdir -p $/build/packaging/osx/install
	pkgbuild --root $/build/packaging/osx/pkg --identifier rethinkdb $/build/packaging/osx/install/rethinkdb.pkg
	productbuild --distribution $/packaging/osx/Distribution.xml --package-path $/build/packaging/osx/install/ $/build/packaging/osx/dmg/rethinkdb.pkg
# TODO: the PREFIX should not be hardcoded in the uninstall script
	cp $/packaging/osx/uninstall-rethinkdb.sh $/build/packaging/osx/dmg/uninstall-rethinkdb.sh
	chmod +x $build/packaging/osx/dmg/uninstall-rethinkdb.sh
	hdiutil create -volname RethinkDB -srcfolder $/build/packaging/osx/dmg -ov $/build/packaging/osx/rethinkdb.dmg

.PHONY: osx
osx:
	$(MAKE) WAY=osx