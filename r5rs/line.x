; # x-r5rs -- R5RS Scheme on x-lang
;
; ## r5rs/line.x -- Scheme as a lang of the session, its line coloured as Scheme
;
; @description The painter the line editor colours a Scheme line with, and
;   the registration that makes a Scheme a lang a session switches to.
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; A Scheme form is an s-expression and the platform's reader reads it, so the
; platform's line editor is this bundle's too. What it does not know is which
; atoms are Scheme's keywords: left alone it colours the line as x-lang. The
; bundle already ships that answer as a grammar, `scheme` (r5rs/syntax), and
; (Paint grammar g) draws a line by a grammar's spans.
;
; THE PAINTER IS MADE ON THE FIRST LINE PAINTED. Making it loads the grammar,
; the highlighting library and the painter, which a batch run never needs and
; a session needs only once a key is pressed.
;
; ON A PLATFORM WITHOUT (Paint grammar) THE LINE IS COLOURED AS IT WAS, by
; x-lang's painter: the make is guarded, and what it falls back to is the
; painter the lang "x" registered, or the line unchanged when there is none.

(module r5rs/line)

; x-lang's import, kept under a name of this module's: R7RS gives `import`
; a meaning of its own, and the painter is made after it has.
(def %scm-import import)

(def %scm-paint-plain (fn (_ window . _) window))

(def %scm-paint-x
  (fn (_)
    (guard (_ %scm-paint-plain)
      (let ((p (Assoc get (lit %repl-paint) (Lang get "x"))))
        (if (null? p) %scm-paint-plain p)))))

(def %scm-painter ())
(def %scm-painter-make
  (fn (_)
    (guard (_ (%scm-paint-x))
      (%seq (%scm-import r5rs/syntax)
        (%seq (%scm-import x/repl/paint)
          (%seq (%scm-import x/tool/syntax)
            (Paint grammar (Syntax named (lit scheme)))))))))

; The %repl-paint seam: (window marks before) -> the text to display.
(def scheme-paint
  (fn (_ window . more)
    (if (null? %scm-painter) (set! %scm-painter (%scm-painter-make)) ())
    (apply %scm-painter (pair window more))))

; Register a Scheme under NAME (x/repl/lang): its prompt, its printer and
; the Scheme painter. A seam not named here is x-lang's, which is right for
; the reader, the bracket marks and the line evaluator: the forms are
; s-expressions.
(def scheme-lang-register!
  (fn (_ name print)
    (Lang register! name
      (list (pair (lit %repl-prompt) "> ")
            (pair (lit %repl-print) print)
            (pair (lit %repl-paint) scheme-paint)))))

(provide r5rs/line scheme-paint scheme-lang-register!)
