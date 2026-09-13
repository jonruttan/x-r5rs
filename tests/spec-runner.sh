#!/bin/sh
# # x-r5rs -- the R5RS personality for x-lang
#
# ## tests/spec-runner.sh -- the bundle's runner
#
# @description Sources the PLATFORM's spec runner; vendors nothing.
# @author [Jon Ruttan](jonruttan@gmail.com)
# @copyright 2026 Jon Ruttan
# @license MIT No Attribution (MIT-0)
#
#     ., .,
#     {O,O}
#     (   )
#      " "
#
# NOT ONE PATH INTO THE X-LANG SOURCE TREE.  The 2024 runner reached the
# platform as "$SCRIPT_DIR/../../../tests/spec-runner.sh" and both that and
# its X_BIN dangled the moment the personality left the repo -- the failure
# x-lang docs/personality-contract.md calls "addressing, not sharing".
# Everything here comes from x itself: --share-dir says which tree x reads
# from (repo root in a checkout, share/x installed) and --engine-path says
# where the engine is after the wrapper's full discovery order.
#
# Set X to point at a particular x; otherwise the one on PATH is used.
set -e

BUNDLE="$(cd "$(dirname "$0")/.." && pwd)"
X="${X:-x}"

command -v "$X" >/dev/null 2>&1 || {
	echo "x-r5rs: no x on PATH.  Set X=/path/to/x.sh and retry." >&2
	exit 1
}

# --share-dir answers from ANY cwd as of x-lang 990c4a35.  It did not at first:
# mode detection is cwd-based, so a checkout's x.sh asked from outside took the
# installed branch and computed a share/x no checkout has.  This runner used to
# cd to the wrapper's own directory before asking -- the guessing the flag
# exists to end.  Reported, fixed upstream, dance removed.
X_ROOT="$("$X" --share-dir)"
# X_BIN is env-overridable, the way tests/x/spec-runner.sh makes it -- so the
# same runner can drive a variant or patched engine without moving anything.
X_BIN="${X_BIN:-$("$X" --engine-path)}"

# REQUIRED FROM AN INSTALLED TREE.  The runner finds its awk harness from the
# directory holding the ENGINE -- true in a checkout, where the binary sits
# beside tests/, and false in an install, where the engine is under libexec/x.
# A sourced script cannot portably find its own path, so the caller says.
SPEC_RUNNER_DIR="$X_ROOT/tests"
export SPEC_RUNNER_DIR

# The harness is GENERATED, never committed: it embeds two absolute paths
# that are facts of this machine, not of the bundle.
sh "$BUNDLE/tests/gen-harness.sh" "$X_ROOT" "$BUNDLE"

LANG_LIB="$BUNDLE/tests/lib/harness.gen.x"
# SPEC_PATH is env-overridable so a single spec file can be run in isolation
# while diagnosing, without moving anything into the suite.
SPEC_PATH="${SPEC_PATH:-$BUNDLE/tests/specs}"

# THE SUITE BOOTS FROM A STATE IMAGE OF THE HARNESS, when the platform can
# write one -- and for a bundle this size the BOOT is what the suite costs.
# Every spec file is its own process, and each one reads the tower and this
# lang from source before its first case; x-python measured the same shape at
# 26 seconds of boot in a 38-second file, two thirds of its wall clock
# (x-python#43, which is where this block comes from -- x-awk has run this way
# since 2026-09-06).
#
# tools/dev/image-build.sh images a child base that loaded the harness and
# keys the image on what it depends on: the harness, the platform's lib/, its
# engine, and every tree the harness armed -- read back off the generated
# harness itself (its `import-path!` lines are this bundle and, for a lang
# built on another, the lang beneath it), so a change to EITHER rewrites the
# image rather than leaving a stale one that still answers.
#
# The writer lives in a CHECKOUT only; an installed tree, and any release
# older than the image tools, boots from source and says so -- which is what
# the pinned leg does until this bundle's (requires-release ...) names a
# release carrying them.  IMG=0 is the control: the same suite from source,
# one file per process either way, so the boot is the only difference -- and
# it is the FIRST thing to try against a failure that reproduces nowhere
# else, because a stale or wrong image is invisible in a diff.
if [ "${IMG:-1}" = 0 ]; then
	SPEC_BATCH="${SPEC_BATCH:-1}"; export SPEC_BATCH
else
	_builder="$X_ROOT/tools/dev/image-build.sh"
	# A PLATFORM THAT IMAGES ITS JIT TRAMPOLINES CANNOT CARRY AN IMAGE THAT
	# COMPILES, and the failure is a SIGSEGV rather than a wrong answer:
	# tool/asm-compile.x held those addresses as plain integers from dlsym, so
	# an image carries the WRITER process's addresses and a compile on the far
	# side of a load jumps into them (x-python#43 saw exit 139 on the analyser
	# swap).  x-lang 41b93185 made them transients the recache hook remakes;
	# the probe is for the FIX and not for a version, so a platform that has
	# it is used and one that has not boots from source.
	_asm="$X_ROOT/lib/x/tool/asm-compile.x"
	if [ -f "$_asm" ] && ! grep -q "image-transients" "$_asm"; then
		echo "x-r5rs: platform images the JIT trampoline addresses (pre-41b93185) -- the suite boots from source" >&2
		_builder=""
	fi
	# A PLATFORM WHOSE RECACHE WALK IS SHAPED LIKE R5RS ITERATION RESTORES
	# NOTHING, and the failure is a WRONG ANSWER rather than a crash.  Scheme's
	# `do` iterates where x's sequences, so scm/derived.scm dispatches on shape:
	# a first operand that is a list of pairs is iteration, anything else is
	# handed to the platform's sequencer.  boot/reflect.x spelled its hook walk
	# `(do ((first l)) (self (rest l)))` -- one binding list, then a (test .
	# results) pair -- which is iteration by that rule, so (%image-recache!)
	# walked the whole hook list and called NO HOOK.  Nothing raises: every
	# value the writer nil'd as a transient stays nil, and the first thing to
	# fail is a float parsed through float.x's strtod handle -- `ffi-call
	# s0->d: nil`, 34 of those and a hundred more dying around them, thousands
	# of forms from the cause.  Only an IMAGE boot reaches the hooks at all,
	# which is why the suite from source never saw it.
	#  The probe is for the DEFECT'S OWN SPELLING, not for a version and not
	# for the fix: a platform that has rewritten the walk any other way is
	# taken at its word, the way the asm-compile probe above takes a platform
	# that has made its trampolines transients.
	#  COMMENTS ARE STRIPPED BEFORE THE MATCH, because the platform's fix
	# QUOTES the broken spelling in the comment that explains it -- so a
	# probe that grepped the file whole reported the defect on a platform
	# that had just been fixed, and the suite booted from source with a
	# message saying the opposite of the truth.  `;` begins a comment in x
	# and reflect.x has no string holding one.
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
