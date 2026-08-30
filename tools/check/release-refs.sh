#!/bin/sh
# release-refs.sh -- the x-lang release this bundle names is written ONCE.
#
# lang.xon's (requires-release ...) is the fact.  Everything else that names an
# x-lang release -- the README's status line, a workflow, a doc -- is a COPY,
# and a copy that nobody checks is a copy that goes stale on the next platform
# release and tells the next reader something false.
#
# WHY A GATE AND NOT A CONVENTION.  The failure is silent and delayed: the
# bundle keeps working, its suite stays green, and the only symptom is a README
# claiming a pairing nobody tested.  It surfaces when someone believes it.
#
# WHAT IT CHECKS.  A release string ATTACHED to the name x-lang -- within a
# couple of dozen characters of it, so `x-lang v0.7.0` and `x-lang: ['v0.7.0']`
# both count -- must be the declared one.  Proximity is what does the work
# here: every version in this tree is the same shape, and only what it sits
# next to says whether it is x-lang's, this bundle's, or the engine's.
#
# `x-lang#527` IS AN ISSUE, NOT A RELEASE, and the pattern stops at the #.
# Without that this fires on r5rs/aliases.x, where an issue reference and an
# ENGINE version share a line and neither is a claim about the platform.
#
# THE ESCAPE HATCH IS EXPLICIT, because history is a legitimate thing to write
# down: a line carrying `release-ref: history` is skipped, and saying so is the
# point.  A silent exemption would make this gate a suggestion.
set -e

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

MANIFEST=lang.xon
[ -f "$MANIFEST" ] || { echo "release-refs: no $MANIFEST" >&2; exit 2; }

declared=$(sed -n 's/^(requires-release "\(.*\)")$/\1/p' "$MANIFEST")
[ -n "$declared" ] || {
	echo "release-refs: $MANIFEST declares no (requires-release ...)" >&2
	exit 2
}

# Tracked files only, and never the manifest itself: the fact may repeat inside
# the file that owns it, where the surrounding prose is what explains it.
files=$(git ls-files | grep -v "^$MANIFEST$" || true)
[ -n "$files" ] || { echo "release-refs: no tracked files" >&2; exit 2; }

# -I skips binaries (the standards PDFs), which would otherwise match as noise.
# The window after `x-lang` allows markdown bold and a YAML key, and excludes
# `#` so an issue reference cannot open one.
PATTERN='x-lang[^#]\{0,24\}v[0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}'
VERSION='v[0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}'

hits=$(mktemp)
trap 'rm -f "$hits"' EXIT
grep -In "$PATTERN" -- $files 2>/dev/null | grep -v 'release-ref: history' > "$hits" || true

bad=0
# Redirected rather than piped, so `bad` survives the loop.
while IFS= read -r line; do
	[ -n "$line" ] || continue
	where=$(printf '%s' "$line" | cut -d: -f1,2)
	for found in $(printf '%s' "$line" | grep -o "$PATTERN" | grep -o "$VERSION" | sort -u); do
		if [ "$found" != "$declared" ]; then
			echo "release-refs: $where names x-lang $found, $MANIFEST declares $declared" >&2
			bad=1
		fi
	done
done < "$hits"

if [ "$bad" -ne 0 ]; then
	echo "" >&2
	echo "  These are one fact.  Update $MANIFEST and the copies together," >&2
	echo "  or mark a deliberate historical mention with 'release-ref: history'." >&2
	exit 1
fi

echo "release-refs: ok -- x-lang $declared, and nothing claims otherwise"
