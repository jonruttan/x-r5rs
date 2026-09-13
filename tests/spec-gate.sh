#!/bin/sh
# # x-r5rs -- the R5RS lang for x-lang
#
# ## tests/spec-gate.sh -- the bundle's shim
#
# @description Sources the platform's spec gate; vendors nothing.
# @author [Jon Ruttan](jonruttan@gmail.com)
# @copyright 2026 Jon Ruttan
# @license MIT No Attribution (MIT-0)
#
#     ., .,
#     {O,O}
#     (   )
#      " "
#
# The gate lives in the lang kit, not here: it is identical in every bundle, so
# one shared copy (x-lang#564, from v0.10.0) saves an N-repo re-vendor for every
# fix. X_LANG_KIT names a checkout's tools/lang-kit directly (what CI uses);
# otherwise the kit is found where x says its share tree is. Unlike
# release-refs this gate runs the suite, so an x is needed either way.
set -e

BUNDLE="$(cd "$(dirname "$0")/.." && pwd)"
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

[ -f "$KIT/spec-gate.sh" ] || {
	echo "x-r5rs: no spec-gate.sh under $KIT" >&2
	# v0.10.0 below is when the kit first shipped this, not the pairing.
	echo "  The lang kit ships it as of x-lang v0.10.0; this bundle declares which release." >&2  # release-ref: history
	exit 1
}

. "$KIT/spec-gate.sh"
