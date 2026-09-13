; --- Hygienic Macros (R5RS §4.3) ---

; Ellipsis symbol (used for pattern matching, also registered as tokenizer in syntax.x)
(define %ellipsis-sym (string->symbol "..."))

; Gensym: generate unique symbols for hygiene

(define %gensym-counter 0)
(define
  (gensym)
  (set! %gensym-counter (+ %gensym-counter 1))
  (string->symbol
    (string-append "%g" (number->string %gensym-counter))))

; Safe eval: returns (t . value) if bound, () if unbound

(define
  (%sr-safe-eval sym env)
  (guard (e ()) (pair #t (eval sym env))))

; Sentinel for pattern match failure (unique identity)

(define %sr-no-match (pair (lit no) (lit match)))

; Remove duplicates (eq?)

(define
  (%sr-unique lst)
  (let loop
    ((in lst) (out ()))
    (if (null? in)
      (reverse out)
      (if (memq (car in) out)
        (loop (cdr in) out)
        (loop (cdr in) (pair (car in) out))))))

; --- Ellipsis helpers ---

; Count fixed elements in a pattern tail (after ...)

(define
  (%sr-tail-length pat)
  (if (pair? pat) (+ 1 (%sr-tail-length (cdr pat))) 0))

; Collect pattern variable names from a sub-pattern

(define
  (%sr-pattern-pvars pat literals)
  (if (symbol? pat)
    (if (or (eq? pat (lit _)) (memq pat literals))
      ()
      (list pat))
    (if (pair? pat)
      (append
        (%sr-pattern-pvars (car pat) literals)
        (%sr-pattern-pvars (cdr pat) literals))
      ())))

; Find pvars in template that have ellipsis bindings

(define
  (%sr-ellipsis-pvars template bindings)
  (if (symbol? template)
    (let ((b (assq template bindings)))
      (if (and b (pair? (cdr b)) (eq? (cadr b) %ellipsis-sym))
        (list template)
        ()))
    (if (pair? template)
      (append
        (%sr-ellipsis-pvars (car template) bindings)
        (%sr-ellipsis-pvars (cdr template) bindings))
      ())))

; Forward declaration for mutual recursion

(define %sr-match ())

; Match (sub-pat ... . tail-pat) against form list

(define
  (%sr-ellipsis-match
    sub-pat
    tail-pat
    form
    literals
    bindings)
  (let*
    ((pvars (%sr-unique (%sr-pattern-pvars sub-pat literals)))
      (tail-len (%sr-tail-length tail-pat))
      (form-len (length form))
      (rep-count (- form-len tail-len)))
    (if (< rep-count 0)
      %sr-no-match
      (let loop
        ((i 0)
          (f form)
          (collected (map (lambda (v) (list v)) pvars)))
        (if (= i rep-count)
          ; Match tail, then add ellipsis bindings

          (let ((tb (%sr-match tail-pat f literals bindings)))
            (if (eq? tb %sr-no-match)
              %sr-no-match
              (let add
                ((cs collected) (bs tb))
                (if (null? cs)
                  bs
                  (add
                    (cdr cs)
                    (pair
                      (pair (caar cs) (pair %ellipsis-sym (reverse (cdar cs))))
                      bs))))))
          ; Match next repeated element

          (let ((b (%sr-match sub-pat (car f) literals ())))
            (if (eq? b %sr-no-match)
              %sr-no-match
              (loop
                (+ i 1)
                (cdr f)
                (map
                  (lambda
                    (cv)
                    (let ((found (assq (car cv) b)))
                      (if found (pair (car cv) (pair (cdr found) (cdr cv))) cv)))
                  collected)))))))))

; Pattern matching for syntax-rules
; Returns bindings alist on success, %sr-no-match on failure
; Ellipsis bindings stored as (pvar . (... val1 val2 ...))

(set!
  %sr-match
  (lambda
    (pattern form literals bindings)
    (if (eq? pattern (lit _))
      bindings
      (if (symbol? pattern)
        (if (memq pattern literals)
          (if (and (symbol? form) (eq? pattern form))
            bindings
            %sr-no-match)
          (pair (pair pattern form) bindings))
        (if (null? pattern)
          (if (null? form) bindings %sr-no-match)
          (if (pair? pattern)
            ; Check for ellipsis: (sub-pat ... . tail)

            (if (and
                  (pair? (cdr pattern))
                  (eq? (cadr pattern) %ellipsis-sym))
              (%sr-ellipsis-match
                (car pattern)
                (cddr pattern)
                form
                literals
                bindings)
              ; Normal pair matching

              (if (pair? form)
                (let ((b (%sr-match (car pattern) (car form) literals bindings)))
                  (if (eq? b %sr-no-match)
                    %sr-no-match
                    (%sr-match (cdr pattern) (cdr form) literals b)))
                %sr-no-match))
            (if (equal? pattern form) bindings %sr-no-match)))))))

; Collect non-pvar symbols from template (excludes ... marker)

(define
  (%sr-introduced template pvars)
  (if (symbol? template)
    (if (or (memq template pvars) (eq? template %ellipsis-sym))
      ()
      (list template))
    (if (pair? template)
      (append
        (%sr-introduced (car template) pvars)
        (%sr-introduced (cdr template) pvars))
      ())))

; Substitute pattern variables in template
; Handles (tmpl ... . rest) by expanding ellipsis-bound vars

(define
  (%sr-subst template bindings)
  (if (symbol? template)
    (let ((b (assq template bindings)))
      (if b (cdr b) template))
    (if (pair? template)
      ; Check for ellipsis: (tmpl ... . rest)

      (if (and
            (pair? (cdr template))
            (eq? (cadr template) %ellipsis-sym))
        (let*
          ((sub-tmpl (car template))
            (rest-tmpl (cddr template))
            (epvars
              (%sr-unique (%sr-ellipsis-pvars sub-tmpl bindings)))
            (count
              (if (null? epvars)
                0
                (length (cddr (assq (car epvars) bindings))))))
          (let loop
            ((i 0) (acc ()))
            (if (= i count)
              (append (reverse acc) (%sr-subst rest-tmpl bindings))
              (let ((slice
                      (map
                        (lambda
                          (pv)
                          (pair pv (list-ref (cddr (assq pv bindings)) i)))
                        epvars)))
                (loop
                  (+ i 1)
                  (pair (%sr-subst sub-tmpl (append slice bindings)) acc))))))
        ; Normal pair

        (pair
          (%sr-subst (car template) bindings)
          (%sr-subst (cdr template) bindings)))
      template)))

; Rename symbols in template

(define
  (%sr-rename template renames)
  (if (symbol? template)
    (let ((r (assq template renames))) (if r (cdr r) template))
    (if (pair? template)
      (pair
        (%sr-rename (car template) renames)
        (%sr-rename (cdr template) renames))
      template)))

; Instantiate template with bindings and hygiene
; 1. Find introduced symbols (in template, not pattern vars)
; 2. For those bound in def-env: rename to gensyms, wrap in let
; 3. Substitute pattern variables

(define
  (%sr-instantiate template bindings def-env)
  (let*
    ((pvars (map car bindings))
      (introduced (%sr-unique (%sr-introduced template pvars)))
      (renames
        (let loop
          ((syms introduced) (acc ()))
          (if (null? syms)
            (reverse acc)
            (let ((v (%sr-safe-eval (car syms) def-env)))
              (if (pair? v)
                (loop (cdr syms) (pair (pair (car syms) (cdr v)) acc))
                (loop (cdr syms) acc))))))
      (renamed (%sr-rename template renames))
      (expanded (%sr-subst renamed bindings)))
    expanded))

; Try each clause, return first match's expansion

(define
  (%sr-expand form literals clauses def-env)
  (if (null? clauses)
    (error "syntax-rules: no matching pattern")
    (let*
      ((clause (car clauses))
        (pattern (car clause))
        (template
          (if (pair? (cdr clause)) (cadr clause) (lit (begin))))
        (bindings (%sr-match (cdr pattern) (cdr form) literals ())))
      (if (eq? bindings %sr-no-match)
        (%sr-expand form literals (cdr clauses) def-env)
        (%sr-instantiate template bindings def-env)))))

; syntax-rules: returns a transformer fn (lexically scoped closure)
; Captures literals, clauses, and def-env for hygiene

; TEMPLATES ARE REWRITTEN BEFORE THEY ARE INSTANTIATED, and this is the only
; place the rewrite can happen.
;
; A macro whose template is a definition -- ((_ var) (define var 1)) -- must not
; leak that binding out of the expansion.  R5RS pitfall 3.2, which this suite
; tests by name.  The expansion is evaluated in a frame, so a plain `def` binds
; there and leaves with it, while `define` binds globally and escapes.
;
; It cannot be fixed after instantiation.  %sr-instantiate resolves an
; introduced identifier to its VALUE -- that IS the hygiene mechanism -- so an
; expanded definition arrives as (#<op> y 1), not (define y 1), and there is no
; way to recognise it: `eq?` does not discriminate operatives, and
; (eq? cond define) answers #t.  Here in the template the head is still the
; symbol `define`, which is exactly what %r5rs-def-form matches.
;
; The leak has always been there.  It only became VISIBLE once define stopped
; depending on frame depth -- before that the global binding was made and then
; discarded when the frame unwound, so the suite passed by accident.
(define
  %sr-rewrite-clause
  (lambda (c)
    (if (pair? c)
      (if (pair? (cdr c))
        (cons (car c) (cons (%r5rs-def-form (cadr c)) (cddr c)))
        c)
      c)))

(define
  %sr-rewrite-clauses
  (lambda (cs)
    (if (null? cs) () (cons (%sr-rewrite-clause (car cs))
                            (%sr-rewrite-clauses (cdr cs))))))

(define
  syntax-rules
  (op (literals . clauses)
    sr-env
    (let ((clauses (%sr-rewrite-clauses clauses)))
      (lambda (form) (%sr-expand form literals clauses sr-env)))))

; define-syntax: bind name to a syntax transformer
; Strategy: store transformer fn under a gensym, bind name to an op
; that calls it. The op is dynamically scoped so it finds the gensym
; in the env at call time.

; BOTH BINDINGS GO THROUGH %def-global, AND THE EXPANSION EVALUATES IN THE USE
; SITE'S ENV.  Two changes, one cause.
;
; THE BINDINGS.  This used to hand a (begin (def ...) (def ...)) to a
; one-argument `eval` from inside an operative body and rely on the bindings
; escaping to the caller.  They escaped because `def` chose global-versus-local
; by SAVE-STACK DEPTH, and an operative in tail position left that stack empty
; -- the same accident r5rs/aliases.x's `define` note calls "extremely fragile"
; and stopped relying on.  `define` was converted then; define-syntax was not,
; and kept the trick.  %def-global takes `def`'s top-level path
; unconditionally, so it does not care how deep the frame is.
;
; THE EXPANSION.  The generated op evaluated its expansion with `eval!`, which
; does no env save/restore -- so a `def` in the expansion (what
; %sr-rewrite-clause rewrites a template's `define` INTO, precisely so it stays
; put) landed wherever the engine judged current.  `(eval <form> %sr-env)` is
; the shape letrec-syntax already used here, and it keeps the definition inside
; the expansion where R5RS pitfall 3.2 wants it.
;
; WHAT CHANGED UNDERNEATH.  x-engine-c v0.2.8 (#41): a `def` scopes by the LIVE
; FRAME, not by an empty save stack.  x-lang picked it up in f3698b11, a pin
; bump and nothing else.  Holding the x-lang source AT f3698b11 and swapping
; only the engine reproduces the whole split -- v0.2.7 green, v0.2.8 red -- so
; this is the engine's ruling, not a library change.
;
; MEASURED, whole suite, one file per process, booted from source
; (IMG=0 SPEC_BATCH=1), each row a full run:
;
;   platform                        engine   before   after
;   x-lang v0.10.0                  v0.1.6   667/0    667/0   (release-ref: history)
;   x-lang main 6c0ab5c5            v0.2.8   667/24   667/2
;
; So: no movement on the release this bundle declares, and 24 -> 2 on main.
;
; THE 2 THAT REMAINED WERE ONE DEFECT, AND IT WAS NOT THIS FORM'S.  let-syntax's
; expansion leaked its `def` to the global env under v0.2.8; that leak bound `x`
; globally in the pitfall-3.2 case, and a later macro then read the leaked
; VALUE, which was the whole of "macro expanding to lambda" answering 6 (= 1 +
; 5) instead of 15.  Fixed at let-syntax below, and fixing the leak took BOTH
; failures with it: nothing puts a stray global in scope any more, so the second
; had nothing to read.  Note the divergence is narrow: a plain `def` inside an
; operative called from a `let` still stays local on v0.2.8; it was the
; eval!-of-an-expansion path alone that reached global.
;
; NOT RECORDED IN known-failures.txt, and that is deliberate -- see the note
; there.  One contract serves both CI legs, and these two PASS on the pinned
; leg, so recording them would turn the pinned leg red while silencing the
; early warning the main leg exists to give.
;
; SPEC_SEAM_COLLECT WAS NOT IT, though the shape invited the guess -- a name
; defined in one snippet and gone in the next is exactly what the per-seam
; collect (x-lang#568/#572) does to a bundle whose reader holds C-side state,
; and the sibling bundles set the knob to 0 for that.  Measured both ways
; against the same platform, 16-syntax-rules: 32/22 with the collect on, the
; SAME 32/22 with it off.  It is not this bundle's problem and stays unset.
; The names also never were cross-snippet: every one of the 22 defines and
; uses its macro in ONE snippet.
;
; letrec-syntax needs no change: it already passed the caller's environment to
; `eval` explicitly, so it never depended on the depth.
(define
  define-syntax
  (op (name transformer-expr)
    e
    (def %ds-xfm (eval transformer-expr e))
    (def %ds-xfm-name
      (string->symbol
        (string-append "%xfm-" (symbol->string name))))
    (%def-global %ds-xfm-name %ds-xfm)
    (%def-global
      name
      (eval
        (list
          (lit op)
          (lit %sr-args)
          (lit %sr-env)
          (list
            (lit eval)
            (list
              %ds-xfm-name
              (list (lit pair) (list (lit lit) name) (lit %sr-args)))
            (lit %sr-env)))
        e))))

; let-syntax: local syntax bindings
; Processes one binding at a time, wrapping in let + recursing
; Uses %ls- prefixed params to avoid shadowing by let*/let (which also
; use 'bindings'/'body'/'e' as op params in dynamic scope).
;
;  THE EXPANSION EVALUATES IN THE USE SITE'S FRAME, AND THE ENV IS CAPTURED
; BEFORE THE TRANSFORMER RUNS.  The generated op used to hand its expansion to
; `eval!`, which does no env save/restore, so a `def` in the expansion landed
; wherever the engine judged current -- global, under x-engine-c v0.2.8, which
; scopes a `def` by the LIVE FRAME.  That is R5RS pitfall 3.2 failing, and the
; leaked binding then fed a later macro a value it had no business seeing.
;
;  THE OBVIOUS REPAIR IS WRONG, and it is worth saying why, because it was
; tried and reverted twice before this.  (eval <form> %sr-env) -- the shape
; define-syntax above uses -- breaks let-syntax on BOTH engines, and the reason
; is at the head of this comment: OP PARAMS ARE DYNAMICALLY SCOPED.  In that
; spelling the env argument is read AFTER the transformer call, and let-syntax
; NESTS -- pitfall 3.3 puts one inside another -- so an inner expansion has
; rebound %sr-env by the time it is read and the expansion evaluates in the
; wrong frame.  `eval!` never named the env at all, which is exactly why it was
; immune to that and leaked instead.  Wrapping the expansion in (let () ...) is
; the other dead end: the pinned engine stays green and main goes to 32.
;
;  So both params are CAPTURED AS LAMBDA ARGUMENTS first.  Arguments are
; evaluated before the body, so the capture happens before any transformer can
; run, and lambda params are LEXICAL, so no nested expansion can reach them.
; letrec-syntax below needs none of this: it already passed the caller's
; environment to `eval` explicitly, so it never depended on the depth.
;
;  MEASURED, whole suite, one file per process, booted from source
; (IMG=0 SPEC_BATCH=1), each row a full run, on top of the define-syntax
; conversion above:
;
;   platform          engine   before   after
;   x-lang v0.10.0    v0.1.6   667/0    667/0   (release-ref: history)
;   x-lang v0.13.0    v0.2.8   667/2    667/0   (release-ref: history)
;   x-lang main       v0.2.8   667/2    667/0   (release-ref: history)

(define
  let-syntax
  (op (%ls-bindings . %ls-body)
    %ls-e
    (if (null? %ls-bindings)
      (eval (pair (lit begin) %ls-body) %ls-e)
      (begin
        (def %ls-b (car %ls-bindings))
        (def %ls-name (car %ls-b))
        (def %ls-xfm (eval (cadr %ls-b) %ls-e))
        (def %ls-xfm-name
          (string->symbol
            (string-append "%xfm-" (symbol->string %ls-name))))
        (eval
          (list
            (lit begin)
            (list (lit def) %ls-xfm-name %ls-xfm)
            (list
              (lit let)
              (list
                (list
                  %ls-name
                  (list
                    (lit op)
                    (lit %sr-args)
                    (lit %sr-env)
                    (list
                      (list
                        (lit lambda)
                        (list (lit %ls-use-env) (lit %ls-use-args))
                        (list
                          (lit eval)
                          (list
                            %ls-xfm-name
                            (list (lit pair) (list (lit lit) %ls-name) (lit %ls-use-args)))
                          (lit %ls-use-env)))
                      (lit %sr-env)
                      (lit %sr-args)))))
              (pair (lit let-syntax) (pair (cdr %ls-bindings) %ls-body))))
          %ls-e)))))

; letrec-syntax: like let-syntax but transformers can see each other
; We achieve this by evaluating all transformers first, then binding them all
; Uses same strategy as define-syntax: def gensym names, then let-bind macro ops

(define
  letrec-syntax
  (op (%lrs-bindings . %lrs-body)
    %lrs-e
    (if (null? %lrs-bindings)
      (eval (pair (lit begin) %lrs-body) %lrs-e)
      (begin
        ; Build defs + let-bindings for all transformers

        (def %lrs-defs ())
        (def %lrs-let-bindings ())
        (for-each
          (lambda
            (b)
            (def %lrs-n (car b))
            (def %lrs-xfm (eval (cadr b) %lrs-e))
            (def %lrs-xn
              (string->symbol
                (string-append "%xfm-" (symbol->string %lrs-n))))
            (set!
              %lrs-defs
              (cons (list (lit def) %lrs-xn %lrs-xfm) %lrs-defs))
            (set!
              %lrs-let-bindings
              (cons
                (list
                  %lrs-n
                  (list
                    (lit op)
                    (lit %sr-args)
                    (lit %sr-env)
                    (list
                      (lit eval)
                      (list
                        %lrs-xn
                        (list (lit pair) (list (lit lit) %lrs-n) (lit %sr-args)))
                      (lit %sr-env))))
                %lrs-let-bindings)))
          %lrs-bindings)
        (eval
          (append
            (list (lit begin))
            (reverse %lrs-defs)
            (list
              (pair
                (lit let)
                (pair (reverse %lrs-let-bindings) %lrs-body))))
          %lrs-e)))))
