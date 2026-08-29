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

**625 of 663 specs green** against x-lang **v0.6.0** and an x-engine-c carrying
the [#527](https://github.com/jonruttan/x-lang/issues/527) fix.

Third of the five 2024-era langs to come back, after [x-krn](../x-krn)
and [x-sweet](../x-sweet), and by far the largest — 687 tests across 26 spec
files against roughly 1,700 lines of Scheme.

The 38 that do not pass are three groups, and none of them is a loose end
someone forgot:

| | count | why |
|---|---|---|
| **Ports** | 21 | `scm/ports.scm` is not loaded — a rewrite, not a port. See below. |
| **`syntax-rules` ellipsis** | 9 | Blocked on the platform reader: `...` is unreadable ([x-lang#158](https://github.com/jonruttan/x-lang/issues/158)). |
| **Exactness** | 7 | `(magnitude 3+4i)` is `5.0` where the 2024 suite expects `5`. |
| **`let-syntax` in a define body** | 1 | Downstream of the ellipsis blocker. |

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

## The three groups that remain

**Ports (21).** `scm/ports.scm` is 249 lines of hand-rolled FFI — `dlopen`,
`ptr-call`, and `obj-make` to build a raw buffer. `obj-make` no longer exists
at all, and the platform grew `File` and `x/type/io`, which do the job with a
collector that knows about the buffers. That is a rewrite against a better
substrate, scoped as its own work. Restoring it also moves
`lang.xon`'s `(dialect xe)` to `rn`, since `dlopen` is a radon opt-in —
exactly the kind of change that row exists to make visible.

**Ellipsis (9).** Every token beginning with `.` reaches x-lang as the dot
sentinel, so `(a ... b)` reads as `('a . #<ATOM:…>)` — an improper list holding
a leaked C satom, which segfaults on `(first (rest …))`. `syntax-rules` cannot
be written until the reader distinguishes a lone `.` from a symbol that starts
with one. Nothing in a lang can work around it. Details added to
[x-lang#158](https://github.com/jonruttan/x-lang/issues/158).

**Exactness (7).** `(magnitude (make-rectangular 3 4))` is `5.0`, `(sin 0)` is
`0.0`, `(number->string 3.0)` is `"3.0"`. The last of those is what R5RS
actually requires and the 2024 expectation was wrong; the first two are the
tower returning inexact where R5RS permits exact. **The expectations have not
been edited to match.** A suite rewritten to agree with current behaviour stops
being evidence, which is the whole reason this generation of personalities was
worth resurrecting rather than replacing.


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
