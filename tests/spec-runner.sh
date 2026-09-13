#!/bin/sh
# # x-r5rs -- the R5RS lang for x-lang
#
# ## tests/spec-runner.sh -- the bundle's runner
#
# @description Sources the platform's spec runner; vendors nothing.
# @author [Jon Ruttan](jonruttan@gmail.com)
# @copyright 2026 Jon Ruttan
# @license MIT No Attribution (MIT-0)
#
#     ., .,
#     {O,O}
#     (   )
#      " "
#
# No path reaches into an x-lang source tree; everything comes from x itself.
# --share-dir gives the tree x reads from (repo root in a checkout, share/x
# when installed) and --engine-path gives the engine location after the
# wrapper's discovery order.
#
# Set X to point at a particular x; otherwise the one on PATH is used.
set -e

BUNDLE="$(cd "$(dirname "$0")/.." && pwd)"
X="${X:-x}"

command -v "$X" >/dev/null 2>&1 || {
	echo "x-r5rs: no x on PATH.  Set X=/path/to/x.sh and retry." >&2
	exit 1
}

# --share-dir answers from any cwd.
X_ROOT="$("$X" --share-dir)"
# X_BIN is env-overridable, the way tests/x/spec-runner.sh makes it -- so the
# same runner can drive a variant or patched engine without moving anything.
X_BIN="${X_BIN:-$("$X" --engine-path)}"

# The platform runner locates its awk harness relative to the engine binary,
# which sits beside tests/ in a checkout but under libexec/x in an install; a
# sourced script cannot portably find its own path, so the caller sets this.
SPEC_RUNNER_DIR="$X_ROOT/tests"
export SPEC_RUNNER_DIR

# The harness is GENERATED, never committed: it embeds two absolute paths
# that are facts of this machine, not of the bundle.
sh "$BUNDLE/tests/gen-harness.sh" "$X_ROOT" "$BUNDLE"

LANG_LIB="$BUNDLE/tests/lib/harness.gen.x"
# SPEC_PATH is env-overridable so a single spec file can be run in isolation
# while diagnosing, without moving anything into the suite.
SPEC_PATH="${SPEC_PATH:-$BUNDLE/tests/specs}"

# The suite boots from a state image of the harness when the platform can write
# one; for a bundle this size the boot is most of the cost. tools/dev/image-
# build.sh images a child base that loaded the harness and keys the image on
# what it depends on -- the harness, the platform's lib/, its engine, and the
# trees the harness armed (read back off its import-path! lines) -- so a change
# to any of them rewrites the image rather than leaving a stale one.
#
# The writer lives in a checkout only; an installed tree, and any release older
# than the image tools, boots from source and says so. IMG=0 is the control:
# the same suite from source, one file per process either way, so the boot is
# the only difference -- and the first thing to try against a failure that
# reproduces nowhere else.
if [ "${IMG:-1}" = 0 ]; then
	SPEC_BATCH="${SPEC_BATCH:-1}"; export SPEC_BATCH
else
	_builder="$X_ROOT/tools/dev/image-build.sh"
	# A platform that images its JIT trampolines cannot carry an image that
	# compiles: those addresses were held as plain integers from dlsym, so an
	# image would carry the writer process's addresses and a compile after a
	# load would jump into them. x-lang made them transients the recache hook
	# remakes; the probe is for that fix, not a version.
	_asm="$X_ROOT/lib/x/tool/asm-compile.x"
	if [ -f "$_asm" ] && ! grep -q "image-transients" "$_asm"; then
		echo "x-r5rs: platform images the JIT trampoline addresses (pre-41b93185) -- the suite boots from source" >&2
		_builder=""
	fi
	# A platform whose recache walk is shaped like R5RS iteration cannot run a
	# hook in this bundle: %image-recache! runs after the install, in the
	# imaged lang's environment, and r5rs re-means `do` as iteration told apart
	# from sequencing by shape, so a walk spelled that way visits every hook and
	# calls none. Comments are stripped before the match, because the platform's
	# fix quotes the broken spelling in its own note, so a probe must read only
	# the code. A platform without the fix boots from source.
	_reflect="$X_ROOT/lib/x/boot/reflect.x"
	if [ -f "$_reflect" ] && sed 's/;.*//' "$_reflect" | grep -q 'do ((first l)) (self (rest l))'; then
		echo "x-r5rs: platform's (%image-recache!) is shaped like R5RS iteration -- the suite boots from source" >&2
		_builder=""
	fi
	if [ -f "$_builder" ]; then
		# The trees the harness armed, in the order it armed them.
		_keys=$(sed -n 's/^(import-path! "\(.*\)")$/\1/p' "$LANG_LIB")
		#  .scm IS PART OF THIS BUNDLE'S SOURCE, AND THE KEY HAS TO SAY SO.
		# image-build.sh keys a KEY-PATH by EXTENSION, and its default names .x
		# alone -- while NINE of this lang's files are .scm: derived, equiv,
		# list, char, string, numeric, control, ports, macro.  They ARE the R5RS
		# library.  Left out of the key, editing one changes nothing the builder
		# hashes: it answers "is current", and the suite goes on testing the
		# library that was there BEFORE while its from-source control tests the
		# one on disk.  Both legs green, at two different libraries, and no diff
		# shows it -- the quietest failure this wiring can have, and the reason
		# it is armed here rather than left to be noticed.
		#  IMG_KEY_EXT is the platform's door for saying so (x-lang v0.14.0):
		# the caller that arms a tree is the only thing that can know what its
		# modules are spelled in, so the platform carries no lang's vocabulary.
		# An older builder ignores the variable and keys .x alone, which is what
		# this bundle did before -- so this neither breaks nor silently helps on
		# a platform that predates it.
		if IMG_KEY_EXT="x scm" X_BIN="$X_BIN" sh "$_builder" "$LANG_LIB" "$BUNDLE/tests/lib/.images" $_keys; then
			X_IMG_DIR="$BUNDLE/tests/lib/.images"; export X_IMG_DIR
		else
			echo "x-r5rs: no state image (image-build exit $?) -- the suite boots from source" >&2
		fi
	elif [ -n "$_builder" ]; then
		# Only when the writer is genuinely absent.  A probe above that
		# cleared $_builder has already said why, and this line claiming a
		# missing writer on top of it named the wrong cause.
		echo "x-r5rs: no image writer at $_builder -- the suite boots from source" >&2
	fi
fi

. "$X_ROOT/tests/spec-runner.sh"
