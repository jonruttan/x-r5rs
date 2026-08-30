# x-r5rs -- the R5RS lang for x-lang
#
# INSTALL PUTS THIS BUNDLE WHERE `-l` LOOKS, which is the whole of it: an
# installed x searches <share>/langs/*/lang.xon, so a lang is "installed" when
# its files are there.  No registry, no database, no per-project pin.
#
#   make install                  into the x on PATH
#   PREFIX=$HOME/.local make install    into a particular prefix
#
# PIN OR INSTALL, AND THEY ANSWER DIFFERENT QUESTIONS.  A pin (lang.pin.xon +
# Pin bundle) freezes a verified tarball for ONE project and is what a build
# should depend on.  An install puts one copy on the machine for every project
# and for the prompt -- convenient, unversioned, and exactly like installing a
# language runtime.  Use the pin when it matters which version; use this when
# you just want `x -l r5rs` to work.

X ?= x

# THE VERSION IS DERIVED, NEVER COMMITTED, and that is deliberate.
#
# A version row in lang.xon can only be true at ONE commit: the one you tag.
# Bump it and tag it and the tree is honest for exactly that moment; every
# commit after claims a release it is not, and a checkout of main always lies.
# git describe does not -- v0.2.0-3-gabc123-dirty says precisely where you are.
#
# So lang.xon declares what this lang REQUIRES, and the installed artifact
# carries what it IS.  Same split, and the same mechanism, as x-lang's own
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
check: check-release-refs ## Run the suite against tests/contract/known-failures.txt -- what CI gates on
	X="$(X)" sh tests/spec-gate.sh

# Seconds, and no platform needed: it reads lang.xon and greps the tree.  It
# rides `check` rather than a tier of its own because the thing it catches --
# a README naming a release nobody tested -- ships silently otherwise.
.PHONY: check-release-refs
check-release-refs: ## Assert the declared x-lang release is named in one place
	X="$(X)" sh tools/check/release-refs.sh

.PHONY: bundle
bundle: ## Roll a release tarball and print its pin
	sh tools/bundle.sh

.PHONY: help
help: ## Show targets
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "  \033[32m%-12s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
