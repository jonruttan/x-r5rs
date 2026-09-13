; --- R5RS Derived expression types (§4.2) ---
;
; General-purpose constructs (when, unless, let*, letrec, named let,
; cond, case, delay/force) are now in lib/x/derived.x and lib/x/promise.x.
;
; This file provides only:
;   1. R5RS do (iteration) — redefines x-lang's do (= begin)
;   2. Post-override patches for forms that used (lit do) for sequencing

; (do ((var init step) ...) (test expr ...) command ...)
;
; Dispatched, not rebound: x's `do` is its sequencing operative, resolved by
; name at run time from many platform call sites (the printer among them), so
; rebinding the global breaks the platform underneath. R5RS iteration has a
; shape nothing in x shares -- the first argument is a list of binding lists
; (possibly empty, every element a pair) and the second a (test . results)
; pair -- so `do` below dispatches on that shape and hands anything else to the
; platform's own operative, captured as %r5rs-seq before this file loads.
;
; The heuristic is a shape test, not airtight: a sequencing call with a
; non-pair in its first argument routes correctly. x-lang#525 asks for the
; platform to stop late-binding the name. tests/spec-runner.sh probes for an
; older platform whose recache walk was itself spelled as an iteration `do`,
; and boots the suite from source there.

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
    ; letrec, not sequential `def`s: binding helpers with `def` inside this
    ; operative and relying on each being visible to the next holds only at a
    ; particular frame depth, and interposing a frame (as loading R7RS `guard`
    ; does) leaves a helper unbound. letrec binds through real parameters, so
    ; the helpers see each other regardless of the caller. (x-lang#527.)
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
