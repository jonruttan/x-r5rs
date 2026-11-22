; # x-r5rs -- R5RS Scheme on x-lang
;
; ## r5rs/run -- the entry
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
; The wrapper boots the dialect bundle.xon declares, arms this bundle's lib/
; as an import root, imports this module, and calls its `main`. Importing it
; sets Scheme up and starts nothing; what follows on the stream -- a program,
; or the launcher's session -- is read with Scheme's names in place.
(module r5rs/run)
(import r5rs/base r5rs-version r5rs-repl-print)

(import r5rs/line scheme-lang-register!)

; R5RS as a lang of the session (x/repl/lang): the prompt, Scheme's printer
; and the line coloured as Scheme. Scheme prints Scheme results: (b c), not
; x's round-trippable ('b 'c); see r5rs/printer.x for why that is a
; re-meaning rather than a workaround.
(scheme-lang-register! "r5rs" r5rs-repl-print)

; `-l` is repeatable, and named second (`x -l xe -l r5rs`) this bundle is a
; library to the lang that owns the prompt: it is registered, so (lang r5rs)
; switches to it, and touches neither the banner nor the prompt.
(if (guard (_ #t) (str=? %lang-lead "r5rs"))
  (%seq (set! %lang-name "R5RS Scheme")
    (%seq (set! %lang-version r5rs-version)
      (Lang use! "r5rs")))
  ())

; Nothing to start: a program is read by the platform's loop, in Scheme's
; vocabulary, and a session by the launcher's.
(def main (fn (_) ()))

(provide r5rs/run main)
