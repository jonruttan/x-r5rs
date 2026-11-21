; --- Deep structural equality (R5RS §6.1) ---

(define
  (equal? a b)
  (cond
    ((and (pair? a) (pair? b))
      (and (equal? (car a) (car b)) (equal? (cdr a) (cdr b))))
    ((and (vector? a) (vector? b))
      (equal? (vector->list a) (vector->list b)))
    ((and (char? a) (char? b))
      (= (char->integer a) (char->integer b)))
    ((or (char? a) (char? b)) #f)
    ((and (number? a) (number? b)) (= a b))
    ((and (string? a) (string? b)) (string=? a b))
    (#t (eq? a b))))

; --- Equivalence (identity for pairs/procs, = for numbers/chars) ---

; A char is an int underneath, so (eq? 65 #\A) is #t in x -- characters and
; small integers share identity. Scheme says (eqv? 65 #\A) is #f, so the char
; cases come first and char-versus-non-char is answered before the fallback,
; which would otherwise reach (eq? 65 #\A) and agree with x rather than Scheme.
(define
  (eqv? a b)
  (cond
    ((and (char? a) (char? b))
      (= (char->integer a) (char->integer b)))
    ((or (char? a) (char? b)) #f)
    ((and (number? a) (number? b)) (= a b))
    (#t (eq? a b))))

; --- boolean? ---

(define (boolean? x) (or (eq? x #t) (eq? x #f)))
