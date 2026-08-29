; --- Numeric operations (R5RS §6.2) ---

; --- Math ---

(define (quotient a b) (%int/ a b))
(define (remainder a b) (- a (* b (quotient a b))))
(define
  (modulo a b)
  (let ((r (remainder a b)))
    (if (zero? r)
      r
      (if (if (> b 0) (< r 0) (> r 0)) (+ r b) r))))

; --- Number type predicates ---
; Tower: integer? ⊂ rational? ⊂ real? ⊂ complex? = number?

(define
  (integer? x)
  (cond
    ((%int-number? x) #t)
    ((float? x) (= x (ftrunc x)))
    (#t #f)))
(define (exact? x) (if (%rat? x) #t (%int-number? x)))
(define (inexact? x) (float? x))
(define (exact-integer? x) (%int-number? x))
; rational?, real?, complex?, number? already set by rational.x / complex.x

; --- Rational accessors ---

(define
  (numerator x)
  (cond
    ((%rat? x) (first (first x)))
    ((%int-number? x) x)
    (#t (error "non-rational"))))
(define
  (denominator x)
  (cond
    ((%rat? x) (rest (first x)))
    ((%int-number? x) 1)
    (#t (error "non-rational"))))

; --- Variadic comparisons ---

; Save binary float-aware versions before redefining as variadic

(define %bin= =)
(define %bin< <)
(define
  (= . args)
  (if (null? (cdr args))
    #t
    (let loop
      ((a (car args)) (rest (cdr args)))
      (if (null? rest)
        #t
        (if (%bin= a (car rest)) (loop (car rest) (cdr rest)) #f)))))
(define
  (< . args)
  (if (null? (cdr args))
    #t
    (let loop
      ((a (car args)) (rest (cdr args)))
      (if (null? rest)
        #t
        (if (%bin< a (car rest)) (loop (car rest) (cdr rest)) #f)))))
(define
  (> . args)
  (if (null? (cdr args))
    #t
    (let loop
      ((a (car args)) (rest (cdr args)))
      (if (null? rest)
        #t
        (if (%bin< (car rest) a) (loop (car rest) (cdr rest)) #f)))))
(define
  (<= . args)
  (if (null? (cdr args))
    #t
    (let loop
      ((a (car args)) (rest (cdr args)))
      (if (null? rest)
        #t
        (if (not (%bin< (car rest) a))
          (loop (car rest) (cdr rest))
          #f)))))
(define
  (>= . args)
  (if (null? (cdr args))
    #t
    (let loop
      ((a (car args)) (rest (cdr args)))
      (if (null? rest)
        #t
        (if (not (%bin< a (car rest)))
          (loop (car rest) (cdr rest))
          #f)))))

; --- Variadic min/max ---

(define
  (min . args)
  (let loop
    ((best (car args)) (rest (cdr args)))
    (if (null? rest)
      best
      (loop (if (< (car rest) best) (car rest) best) (cdr rest)))))
(define
  (max . args)
  (let loop
    ((best (car args)) (rest (cdr args)))
    (if (null? rest)
      best
      (loop (if (> (car rest) best) (car rest) best) (cdr rest)))))

; --- Variadic gcd/lcm ---

(define
  (%gcd2 a b)
  (if (zero? b) a (%gcd2 b (remainder a b))))
(define
  (gcd . args)
  (if (null? args)
    0
    (let loop
      ((acc (abs (car args))) (rest (cdr args)))
      (if (null? rest)
        acc
        (loop (%gcd2 acc (abs (car rest))) (cdr rest))))))
(define
  (%lcm2 a b)
  (if (zero? b) 0 (abs (* (quotient a (%gcd2 a b)) b))))
(define
  (lcm . args)
  (if (null? args)
    1
    (let loop
      ((acc (abs (car args))) (rest (cdr args)))
      (if (null? rest)
        acc
        (loop (%lcm2 acc (abs (car rest))) (cdr rest))))))

; --- R5RS math with float support ---

(define
  (floor x)
  (if (float? x) (inexact->exact (ffloor x)) x))
(define
  (ceiling x)
  (if (float? x) (inexact->exact (fceil x)) x))
(define
  (truncate x)
  (if (float? x) (inexact->exact (ftrunc x)) x))
(define
  (round x)
  (if (float? x) (inexact->exact (frint x)) x))
(define
  (sqrt x)
  (if (and (%int-number? x) (>= x 0))
    (let ((s (inexact->exact (fsqrt (exact->inexact x)))))
      (if (= (* s s) x) s (fsqrt (exact->inexact x))))
    (fsqrt (if (float? x) x (exact->inexact x)))))
; --- The exact special cases of the transcendental functions ---------------
;
; R5RS 6.2.5 says these "in general" return inexact results, and permits an
; exact one where the argument is exact and the value is exactly representable.
; `sqrt` above already takes that permission -- (sqrt 4) is 2, not 2.0 -- and
; these are the same rule applied to the handful of arguments whose value is
; exact by definition rather than by luck of the arithmetic.
;
; It matters for more than tidiness: the float path answers 0.0 where R5RS
; programs branch on (= (sin 0) 0) and on exact?, and it makes an exact
; computation go inexact at the first trig call and stay there.
;
; ONLY WHERE THE MATHEMATICS IS EXACT, never where the float merely looks
; round.  sin 0 is exactly 0 and cos 0 exactly 1; sin of any other exact
; argument is irrational.  (log (exp 1)) is NOT in this set -- (exp 1) is
; inexact, and an inexact argument must give an inexact result whatever the
; digits come out as.
(define (%exact-int? x) (and (%int-number? x) (exact? x)))

(define
  sin
  (lambda (x)
    (if (and (%exact-int? x) (= x 0))
      0
      (fsin (if (float? x) x (exact->inexact x))))))
(define
  cos
  (lambda (x)
    (if (and (%exact-int? x) (= x 0))
      1
      (fcos (if (float? x) x (exact->inexact x))))))
(define
  tan
  (lambda (x)
    (if (and (%exact-int? x) (= x 0))
      0
      (ftan (if (float? x) x (exact->inexact x))))))
(define
  asin
  (lambda (x)
    (if (and (%exact-int? x) (= x 0))
      0
      (fasin (if (float? x) x (exact->inexact x))))))
(define
  acos
  (lambda (x)
    (if (and (%exact-int? x) (= x 1))
      0
      (facos (if (float? x) x (exact->inexact x))))))
(define
  atan
  (lambda
    (x . rest)
    (if (null? rest)
      (if (and (%exact-int? x) (= x 0))
        0
        (fatan (if (float? x) x (exact->inexact x))))
      (fatan2
        (if (float? x) x (exact->inexact x))
        (if (float? (car rest))
          (car rest)
          (exact->inexact (car rest)))))))
(define
  (exp x)
  (if (and (%exact-int? x) (= x 0))
    1
    (fexp (if (float? x) x (exact->inexact x)))))
(define
  (log x)
  (if (and (%exact-int? x) (= x 1))
    0
    (flog (if (float? x) x (exact->inexact x)))))

; --- magnitude, exact where the triangle is --------------------------------
;
; The same permission sqrt takes, for the same reason: (magnitude 3+4i) is
; exactly 5 when the parts are exact, and answering 5.0 turns an exact
; computation inexact at the first call.  A 3-4-5 triangle is not a rounding
; accident -- the test is whether the squared magnitude is a perfect square,
; computed exactly, exactly as sqrt does it.
;
; Falls back to the class for everything else, so inexact parts, non-integer
; parts and non-representable magnitudes all keep the float answer.
(define %complex-magnitude magnitude)
(define (magnitude z)
  (let ((r (real-part z)) (i (imag-part z)))
    (if (and (%exact-int? r) (%exact-int? i))
      (let ((sq (+ (* r r) (* i i))))
        (let ((s (inexact->exact (fsqrt (exact->inexact sq)))))
          (if (= (* s s) sq) s (%complex-magnitude z))))
      (%complex-magnitude z))))

; --- Generic number->string / string->number ---

(define %int-number->string number->string)
(define %int-string->number string->number)
(define
  (number->string n . radix)
  (if (float? n)
    (float->string (first n))
    (if (null? radix)
      (%int-number->string n)
      (%int-number->string n (car radix)))))
(define
  (string->number s . radix)
  (if (null? radix)
    (let ((has-dot
            (let loop
              ((i 0))
              (cond
                ((= i (string-length s)) #f)
                ((char=? (string-ref s i) #\.) #t)
                (#t (loop (+ i 1)))))))
      (if has-dot
        (make-instance %float (string->float s))
        (%int-string->number s)))
    (%int-string->number s (car radix))))

; --- Generic expt (supports float exponents) ---

(define
  (expt base exp)
  (cond
    ((and (%int-number? base) (%int-number? exp) (>= exp 0))
      (cond
        ((zero? exp) 1)
        ((even? exp) (expt (* base base) (quotient exp 2)))
        (#t (* base (expt base (- exp 1))))))
    (#t
      (fpow
        (if (float? base) base (exact->inexact base))
        (if (float? exp) exp (exact->inexact exp))))))
