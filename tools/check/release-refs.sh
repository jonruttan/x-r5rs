#!/bin/sh
# # x-r5rs -- R5RS Scheme on x-lang
#
# ## tools/check/release-refs.sh -- the bundle's shim
#
# @description Sources the PLATFORM's release-refs check; vendors nothing.
# @author [Jon Ruttan](jonruttan@gmail.com)
# @copyright 2026 Jon Ruttan
# @license MIT No Attribution (MIT-0)
#
#     ., .,
#     {O,O}
#     (   )
#      " "
#
# THE SAME RULING AS tests/spec-runner.sh, and for the same reason: this check
# is identical in every bundle, so a copy per repository buys nothing and costs
# an N-repo re-vendor for every fix.  It was written twice before it moved to
# the platform, and the second copy needed three fixes backported the day it
# was written.
#
# TWO WAYS TO REACH THE KIT, because this check needs no platform to run.  It
# reads lang.xon and greps the tree; forcing an x onto it would turn a
# one-second text check into a build.  So X_LANG_KIT names a checkout's
# tools/lang-kit directly -- what CI uses, having checked x-lang out already --
# and everything else falls back to asking x where its share tree is.
set -e

BUNDLE="$(cd "$(dirname "$0")/../.." && pwd)"
export BUNDLE

if [ -n "$X_LANG_KIT" ]; then
	KIT="$X_LANG_KIT"
else
	X="${X:-x}"
	command -v "$X" >/dev/null 2>&1 || {
		echo "x-r5rs: no x on PATH, and X_LANG_KIT is unset." >&2
		echo "  Set X=/path/to/x.sh, or X_LANG_KIT=/path/to/x-lang/tools/lang-kit" >&2
		exit 1
	}
	KIT="$("$X" --share-dir)/tools/lang-kit"
fi

[ -f "$KIT/release-refs.sh" ] || {
	echo "x-r5rs: no release-refs.sh under $KIT" >&2
	echo "  The lang kit ships with x-lang; this bundle declares which one." >&2
	exit 1
}

. "$KIT/release-refs.sh"
