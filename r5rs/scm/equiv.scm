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

; A CHAR IS AN INT UNDERNEATH, so (eq? 65 #\A) is #t in x -- characters and
; small integers share identity.  Scheme says (eqv? 65 #\A) is #f, so the
; char cases have to come FIRST and a char-versus-non-char has to be answered
; before the fallback ever sees it.  Without the second clause the fallback
; reaches (eq? 65 #\A) and agrees with x rather than with Scheme.
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
