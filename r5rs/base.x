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

(module r5rs/base)
(import r5rs/prims)
(import r5rs/aliases)
(import r5rs/printer r5rs-write r5rs-repl-print)

(def r5rs-version "0.1.0")

; Scheme's `write`, installed. See r5rs/printer.x for why a lang rebinds it.
(def write r5rs-write)

; --- Forms the platform no longer supplies ---------------------------------
; let, letrec, named let, cond, case, when and unless are supplied by the
; platform; let* comes from derived.scm; delay/force are supplied nowhere, so
; Scheme brings its own.

; delay is the platform's (x/type/promise owns the name, and provides it to
; the root); force is its force, which passes a non-promise through.
(def force (fn (_ p) (Promise force p)))

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
(include-once "./scm/ports.scm")
(include-once "./scm/macro.scm")

(provide r5rs/base r5rs-version r5rs-repl-print (global write) (global force))
