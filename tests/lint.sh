#!/bin/sh
# # x-r5rs -- R5RS Scheme on x-lang
#
# ## tests/lint.sh -- shim onto the lang kit's linter
#
# @description Sources the PLATFORM's lint; vendors nothing.  --strict
#   fails on the structural rules, which is how this bundle wants them.
# @author [Jon Ruttan](jonruttan@gmail.com)
# @copyright 2026 Jon Ruttan
# @license MIT No Attribution (MIT-0)
#
#     ., .,
#     {O,O}
#     (   )
#      " "
#
# THE BUNDLE WAS SWEPT BY NOTHING.  x-lang's `make lint-x` covers lib/ and
# apps/; a lang under languages/ was covered by neither.  This bundle grew
# its own `tools/check/if-ladders.sh` for exactly that reason -- one rule,
# kept locally because the sweep that knows it could not be run here.  That
# check stays: it carries a ratchet file this does not replace.  What this
# adds is every OTHER rule the linter knows, and a second opinion on the one
# they share.
#
# X_LANG_KIT names a checkout's tools/lang-kit directly, the spelling
# tests/spec-gate.sh already takes; otherwise the kit is found where x says
# its share tree is.  An x is needed either way -- the kit's lint.sh asks it
# for --share-dir and --engine-path itself.
set -e

BUNDLE="$(cd "$(dirname "$0")/.." && pwd)"
X="${X:-x}"

command -v "$X" >/dev/null 2>&1 || {
	echo "x-r5rs: no x on PATH.  Set X=/path/to/x and retry." >&2
	exit 2
}

# The tree the kit's lint.sh will actually read, whatever X_LANG_KIT says:
# it resolves its linter from --share-dir, so that is what the probe below
# has to judge.
X_ROOT="$("$X" --share-dir)"
KIT="${X_LANG_KIT:-$X_ROOT/tools/lang-kit}"

# A GATE THE PLATFORM CANNOT RUN YET SKIPS; it does not fail the build.
# tests/spec-gate.sh hard-fails on a missing kit and that is right for a
# file every x has shipped for months.  The linter is newer, and the fixes
# this bundle's sources need are newer still, so hard-failing here would
# break `make check` on every x that exists until a release lands -- and
# that is a cadence this bundle does not set.
[ -f "$KIT/lint.sh" ] || {
	echo "x-r5rs: SKIPPING lint -- no $KIT/lint.sh in this x." >&2
	echo "x-r5rs: it arrives with the lang kit's linter; upgrade x to gate on it." >&2
	exit 0
}

# THE CAPABILITY, NOT THE VERSION NUMBER.  A version test would misjudge
# every tree between releases, which is what CI's `main` leg is.  These two
# names are the fixes themselves:
#
#   build/boot/x-base.x  -- x-lang#687.  A CHECKOUT keeps the boot amalgam at
#     build/boot/, an install at boot/, and only the installed path was
#     looked for; the checkout fell through to lib/x-core.x, whose opening
#     include is root-relative, and every file in every group died on
#     `include: cannot open`.  This bundle's CI points X at a checkout's
#     ./x.sh, so without it the gate cannot run in CI at all.
#
#   _lang_constructs_for -- x-lang#686.  The driver loading a bundle's own
#     construct table (r5rs/constructs.x).  Without it `define`, `lambda`
#     and `let*` are ordinary calls, and scripts/r5rs-tests.x -- thirty of
#     them -- is analysed against a table that does not describe it.
#
# Both are in main and in no release yet; they land together.
if ! grep -q 'build/boot/x-base.x' "$X_ROOT/tools/dev/lint.sh" 2>/dev/null ||
   ! grep -q '_lang_constructs_for' "$X_ROOT/tools/dev/lint.sh" 2>/dev/null; then
	echo "x-r5rs: SKIPPING lint -- this x's linter predates the fixes this" >&2
	echo "x-r5rs: gate needs (x-lang#686, #687).  Upgrade x to gate on it." >&2
	exit 0
fi

# WHAT THIS GATE DOES NOT CATCH TODAY, written here rather than discovered
# later: the linter's `Undefined` rule is DEAD in this bundle.  Plant
# `(def %probe (fn (_) (undefined-name-alpha 1)))` in r5rs/printer.x and this
# gate still says ok -- while the same plant reports correctly with no bundle
# preload, and reports correctly in x-krn.  Measured cause: under this
# bundle's preload the linter records ZERO uses for the file, so the rule has
# nothing to filter.  x-lang#690 carries the reproduction and the hypotheses
# already ruled out.
#
# The STRUCTURAL rules DO fire -- a planted four-arm ladder is reported -- and
# those are what --strict gates on, so this is worth running.  It is just not
# yet the undefined-name check it looks like.
#
# No targets are named: the kit's default is every .x the bundle ships minus
# the generated harness, which for this one is r5rs/, scripts/ and
# tools/check/ -- all of it worth sweeping.
BUNDLE="$BUNDLE" X="$X" sh "$KIT/lint.sh" --strict "$@"
