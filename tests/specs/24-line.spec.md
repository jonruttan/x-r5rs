# @weight 1

## r5rs/line -- Scheme as a lang of the session

`scheme-lang-register!` registers a Scheme with the platform's `Lang`
registry: its prompt, its printer and `scheme-paint`, the painter that
colours the line being typed by the `scheme` grammar. A seam it does not
name stays x-lang's: a Scheme form is an s-expression, and the platform's
reader and line evaluator read it.

### the registered lang names its prompt, its printer and the Scheme painter, and nothing else

```scheme
(import r5rs/line scheme-paint scheme-lang-register!)
(scheme-lang-register! "r5rs-line-spec" write)
(define row (Lang get "r5rs-line-spec"))
(list (Assoc get '%repl-prompt row)
      (eq? (Assoc get '%repl-print row) write)
      (eq? (Assoc get '%repl-paint row) scheme-paint)
      (Assoc has? '%repl-eval-line row))
```
---
    ("> " #t #t #f)

### with colour off the painter answers the line unchanged

The harness has no terminal, so colour is off.

```scheme
(import r5rs/line scheme-paint)
(list (scheme-paint "(define (f x) x)" '() '())
      (scheme-paint "x\")" '() "(display \"a\n"))
```
---
    ("(define (f x) x)" "x\")")
