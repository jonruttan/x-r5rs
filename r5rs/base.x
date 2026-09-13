; # x-r5rs -- R5RS Scheme on x-lang
;
; ## r5rs/base.x -- the language, assembled
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; No path literals and no dialect boot here: run.x owns both. Siblings are
; reached by ./-relative include-once, which resolves against this file, so the
; bundle relocates.
;
; The entry boots x-core, posix, hash and compile, and the numeric tower, so
; this file loads none of them -- re-including a platform module on a booted
; tower is a crash, not an error (x-lang#515). Quote/quasiquote reader types
; come from the platform (lib/x/reader/lit-reader.x, quasi-reader.x), so ' and
; ` work without anything here.

(import r5rs/prims)
(import r5rs/aliases)
(import r5rs/printer)

(provide r5rs/base r5rs-version %r5rs-repl-print)

(def r5rs-version "0.1.0")

; Scheme's `write`, installed. See r5rs/printer.x for why a lang rebinds it.
(def write %r5rs-write)

; --- The platform's sequencer, captured before Scheme's `do` shadows it -----
; scm/derived.scm installs an R5RS `do` that dispatches on shape and hands
; everything that is not iteration back to this.  It has to be captured HERE,
; before that file loads, and it must never be re-captured afterwards.
(def %r5rs-seq do)

; --- Forms the platform no longer supplies ---------------------------------
; let, letrec, named let, cond, case, when and unless are supplied by the
; platform; let* comes from derived.scm; delay/force are supplied nowhere, so
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
; Ports, built on File and the platform's print sink. x/sys/file is opt-in in
; every dialect, so it is imported here rather than assumed -- and because a
; dialect decides what is preloaded, not what is reachable, ports do not drag
; this bundle to radon; it stays on xe.
(import x/sys/file)
(include-once "./scm/ports.scm")
(include-once "./scm/macro.scm")
