; # x-r5rs -- R5RS Scheme on x-lang
;
; ## r5rs/base.x -- the language, assembled
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; No path literals and no dialect boot here: run.x owns both.  Siblings are
; reached by ./-relative include-once, which resolves against THIS file rather
; than the cwd -- so the bundle relocates.  The 2024 tree spelled every one of
; these as (include "lang/r5rs/lib/scm/...") and was nailed to a directory the
; platform abandoned.
;
; WHAT IS NOT HERE ANY MORE.  The 2024 base opened by loading four platform
; modules -- posix, hash, compile, then float/rational/complex.  All four are
; gone from this file:
;
;   - x-core, posix, hash and compile are the ENTRY's business, and
;     re-including a platform module on a booted tower is a segfault
;     (x-lang#515), not an error.
;   - float, rational and complex are in the tower the entry boots.  Loading
;     them again produced `^: operands must be integers`, which names neither
;     the file nor the re-inclusion.
;   - lib/x/syntax.x, 110 lines of quote/quasiquote/comma reader types built
;     with compile-batch, is DELETED rather than ported: the platform ships
;     lib/x/reader/lit-reader.x and quasi-reader.x now, and ' and ` work out of
;     the box.  Porting it would have been re-implementing the platform.

(import r5rs/prims)
(import r5rs/aliases)
(import r5rs/printer)

(provide r5rs/base r5rs-version %r5rs-repl-print)

(def r5rs-version "0.1.0")

; Scheme's `write`, installed.  See r5rs/printer.x for why a personality
; rebinds it rather than rewriting its specs.
(def write %r5rs-write)

; --- The platform's sequencer, captured before Scheme's `do` shadows it -----
; scm/derived.scm installs an R5RS `do` that dispatches on shape and hands
; everything that is not iteration back to this.  It has to be captured HERE,
; before that file loads, and it must never be re-captured afterwards.
(def %r5rs-seq do)

; --- Forms the platform used to supply and no longer does -------------------
; derived.scm's header says let*, letrec, cond, case, when, unless, named let,
; delay and force "are now in lib/x/derived.x and lib/x/promise.x".  Most still
; are: let, letrec, named let, cond, case, when and unless all answer.  let* is
; supplied by derived.scm itself.  delay/force are not supplied anywhere, so
; Scheme brings its own.

; delay/force: a one-slot cell holding either the thunk or its value, with a
; second slot as the forced flag.  R5RS requires the expression run at most
; once, which is the whole content of the promise.
(def %r5rs-promise-tag (list (lit %r5rs-promise)))
(def delay
  (op (expr)
    e
    (list %r5rs-promise-tag (list 0) (eval (list (lit lambda) () expr) e))))
(def force
  (fn (_ p)
    (if (if (pair? p) (eq? (first p) %r5rs-promise-tag) #f)
      (do
        (if (= (first (first (rest p))) 0)
          (do
            (%set-first! (rest (rest p)) ((first (rest (rest p)))))
            (%set-first! (first (rest p)) 1))
          ())
        (first (rest (rest p))))
      p)))

; --- The library, in dependency order ---------------------------------------
; equiv before list (memv needs eqv?), list before the rest, macro last: it
; rewrites at read time and wants everything else already bound.
(include-once "./scm/derived.scm")
(include-once "./scm/equiv.scm")
(include-once "./scm/list.scm")
(include-once "./scm/char.scm")
(include-once "./scm/string.scm")
(include-once "./scm/numeric.scm")
(include-once "./scm/control.scm")
; Ports, rewritten against File and the platform's print sink rather than the
; 2024 dlopen/ptr-call/obj-make FFI -- see the note at the top of that file.
;
; x/sys/file is an opt-in module in EVERY dialect -- x/rn.x leaves it commented
; out too -- so it is imported here rather than assumed.  That import is also
; why the bundle stays on (dialect xe): a dialect decides what is preloaded,
; not what is reachable, so ports did not have to drag this bundle to radon the
; way the 2024 dlopen version would have.
(import x/sys/file)
(include-once "./scm/ports.scm")
(include-once "./scm/macro.scm")
