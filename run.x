; # x-r5rs -- R5RS Scheme on x-lang
;
; ## run.x -- the entry point
;
; @description R5RS Scheme: the Scheme vocabulary and binding forms, on
;   x-lang's evaluator and numeric tower.
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; Usage:
;   x -l r5rs               interactive
;   x -l r5rs -f prog.scm   batch
;
; This file contains no path literals and no boot code. x.sh boots the dialect
; lang.xon declares, arms this bundle's root with import-path!, cats this file,
; and appends the launcher when no -f was given, so `import` below resolves
; against the bundle wherever it sits.
(import r5rs/base)

(set! %lang-name "R5RS Scheme")
(set! %lang-version r5rs-version)
(set! %repl-prompt "> ")
; Scheme prints Scheme results: (b c), not x's round-trippable ('b 'c).
; See r5rs/printer.x for why that is a re-meaning rather than a workaround.
(set! %repl-print %r5rs-repl-print)
