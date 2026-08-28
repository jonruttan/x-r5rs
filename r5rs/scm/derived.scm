; --- R5RS Derived expression types (§4.2) ---
;
; General-purpose constructs (when, unless, let*, letrec, named let,
; cond, case, delay/force) are now in lib/x/derived.x and lib/x/promise.x.
;
; This file provides only:
;   1. R5RS do (iteration) — redefines x-lang's do (= begin)
;   2. Post-override patches for forms that used (lit do) for sequencing

; --- do (R5RS iteration) ---
;
; (do ((var init step) ...) (test expr ...) command ...)
;
; DISPATCHED, NOT REBOUND, and this is the one place a personality cannot
; simply re-mean a spelling.  x's `do` is its sequencing operative, and the
; platform library resolves it BY NAME at run time from 275 call sites -- the
; printer among them.  Rebind the global and the platform breaks underneath
; you: (def do 5) makes the next write raise `Unbound SYMBOL '%print-tw`, and
; (def do (op ...)) kills the top-level loop outright, silently.
;
; So `do` below is a dispatcher.  R5RS iteration has a shape nothing in x
; shares: the first argument is a LIST OF BINDING LISTS -- possibly empty, and
; every element a pair -- and the second is a (test . results) pair.  Anything
; else is sequencing and is handed to the platform's own operative, captured as
; %r5rs-seq before this file loads.
;
; The heuristic is honest rather than airtight.  (do ((f x)) ((g y))) meant as
; two calls would be read as iteration; no such form exists in x's library or
; in this bundle, and every real sequencing call -- (do (Sys dup2 3 0) (Sys
; close 3)) -- has a non-pair in its first argument and routes correctly.
; x-lang#525 asks for the platform to stop late-binding the name.

(define
  %r5rs-do-shape?
  (lambda (forms)
    (if (null? forms) #f
      (if (null? (cdr forms)) #f
        (if (pair? (cadr forms))
          (if (null? (car forms)) #t
            (if (pair? (car forms)) (%r5rs-all-pairs? (car forms)) #f))
          #f)))))

(define
  %r5rs-all-pairs?
  (lambda (l)
    (if (null? l) #t
      (if (pair? (car l)) (%r5rs-all-pairs? (cdr l)) #f))))

(define
  do
  (op forms
    e
    (if (%r5rs-do-shape? forms)
      (tail-eval (cons (lit %r5rs-do-iter) forms) e)
      (tail-eval (cons (lit %r5rs-seq) forms) e))))

(define
  %r5rs-do-iter
  (op (bindings test-and-result . body)
    env
    (let ((vars (map car bindings))
           (inits (map (lambda (b) (list-ref b 1)) bindings))
           (steps
             (map
               (lambda (b) (if (> (length b) 2) (list-ref b 2) (car b)))
               bindings))
           (test (car test-and-result))
           (result (cdr test-and-result)))
      (tail-eval
        (cons
          (list
            (lit lambda)
            ()
            (cons
              (lit letrec)
              (cons
                (list
                  (list
                    (lit %do-loop)
                    (cons
                      (lit lambda)
                      (cons
                        vars
                        (list
                          (list
                            (lit if)
                            test
                            (if (null? result)
                              (list (lit if) #f #f)
                              (cons (lit begin) result))
                            (append
                              (cons (lit begin) body)
                              (list (cons (lit %do-loop) steps)))))))))
                (list (cons (lit %do-loop) inits)))))
          ())
        env))))

; --- Override forms that used (lit do) to use (lit begin) instead ---

; (do was just redefined as the R5RS iteration form, so any construct
; that used (lit do) for sequential evaluation must switch to (lit begin))

(define
  when
  (op (test . body)
    e
    (if (eval test e) (tail-eval (pair (lit begin) body) e))))
(define
  unless
  (op (test . body)
    e
    (if (not (eval test e)) (tail-eval (pair (lit begin) body) e))))
(define
  let*
  (op (bindings . body)
    e
    (if (null? bindings)
      (tail-eval (pair (lit begin) body) e)
      (tail-eval
        (list
          (lit let)
          (list (first bindings))
          (pair (lit let*) (pair (rest bindings) body)))
        e))))
(define
  cond
  (op clauses
    e
    (let %cond-loop
      ((cls clauses))
      (if (null? cls)
        ()
        (let ((clause (first cls)))
          (if (eq? (first clause) (lit else))
            (tail-eval (pair (lit begin) (rest clause)) e)
            (let ((test-val (eval (first clause) e)))
              (if test-val
                (if (and (pair? (rest clause))
                         (eq? (first (rest clause)) (lit =>)))
                  ((eval (first (rest (rest clause))) e) test-val)
                  (tail-eval (pair (lit begin) (rest clause)) e))
                (%cond-loop (rest cls))))))))))
(define
  case
  (op (key . clauses)
    e
    ; LETREC, NOT SEQUENTIAL `def`s.  The 2024 body bound three helpers with
    ; `def` inside this operative and relied on each being visible to the next.
    ; That holds only at a particular frame depth: interpose one more frame --
    ; which loading R7RS `guard` does -- and case-check-datums is unbound by the
    ; time case-loop looks for it.  letrec binds through real parameters, so the
    ; helpers see each other regardless of who called us.  (x-lang#527 is the
    ; general form of this.)
    (let ((case-val (eval key e)))
      (letrec
        ((case-match?
           (lambda (datum)
             (if (number? case-val) (= case-val datum) (eq? case-val datum))))
         (case-check-datums
           (lambda (datums)
             (if (null? datums) ()
               (if (case-match? (first datums)) #t
                 (case-check-datums (rest datums))))))
         (case-loop
           (lambda (cls)
             (if (null? cls) ()
               (if (or (eq? (first (first cls)) (lit else))
                       (case-check-datums (first (first cls))))
                 (tail-eval (pair (lit begin) (rest (first cls))) e)
                 (case-loop (rest cls)))))))
        (case-loop clauses)))))
