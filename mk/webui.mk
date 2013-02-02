#### Web UI sources

WEB_SOURCE_DIR := $/admin
WEB_ASSETS_OBJ_DIR := $(BUILD_DIR)/webobj
WEB_ASSETS_RELATIVE := cluster-min.js cluster.css index.html js fonts images favicon.ico js/rethinkdb.js js/template.js
WEB_ASSETS := $(foreach a,$(WEB_ASSETS_RELATIVE),$(WEB_ASSETS_BUILD_DIR)/$(a))

# coffee script can't handle dependencies.
COFFEE_SOURCES := $(patsubst %, $(WEB_SOURCE_DIR)/static/coffee/%,\
			util.coffee \
			loading.coffee \
			body.coffee \
			ui_components/modals.coffee ui_components/list.coffee ui_components/progressbar.coffee \
			namespaces/database.coffee \
			namespaces/index.coffee namespaces/replicas.coffee namespaces/shards.coffee namespaces/server_assignments.coffee namespaces/namespace.coffee \
			servers/index.coffee servers/machine.coffee servers/datacenter.coffee \
			dashboard.coffee \
			dataexplorer.coffee \
			sidebar.coffee \
			resolve_issues.coffee \
			log_view.coffee \
			vis.coffee \
			models.coffee \
			navbar.coffee \
			router.coffee \
			app.coffee)
LESS_SOURCES := $(shell find $(WEB_SOURCE_DIR)/static/less -name '*.less')
LESS_MAIN := $(WEB_SOURCE_DIR)/static/less/styles.less
CLUSTER_HTML := $(WEB_SOURCE_DIR)/templates/cluster.html
JS_EXTERNAL_DIR := $(WEB_SOURCE_DIR)/static/js
FONTS_EXTERNAL_DIR := $(WEB_SOURCE_DIR)/static/fonts
IMAGES_EXTERNAL_DIR := $(WEB_SOURCE_DIR)/static/images
FAVICON := $(WEB_SOURCE_DIR)/favicon.ico

$(WEB_ASSETS_BUILD_DIR)/js/rethinkdb.js: $(JS_BUILD_DIR)/rethinkdb.js | $(WEB_ASSETS_BUILD_DIR)/js/.
	$P CP
	cp -pRP $< $@

rpc/semilattice/joins/macros.hpp: $/scripts/generate_join_macros.py
rpc/serialize_macros.hpp: $/scripts/generate_serialize_macros.py
rpc/mailbox/typed.hpp: $/scripts/generate_rpc_templates.py
rpc/semilattice/joins/macros.hpp rpc/serialize_macros.hpp rpc/mailbox/typed.hpp:
	$P GEN $@
	$< > $@

ALL += $/admin
all-$/admin: web-assets

CLEAN += $/admin
clean-$/admin:
	$P RM $(WEB_ASSETS_BUILD_DIR)
	rm -rf $(WEB_ASSETS_BUILD_DIR)
	$P RM $(WEB_ASSETS_OBJ_DIR)
	rm -rf $(WEB_ASSETS_OBJ_DIR)

.PHONY: web-assets
web-assets: $(WEB_ASSETS)

$(WEB_ASSETS_BUILD_DIR)/js/template.js: $(WEB_SOURCE_DIR)/static/handlebars $(HANDLEBARS) $/scripts/build_handlebars_templates.py | $(WEB_ASSETS_BUILD_DIR)/js/.
	$P HANDLEBARS $@
	env TC_HANDLEBARS_EXE=$(HANDLEBARS) $/scripts/build_handlebars_templates.py $(WEB_SOURCE_DIR)/static/handlebars $(BUILD_DIR) $(WEB_ASSETS_BUILD_DIR)/js

$(WEB_ASSETS_OBJ_DIR)/cluster-min.concat.coffee: $(COFFEE_SOURCES) | $(WEB_ASSETS_OBJ_DIR)/.
	$P CONCAT $@
	cat $+ > $@

$(WEB_ASSETS_BUILD_DIR)/cluster-min.js: $(WEB_ASSETS_OBJ_DIR)/cluster-min.concat.coffee $(COFFEE) | $(WEB_ASSETS_BUILD_DIR)/.
	$P COFFEE $@
	$(COFFEE) -bp --stdio < $(WEB_ASSETS_OBJ_DIR)/cluster-min.concat.coffee > $@

$(WEB_ASSETS_BUILD_DIR)/cluster.css: $(LESS_MAIN) $(LESSC) | $(WEB_ASSETS_BUILD_DIR)/.
	$P LESSC $@
	@echo "    LESSC $@"
	$(LESSC) $(LESS_MAIN) > $@

$(WEB_ASSETS_BUILD_DIR)/index.html: $(CLUSTER_HTML) | $(WEB_ASSETS_BUILD_DIR)/.
	$P SED
	sed "s/{RETHINKDB_VERSION}/$(RETHINKDB_VERSION)/" $(CLUSTER_HTML) > $@

$(WEB_ASSETS_BUILD_DIR)/js: | $(WEB_ASSETS_BUILD_DIR)/.
	$P CP $(JS_EXTERNAL_DIR) $(WEB_ASSETS_BUILD_DIR)
	cp -RP $(JS_EXTERNAL_DIR) $(WEB_ASSETS_BUILD_DIR)

$(WEB_ASSETS_BUILD_DIR)/fonts: | $(WEB_ASSETS_BUILD_DIR)/.
	$P CP $(FONTS_EXTERNAL_DIR) $(WEB_ASSETS_BUILD_DIR)
	cp -RP $(FONTS_EXTERNAL_DIR) $(WEB_ASSETS_BUILD_DIR)

$(WEB_ASSETS_BUILD_DIR)/images: | $(WEB_ASSETS_BUILD_DIR)/.
	$P CP $(IMAGES_EXTERNAL_DIR) $(WEB_ASSETS_BUILD_DIR)
	cp -RP $(IMAGES_EXTERNAL_DIR) $(WEB_ASSETS_BUILD_DIR)

$(WEB_ASSETS_BUILD_DIR)/favicon.ico: $(FAVICON) | $(WEB_ASSETS_BUILD_DIR)/.
	$P CP $(FAVICON) $(WEB_ASSETS_BUILD_DIR)
	cp -P $(FAVICON) $(WEB_ASSETS_BUILD_DIR)
