#!/bin/sh
# # x-r5rs -- the R5RS lang for x-lang
#
# ## tools/check/release-refs.sh -- the bundle's shim
#
# @description Sources the platform's release-refs check; vendors nothing.
# @author [Jon Ruttan](jonruttan@gmail.com)
# @copyright 2026 Jon Ruttan
# @license MIT No Attribution (MIT-0)
#
#     ., .,
#     {O,O}
#     (   )
#      " "
#
# The check lives in the lang kit, not here: it is identical in every bundle,
# so one shared copy saves an N-repo re-vendor for every fix. It needs no
# platform to run -- it reads lang.xon and greps the tree -- so X_LANG_KIT
# names a checkout's tools/lang-kit directly (what CI uses), and otherwise it
# asks x where its share tree is.
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
