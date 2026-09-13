; # x-r5rs -- R5RS Scheme on x-lang
;
; ## r5rs/printer.x -- Scheme-style `write`
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; x's `write` is round-trippable: a symbol renders with the quote its reader
; needs to give it back, so (list 'b 'c) writes as ('b 'c). Scheme's renders
; symbols bare and strings quoted -- (b c) and "hello" -- which this bundle's
; specs assert throughout, so `write` is rebound and the same writer backs
; %repl-print.

(provide r5rs/printer %r5rs-write %r5rs-repl-print)

; Recursive descent, because only the symbol leaf differs from x's `write`;
; everything else delegates, so the lang inherits the platform's rendering and
; stays correct as new types arrive.
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
