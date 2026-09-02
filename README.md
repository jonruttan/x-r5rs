# x-r5rs — R5RS Scheme on x-lang

The Scheme vocabulary and binding forms, riding on
[x-lang](https://github.com/jonruttan/x-lang)'s evaluator and numeric tower.

```
$ x -l r5rs
> (define (fact n) (if (= n 0) 1 (* n (fact (- n 1)))))
> (fact 10)
3628800
> (let loop ((i 0) (acc 0)) (if (= i 5) acc (loop (+ i 1) (+ acc i))))
10
> (assoc 'b '((a 1) (b 2)))
(b 2)
```

x-r5rs is a **lang**: a different surface language loaded over an x-lang
dialect. Where x-lang and Scheme spell something the same way, Scheme is free
to mean something different by it — `lambda` is one such spelling, and `do`
below is the one this lang cannot claim. The terms are in x-lang's
[lang contract](https://github.com/jonruttan/x-lang/blob/main/docs/lang-contract.md).

## Status

**667 specs, all green** against x-lang **v0.10.0**.

Third of the five 2024-era langs to come back, after [x-krn](https://github.com/jonruttan/x-krn)
and [x-sweet](https://github.com/jonruttan/x-sweet), and by far the largest — 667 tests across 27 spec
files against roughly 1,500 lines of Scheme and 680 of x.

[`tests/contract/known-failures.txt`](tests/contract/known-failures.txt) is
**empty**, and stays in the tree saying so. `make check` is red the moment any
spec fails, with no line there to excuse it — an empty contract is a stronger
claim than a missing one. What used to be listed was the ellipsis group, and
it went without a line changing under `r5rs/`; see below.

**Ports work now** (R5RS §6.6), which is the 21 that used to head this table.
`scm/ports.scm` was 249 lines of hand-rolled FFI — `dlopen`/`ptr-call` against
libc, `obj-make` for a raw buffer object, and a hand-walked map of the base
object's internal tree to reach the file table. `obj-make` had been removed
outright, so it was a rewrite rather than a port.

It drives `File` now — open/close/read/write/getc as syscalls, with a collector
that knows about the buffers — and nothing in it reaches into the base's
layout, so nothing in it breaks when that layout moves again. Redirection and
transcripts do not shadow `display` or `write`: the platform's printer already
emits through a swappable sink, so `with-output-to-file` and `transcript-on`
swap that instead of re-implementing every renderer the verbs reach.

The bundle stays on `(dialect xe)`. The old note predicted that restoring ports
would force it to radon, and that was true of the `dlopen` version — but a
dialect decides what is *preloaded*, not what is *reachable*, so an explicit
`(import x/sys/file)` is enough. Measured both ways rather than reasoned about,
with ports loaded in each: the suite scores identically under `xe` and under
`rn`, so nothing here asks for the heavier dialect.

## Install

Nothing cloned, from any directory:

```bash
x --install-lang https://github.com/jonruttan/x-r5rs/releases/latest/download/lang.pin.xon
x -l r5rs
```

x fetches the published pin, then the tarball it names, verifies the digest,
and installs to `<share>/langs/r5rs` — where `x -l` looks. A failed upgrade
leaves the working install untouched.

From a clone, if you have one:

```bash
make install                      # into the x on your PATH
PREFIX=$HOME/.local make install  # or a particular prefix
```

`make uninstall` removes it either way. An installed x searches
`<share>/langs/*/lang.xon`, so a lang is installed when its files are there —
no registry, no database.

**One trap, and it is the one you will hit.** `x` decides where to look for
langs from the directory you run it *in*. Inside an **x-lang checkout** it
searches `deps/langs/` and an installed lang is invisible, however correctly it
was installed:

```
$ cd path/to/x-lang && x -l r5rs
Error: no library, app or lang named 'r5rs'
  searched lib/r5rs.x, apps/r5rs/run.x
      and deps/langs/*/lang.xon
```

Run it from anywhere else, or name the bundles explicitly — `X_LANG_DIR` wins
in both modes:

```bash
X_LANG_DIR=$HOME/.local/share/x/langs/ x -l r5rs   # the installed one
X_LANG_DIR=/path/to/x-r5rs/.. x -l r5rs            # a checkout, uninstalled
```


## Pin it instead, for a project

An install is unversioned and machine-wide. When it matters *which* version a
project builds against, pin it: `Pin bundle` fetches the release tarball and
verifies it against a digest before unpacking. In the project's
`lang.pin.xon`:

```x
(lang "r5rs")
(release "v0.2.2")
(bundle "sha256:…" "https://github.com/jonruttan/x-r5rs/releases/download/v0.2.2/x-r5rs-v0.2.2.tar.gz")
(source "https://github.com/jonruttan/x-r5rs.git")
```

Each release publishes its own digest, and the release notes carry this block
ready to paste. Then:

```x-repl
> (import x/tool/pin)
> (Pin bundle "deps/langs")
"deps/langs/r5rs-v0.2.2"
```

`deps/langs/` is where `x -l` looks in a checkout, beside the engine and
anything else fetched rather than built. `X_LANG_DIR` overrides it.

**Which to use.** Install when you just want `x -l r5rs` to work. Pin when a
build depends on it — the digest is what makes the version reproducible, and
an install has none.

**x-r7rs consumes this bundle**, and by an exact version: its `lang.xon` carries
`(requires-lang "r5rs" …)`, compared for equality and never parsed. A checkout
does not satisfy that row — only an install or an unpacked release tarball
carries the stamped `version` file it compares against.

That stamp is `git describe`, so **installing from a checkout that is not
exactly on the tag will not satisfy a dependent**. One commit past v0.2.2 with
an edited file installs as `v0.2.2-1-gabc1234-dirty`, which is not `v0.2.2`,
and x-r7rs refuses it by name. That is the mechanism working — the row asks
*which* x-r5rs, and a modified working tree is not the one that was tested.
`--allow-lang-skew` is the way through while working on both at once.

## Running it

```bash
x -l r5rs                  # interactive
x -l r5rs -f program.scm   # batch
```

x-lang boots the dialect `lang.xon` declares, arms this bundle's module root,
and loads `run.x` on top — which is why nothing here needs to know a path.

## Development

Run the specs against any x-lang checkout or install:

```bash
X=/path/to/x-lang/x.sh make test    # the suite -- every failure is loud
X=/path/to/x-lang/x.sh make check   # the suite against the contract, which CI gates on
make check-release-refs             # the declared x-lang release is named in one place
make bundle                         # roll a release tarball and print its pin
```

**Pass `X` explicitly.** Without it the suite takes the `x` on your PATH, and an
installed x that trails the checkout reports failures the platform has already
fixed — which is exactly how the nine ellipsis specs appeared to survive the
release that removed them.

**Do not `make install` into an x-lang checkout.** The Makefile asks
`$(X) --share-dir` where to put the bundle, and a checkout answers with its own
root — so the files land in `<checkout>/langs/NAME`, which is not one of the
three paths `-l` searches there. It reports success and the lang stays
invisible. Install into a real `<share>` tree, or use `X_LANG_DIR`.


`make check-release-refs` is the gate that keeps this file honest: every x-lang
version named here is a *copy* of the one row in `lang.xon`, and a copy nobody
checks goes stale at the next release. CI runs the declared release *and*
x-lang `main`, so a platform that moves underneath this bundle shows up as a
red build rather than a surprise later.

The release tarball is byte-reproducible: it is built from the tag with
`git archive` and a timestamp-free gzip, so two people rolling one tag get one
digest. Pushing a `v*` tag runs the suite and, only if it is green, publishes
the tarball, its `.sha256` and `lang.pin.xon` as a GitHub release.

## Layout

```
lang.xon               what this bundle is: name, dialect, release pairing
run.x                  the entry
r5rs/aliases.x         Scheme's names in x's current spellings -- where the rot was
r5rs/prims.x           the raw type layer, under its 2024 names
r5rs/printer.x         Scheme's `write`, which is not x's
r5rs/base.x            assembles the parts
r5rs/scm/*.scm         the library, in Scheme
tests/spec-runner.sh   sources the platform's shared runner
tests/specs/*.spec.md  the suite, as literate markdown
tests/contract/        the recorded debt CI gates on -- empty, and saying so
tools/bundle.sh        rolls a release tarball and prints its pin
tools/check/           the release-refs gate, sourced from x-lang's lang kit
scripts/               2024 harnesses, superseded by tests/ -- kept, not wired up
Makefile               install / uninstall / test / check / bundle
```

No file here carries a path literal, `run.x` included — x.sh boots the dialect
`lang.xon` declares and arms this root *before* `run.x` is read, so nothing
needs one. CI enforces it, and it is stricter than the lang contract requires:
the contract exempts an app entry, and a bundle has no claim to that exemption.

## What porting it actually cost

Almost all of it landed in one file. `r5rs/aliases.x` is the only layer that
names x-lang directly, so it took the whole of four years of platform drift;
everything under `r5rs/scm/` is Scheme written in Scheme and needed four edits
in total.

**`(def lambda fn)` was the single worst line in the tree.** x's `fn` takes an
explicit receiver — `(fn (_ n) ...)` — so aliasing `lambda` to it binds
Scheme's *first parameter* to the receiver. `((lambda (x) x) 42)` returns the
closure. Every procedure in the bundle is written in `lambda`, so nothing
worked and nothing pointed at the cause. It has to be an operative that splices
the receiver in.

**Subject-last is a reordering, not a rename.** The class methods do not take
their subject first:

```x
(List ref n lst)      (Vector ref i v)      (Str8 ref i v)
(List drop n lst)     (Vector set! i x v)   (Str8 sub st LEN v)
```

and `(Str8 sub)` takes a *length* where Scheme's `substring` takes an *end*.
These type-check either way often enough that you find them as a wrong answer
rather than an error. ([x-lang#66](https://github.com/jonruttan/x-lang/issues/66)
tracks the convention.)

**`do` is the one spelling this lang cannot claim, and that is a hole in the
contract.** R5RS `do` is
the iteration form; x's `do` is its sequencer, and the platform library
resolves it *by name at run time* from 275 call sites. Rebind the global and
the platform breaks underneath you — `(def do 5)` makes the next `write` raise
`Unbound SYMBOL '%print-tw`, and `(def do (op ...))` kills the top-level loop
silently. So `scm/derived.scm` installs a **dispatcher**: R5RS iteration has a
shape nothing in x shares (first argument a list of binding *lists*), and
everything else is handed back to the platform's operative, captured as
`%r5rs-seq` before the shadow goes up. Filed as
[x-lang#525](https://github.com/jonruttan/x-lang/issues/525), because the
contract's central promise is that a lang may mean something of its own by a
shared spelling, and this is a spelling where it cannot — not because two
meanings may not coexist, but because the platform resolves this one by name
while the lang is running.

**Interior defines never worked** — the same defect x-krn had, for the same
reason. `define` is an operative, so its `def` runs in `define`'s own frame; in
body position that frame is not in tail position, and the binding is discarded
with it, leaving the name unbound *everywhere*. The fix is a construction-time
rewrite in `lambda`, which is how Schemes handle internal defines anyway.

**And `define` itself is no longer a TCO trick.** It used to put its `eval` in
tail position so TCO would pop the operative's frame before `def` ran, leaving
the save-stack empty and the binding global — because `def` decides
global-versus-local by save-stack depth and an operative had no other way to
define for its caller. That worked and was extremely fragile: one extra wrapper
frame and every definition landed nowhere, silently. It is why x-r7rs could not
load its own `guard`.

`(base def-global)` ([#527](https://github.com/jonruttan/x-lang/issues/527))
takes the global path unconditionally, so `define` is now frame-independent —
correct at the prompt, inside a guarded body, and under any number of wrappers.
The same fix turned `case` from three sequential `def`s inside an operative
into a `letrec`; those helpers were invisible to each other as soon as anything
added a frame.

**A zero float is not proof of a number.** `(string->number "abc")` returned
`0.0` — truthy — because the conversion runs `strtod`, which answers 0 for
`"abc"` as readily as for `"0.0"`. R5RS's contract that a failure is `#f`
quietly inverted. The 2024 code had this guard; it was lost with the file that
held it.

**Deleted rather than ported:** `lib/x/syntax.x`, 110 lines of
quote/quasiquote/comma reader types built with `compile-batch`. The platform
ships `lib/x/reader/lit-reader.x` and `quasi-reader.x` now, and `'` and `` ` ``
work out of the box. Porting it would have been re-implementing the platform.

## What was fixed

**Ellipsis (9) — gone, and the bundle did not move.** `syntax-rules` patterns
could not be written at all: every token *beginning* with `.` reached x-lang as
the pair-dot sentinel, so `(a ... b)` read as `('a . #<ATOM:…>)` — an improper
list holding a leaked C satom, which segfaulted on `(first (rest …))`.

The contract recorded it as "not a patch waiting to be applied", on the reading
that **x is not Scheme**: Scheme's lexical rules — that `a.b` is a symbol, that
`...` is a symbol — are a lang's to impose above the engine, not the engine's
to adopt. That reading held. What it missed is that the engine was not failing
to support Scheme; it was asserting a rule of *its own* that it never meant to
make. The dot sat in `X_SEXP_LIST_CHARS_STR` beside the brackets, so the
analyser scored it on sight — true of `(` and `)`, which really are always
single-character tokens, and false of `.`, which separates a pair only when
nothing follows it.

x-engine-c v0.1.4, shipped in x-lang v0.8.1, stopped claiming the character. <!-- release-ref: history: when the fix landed, not the pairing -->
Nothing about `...` was added anywhere: it is a symbol the reader does not
recognise and passes through. 667/9 became 667/0 without a line changing under
`r5rs/`, which is the outcome the lang-owned-tokenizer route
([x-lang#158](https://github.com/jonruttan/x-lang/issues/158)) would have cost
a rewrite to reach.

**Exactness — fixed, and it split two ways.** Four were the implementation's
fault: R5RS 6.2.5 permits an exact result where the argument is exact and the
value is exactly representable, `sqrt` in `scm/numeric.scm` already took that
permission — `(sqrt 4)` is `2`, not `2.0` — and `sin`, `cos`, `exp` and
`magnitude` did not. They do now, and only where the mathematics is exact
rather than where a float happens to look round.

Three were the **suite's** fault, and were corrected against the standard
rather than against our output — the distinction the paragraph below turns on:

| | was | is | why |
|---|---|---|---|
| `(number->string (exact->inexact 3))` | `3` | `3.0` | 6.2.6 — it must read back with the same exactness |
| `(log (exp 1))` | `1` | an inverse check | it was asserting a float's printed form, not a fact about logarithms |
| `(+ 1/2 1.5)` | `2` | `2.0` | 6.2.2 — exactness is contagious |

The third is not an exactness correction at all. `(log (exp 1))` was asserting
the printed form of a float, which is a question about the printer rather than
about logarithms, and which a change in rounding could break while both
functions stayed perfectly correct. It asks what it was always for now — that
`log` and `exp` undo each other, to within the error floating point is entitled
to. Checked non-vacuous by running it at zero tolerance, where it fails.

**No expectation was edited to agree with behaviour.** Each of those three
contradicted R5RS on the day it was written, and each carries its citation in
the spec file. A suite rewritten to match the implementation stops being
evidence, which is the whole reason this generation of langs was worth
resurrecting rather than replacing — but a suite that contradicts the standard
it tests was never evidence in the first place.


## The hygiene leak, and where it had to be fixed

`scm/macro.scm` let a macro-introduced definition escape into the global
environment — R5RS pitfall 3.2, which this suite tests by name. It had always
leaked; it only became *visible* once `define` stopped depending on frame depth,
because before that the global binding was made and then discarded when the
expansion's frame unwound. The suite passed by accident.

**It cannot be fixed after instantiation, and that is the interesting part.**
`%sr-instantiate` resolves an introduced identifier to its *value* — that is the
hygiene mechanism doing its job — so an expanded definition arrives as
`(#<op> y 1)`, not `(define y 1)`. There is no way to recognise it there:
`eq?` does not discriminate operatives, and `(eq? cond define)` answers `#t`.

Two attempts failed on exactly that. Evaluating the expansion in the use-site
environment does not help, because `eval`-with-env deliberately does not restore
the BST and `define` binds through it. Rewriting the expansion does not help,
because by then the head is an operative.

The fix is in `syntax-rules`, on the **template**, before instantiation — where
the head is still the symbol `define` and the same `%r5rs-def-form` rewrite
`lambda` uses for body-position definitions applies cleanly. A definition
produced into an expression context becomes a plain `def`, which binds in the
frame the expansion runs in and leaves with it.

Both paths are covered by specs now, and the two engines agree at 37.

## Background

Scheme began with Gerald Jay Sussman and Guy L. Steele Jr. at MIT in 1975 — a
Lisp with lexical scope, first-class continuations, and proper tail calls as a
requirement rather than an optimization. R5RS (1998, edited by Kelsey, Clinger
and Rees) is the revision this bundle implements, and the one most often meant
by "standard Scheme": famously about fifty pages, on the stated principle that
a language grows by removing the weaknesses that make features seem necessary,
not by piling features up. That brevity is why 667 specs can plausibly claim to
cover a useful core of it.

- [R5RS](https://schemers.org/Documents/Standards/R5RS/) — the report itself
- [scheme.org](https://www.scheme.org/) — the community hub: implementations, standards, SRFIs
- [SICP](https://sarabander.github.io/sicp/) — *Structure and Interpretation of Computer Programs*, the book that taught the world this language

## Licence

MIT No Attribution (MIT-0). See [LICENSE](LICENSE).
