# x-r5rs — R5RS Scheme on x-lang

The Scheme vocabulary and binding forms, riding on x-lang's evaluator and
numeric tower.

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

## Status

**658 of 667 specs green** against x-lang **v0.8.1**.

Third of the five 2024-era langs to come back, after [x-krn](../x-krn)
and [x-sweet](../x-sweet), and by far the largest — 667 tests across 26 spec
files against roughly 1,700 lines of Scheme.

The 9 that do not pass are all one thing: the reader takes every token
beginning with `.` as the pair-dot, so `...` is unreadable and `syntax-rules`
patterns cannot be written. That is a design question in the engine's
tokenizer rather than a patch — see below.

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
`(import x/sys/file)` is enough. Measured both ways with ports loaded: 667/16
under `xe`, 667/16 under `rn`.

## Running it

```bash
make test        # the spec suite
make install     # into the x on PATH
```

then `x -l r5rs`. `make install` puts the bundle where `-l` looks — an installed
x searches `<share>/langs/*/lang.xon`, so a lang is installed when its files
are there. No registry, no per-project pin. Use `lang.pin.xon` and `Pin bundle`
instead when it matters which version.

## Layout

```
lang.xon     name, dialect, release pairing
run.x               THE entry -- the only file that may know a path
r5rs/aliases.x      Scheme's names in x's current spellings -- where the rot was
r5rs/prims.x        the raw type layer, under its 2024 names
r5rs/printer.x      Scheme's `write`, which is not x's
r5rs/base.x         assembles the parts
r5rs/scm/*.scm      the library, in Scheme
scripts/            2024 harnesses, superseded by tests/ -- kept, not wired up
```

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

**`do` cannot be re-meant, and that is a hole in the contract.** R5RS `do` is
the iteration form; x's `do` is its sequencer, and the platform library
resolves it *by name at run time* from 275 call sites. Rebind the global and
the platform breaks underneath you — `(def do 5)` makes the next `write` raise
`Unbound SYMBOL '%print-tw`, and `(def do (op ...))` kills the top-level loop
silently. So `scm/derived.scm` installs a **dispatcher**: R5RS iteration has a
shape nothing in x shares (first argument a list of binding *lists*), and
everything else is handed back to the platform's operative, captured as
`%r5rs-seq` before the shadow goes up. Filed as
[x-lang#525](https://github.com/jonruttan/x-lang/issues/525), because the
contract's central promise is that a lang may re-mean a shared spelling,
and this is a spelling where it cannot.

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

## What remains, and what was fixed

**Ellipsis (9).** Every token beginning with `.` reaches x-lang as the dot
sentinel, so `(a ... b)` reads as `('a . #<ATOM:…>)` — an improper list holding
a leaked C satom, which segfaults on `(first (rest …))`. `syntax-rules` cannot
be written until a lone `.` is distinguishable from a token that merely starts
with one.

It is not obviously the engine's job to fix. **x is not Scheme**, and Scheme's
lexical rules — that `a.b` is a symbol, that `...` is a symbol — are the
lang's to impose, above the engine, not the engine's to adopt. What is
arguably the engine's own defect is narrower: its internal pair-dot marker
escapes into data as a value and crashes on access, which is wrong in x's terms
whatever a dot is supposed to mean.

The route that does not ask the engine to become Scheme is a lang-owned
tokenizer base — `(Base make-tok)`, which is what x-ash uses for shell syntax
and what that primitive is documented for. It is a real lift for a lang that
otherwise wants x's s-expression reader, and it has not been attempted here.
Background on [x-lang#158](https://github.com/jonruttan/x-lang/issues/158).

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

## Licence

MIT No Attribution (MIT-0). See [LICENSE](LICENSE).
