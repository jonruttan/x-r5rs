#!/bin/sh
# release-refs.sh -- a version this bundle DECLARES is named once, and gated.
#
# lang.xon carries one of them today:
#
#   (requires-release "vN.N.N")        the x-lang this bundle was built against
#
# A (requires-lang ...) row would add a second, and the scan below is already
# table-driven over however many there are -- x-r7rs runs the same file with
# two.  This is the copy that will collect into the shared kit; until it does,
# the two must not diverge, which is why this carries x-r7rs's fixes verbatim.
#
# Everything else naming either -- the README's status line, a workflow, a doc
# -- is a COPY, and a copy nobody checks goes stale on the next release and
# tells the next reader something false.  The bundle keeps working, the suite
# stays green, and the only symptom is a claim about a pairing nobody tested.
#
# WHAT COUNTS AS A CLAIM: a version string preceded, within 24 characters, by
# the name it belongs to.  Proximity is the whole mechanism -- every version in
# this tree is the same shape, and only what it sits beside says whether it is
# x-lang's, this bundle's or the engine's.
#
# `x-lang#527` IS AN ISSUE, NOT A RELEASE.  A `#` between the name and the
# version disqualifies the pair; without that this fires on r5rs/aliases.x in
# the r5rs bundle, where an issue reference and an ENGINE version share a line
# and neither is a claim about a platform.
#
# WHY awk AND NOT A REGEX WINDOW.  The first version of this used
# `name[^#]\{0,24\}vN.N.N` and was wrong the moment two versions shared a line:
# POSIX has no lazy quantifier, so the greedy window steps over the near
# version and pairs the name with the FAR one.  This bundle's README says
# "against x-lang v0.7.0 and x-r5rs v0.2.0" and would have reported x-lang as
# claiming v0.2.0.  Scanning version-first and looking BACKWARD has no such
# ambiguity.
#
# THE ESCAPE HATCH IS EXPLICIT, because history is worth writing down: a line
# carrying `release-ref: history` is skipped, and having to say so is the point.
set -e

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

MANIFEST=lang.xon
[ -f "$MANIFEST" ] || { echo "release-refs: no $MANIFEST" >&2; exit 2; }

release=$(sed -n 's/^(requires-release "\(.*\)")$/\1/p' "$MANIFEST")
[ -n "$release" ] || {
	echo "release-refs: $MANIFEST declares no (requires-release ...)" >&2
	exit 2
}

# Tracked files only, and never the manifest: the fact may repeat inside the
# file that owns it, where the prose around it is what explains it.
files=$(git ls-files | grep -v "^$MANIFEST$" || true)
[ -n "$files" ] || { echo "release-refs: no tracked files" >&2; exit 2; }

# THE NAME IS THE REPOSITORY'S, "x-r5rs" and not "r5rs".  The bare form would
# also match inside the long one and claim lines it does not own; the cost is
# that a line writing "r5rs v0.1.0" unprefixed is not checked, which is the
# right way round -- a missed check is a gap, a wrong one is a false alarm that
# gets the gate switched off.
scan() {
	name=$1
	want=$2
	# -I skips the standards PDFs, which would otherwise match as noise.
	grep -In "$name" -- $files 2>/dev/null \
		| grep -v 'release-ref: history' \
		| awk -F: -v name="$name" -v want="$want" '
		{
			file = $1; lineno = $2
			# Rebuild the text: the content may itself contain colons.
			text = $0
			sub(/^[^:]*:[^:]*:/, "", text)
			rest = text; off = 0; prev = 0
			while (match(rest, /v[0-9]+\.[0-9]+\.[0-9]+/)) {
				ver   = substr(rest, RSTART, RLENGTH)
				start = off + RSTART
				# THE WINDOW STOPS AT THE PREVIOUS VERSION.  A flat look-back
				# lets one pair span another: where a line names x-lang, then a
				# version, then x-r5rs, then a second version, the window from
				# the second reaches x-lang and reports it as claiming the wrong
				# one.  A name owns a version only when no other version stands
				# between them.  CI caught this on THIS file, whose header quotes
				# such a line as an example.
				from = prev + 1
				if (start - 24 > from) from = start - 24
				win = substr(text, from, start - from)
				at  = index(win, name)
				if (at > 0 && index(substr(win, at), "#") == 0 && ver != want)
					printf "%s:%s names %s %s, lang.xon declares %s\n",
						file, lineno, name, ver, want
				prev = start + RLENGTH - 1
				off  = off + RSTART + RLENGTH - 1
				rest = substr(rest, RSTART + RLENGTH)
			}
		}'
}

# A WORKFLOW NEVER PINS A VERSION LITERALLY, and this is the rule that covers
# what the scan above structurally cannot.  `ref:` sits on its own line, so the
# name it belongs to is on a DIFFERENT one and no per-line proximity test can
# pair them -- release.yml carried `ref: v0.2.0` under `repository: .../x-r5rs`
# and the scan was blind to it.  Rather than teach the scan about YAML, forbid
# the shape: a ref in a workflow is derived, or it is a bug.
refs=$(grep -n "^[[:space:]]*ref:[[:space:]]*v[0-9]" .github/workflows/*.yml 2>/dev/null || true)

bad=$( scan "x-lang" "$release" | sort -u )

if [ -n "$refs" ]; then
	echo "$refs" | sed 's/^/release-refs: literal ref in a workflow: /' >&2
	echo "" >&2
	echo "  A workflow reads the version from $MANIFEST -- see the prepare job." >&2
	exit 1
fi

if [ -n "$bad" ]; then
	echo "$bad" | sed 's/^/release-refs: /' >&2
	echo "" >&2
	echo "  These are one fact each.  Update $MANIFEST and the copies together," >&2
	echo "  or mark a deliberate historical mention with 'release-ref: history'." >&2
	exit 1
fi

echo "release-refs: ok -- x-lang $release, and nothing claims otherwise"
