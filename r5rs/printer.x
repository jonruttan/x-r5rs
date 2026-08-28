; # x-r5rs -- r5rs-expressions for x-lang
;
; ## r5rs/printer.x -- Scheme's `write`, which is not x's
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; x's `write` is round-trippable: a symbol renders with the quote its reader
; needs to give it back, so (list 'b 'c) writes as ('b 'c).  That is right for
; x, and blessed in docs/spec.md -- "(my-quote (+ 1 2)) -> ('+ 1 2)".
;
; Scheme's `write` renders symbols bare and strings quoted: (b c) and "hello".
; This bundle's specs assert it in dozens of places -- every list-of-symbols
; result -- so the difference is not cosmetic here, it is the assertion.
;
; Re-meaning a shared spelling is what a personality is FOR; the contract says
; so in as many words.  So `write` is rebound rather than the spec rewritten,
; and the same writer backs %repl-print.  (x-krn and x-sweet reach the same conclusion from the same evidence -- three independent ports needing the
; same twenty lines is an argument for the platform documenting the seam,
; which is x-lang#518.)

(provide r5rs/printer %r5rs-write %r5rs-repl-print)

; Recursive descent, because only the SYMBOL leaf differs from x's `write`.
; Everything else -- strings, ints, chars, booleans, procedures -- delegates,
; so the personality inherits the platform's rendering and stays correct as new
; types arrive.
(def %r5rs-write ())
(def %x-write write)

(def %r5rs-write-items
  (fn (_ v)
    (%r5rs-write (first v))
    (if (null? (rest v))
      ()
      ; Proper tail: keep going.  Improper: the dotted spelling.  A printer
      ; that cannot render (a . b) cannot show a pair, and pairs are the
      ; substrate.
      (if (pair? (rest v))
        (%seq (display " ") (%r5rs-write-items (rest v)))
        (%seq (display " . ") (%r5rs-write (rest v)))))))

(set! %r5rs-write
  (fn (_ v)
    (if (pair? v)
      (%seq (display "(") (%seq (%r5rs-write-items v) (display ")")))
      (if (symbol? v) (display v) (%x-write v)))))

; The %repl-print shape: nil is the "no value" result and prints only the
; newline, matching lib/x/repl/loop.x.
(def %r5rs-repl-print
  (fn (_ result)
    (unless (null? result) (%r5rs-write result))
    (newline)))
