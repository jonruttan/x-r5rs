# x-r5rs -- the R5RS lang for x-lang
#
# Install copies this bundle to <share>/langs/r5rs, where `x -l` looks: a lang
# is installed when its files are there. No registry, no database.
#
#   make install                        into the x on PATH
#   PREFIX=$HOME/.local make install    into a particular prefix
#
# A pin (lang.pin.xon + Pin bundle) freezes a verified tarball for one project
# and is what a build should depend on. An install is one unversioned copy for
# the whole machine. Pin when the version matters; install to get `x -l r5rs`
# working.

X ?= x

# The version is derived from git describe, never committed: a version literal
# is true only at the commit it is tagged on and wrong on every commit after.
# lang.xon declares what this bundle requires; the installed artifact carries
# what it is, in a version stamp -- the same split as x-lang's own
# $(X_RELEASE) -> <lib>/contract/release.
LANG_VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
# PREFIX wins when given, so this matches x-lang's own `PREFIX=... make
# install`.  Otherwise ask the x on PATH where its tree is -- the question
# --share-dir exists to answer.
SHARE := $(if $(PREFIX),$(PREFIX)/share/x,$(shell $(X) --share-dir))
DEST  := $(SHARE)/langs/r5rs

# What a consumer needs to RUN the lang: the declaration, the entry, the
# modules.  Not the suite, not the tooling, not CI -- those are this
# repository's business, not the installed platform's.
PAYLOAD := lang.xon run.x r5rs

.PHONY: install
install: ## Install into <share>/langs/r5rs
	@test -n "$(SHARE)" || { echo "x-r5rs: cannot find an x tree -- set PREFIX or X" >&2; exit 1; }
	@test -d "$(SHARE)" || { echo "x-r5rs: no x tree at $(SHARE)" >&2; exit 1; }
	rm -rf "$(DEST)"
	mkdir -p "$(DEST)"
	cp -R $(PAYLOAD) "$(DEST)/"
	printf '%s\n' '$(LANG_VERSION)' > "$(DEST)/version"
	@echo "x-r5rs: installed to $(DEST)"
	@echo "x-r5rs: try  x -l r5rs"

.PHONY: uninstall
uninstall: ## Remove it again
	rm -rf "$(DEST)"
	@echo "x-r5rs: removed $(DEST)"

.PHONY: test
test: ## Run the spec suite (every failure is loud)
	X="$(X)" sh tests/spec-runner.sh

.PHONY: check
check: check-release-refs check-if-ladders ## Run the suite against tests/contract/known-failures.txt -- what CI gates on
	X="$(X)" sh tests/spec-gate.sh

# Seconds, and no platform needed: it reads lang.xon and greps the tree.  It
# rides `check` rather than a tier of its own because the thing it catches --
# a README naming a release nobody tested -- ships silently otherwise.
.PHONY: check-release-refs
check-release-refs: ## Assert the declared x-lang release is named in one place
	X="$(X)" sh tools/check/release-refs.sh

# `match` is the primitive for a decision with arms; a nested-if chain is not.
# It rides `check` for the same reason release-refs does -- the shape it
# catches is invisible in a diff that only shows the new arm.
.PHONY: check-if-ladders
check-if-ladders: ## Assert no new nested-if ladders (tools/contract/if-ladders.txt)
	X="$(X)" sh tools/check/if-ladders.sh

.PHONY: bundle
bundle: ## Roll a release tarball and print its pin
	sh tools/bundle.sh

.PHONY: help
help: ## Show targets
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "  \033[32m%-12s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
