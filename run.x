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
(import r5rs/base r5rs-version r5rs-repl-print)

(import r5rs/line scheme-lang-register!)

; R5RS as a lang of the session (x/repl/lang): the prompt, Scheme's printer
; and the line coloured as Scheme. Scheme prints Scheme results: (b c), not
; x's round-trippable ('b 'c); see r5rs/printer.x for why that is a
; re-meaning rather than a workaround.
(scheme-lang-register! "r5rs" r5rs-repl-print)

; `-l` is repeatable, and named second (`x -l xe -l r5rs`) this bundle is a
; library to the lang that owns the prompt: it is registered, so (lang r5rs)
; switches to it, and touches neither the banner nor the prompt. A wrapper
; older than %lang-lead binds nothing, and then this bundle leads.
(if (guard (_ #t) (str=? %lang-lead "r5rs"))
  (%seq (set! %lang-name "R5RS Scheme")
    (%seq (set! %lang-version r5rs-version)
      (Lang use! "r5rs")))
  ())
