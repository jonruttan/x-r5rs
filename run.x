; # x-r5rs -- R5RS Scheme on x-lang
;
; ## run.x -- THE entry
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
; THIS FILE KNOWS NO PATHS, and that is the whole point of the arrangement.
; x.sh boots the dialect lang.xon declares, arms this bundle's root with
; import-path!, cats this file, and appends the launcher when no -f was given.
; So by the time anything below runs, the platform is up and `import` resolves
; against the bundle wherever it happens to sit.
;
; It used to do all of that itself: include "lib/x-core.x" to self-boot, probe
; a list of candidate directories to guess its own location, and end with its
; own %batch?-guarded launcher.  Every line of that was a workaround for `-l`
; not knowing about bundles.  It does now.
(import r5rs/base)

(set! %lang-name "R5RS Scheme")
(set! %lang-version r5rs-version)
(set! %repl-prompt "> ")
; Scheme prints Scheme results: (b c), not x's round-trippable ('b 'c).
; See r5rs/printer.x for why that is a re-meaning rather than a workaround.
(set! %repl-print %r5rs-repl-print)
