# @weight 4

Kept out of `16-syntax-rules.spec.md` deliberately: the ellipsis group in that
file crashes the interpreter (x-lang#158), which kills the rest of the batch, so
anything appended after it never runs. These are the regression cover for the
pitfall-3.2 leak and they need to actually execute.

## macro-introduced definitions do not escape (pitfall 3.2, both paths)

### define-syntax: the definition stays inside the expansion

```scheme
(define-syntax dsfoo (syntax-rules () ((_ var) (define var 777))))
(let ((y 2)) (dsfoo y) y)
```
---
    2

### define-syntax: and leaves nothing behind

```scheme
(not (eq? (guard (e (quote gone)) y) 777))
```
---
    #t

### let-syntax: the definition stays inside the expansion

```scheme
(let-syntax ((lsfoo (syntax-rules () ((_ var) (define var 888)))))
  (let ((z 2)) (lsfoo z) z))
```
---
    2

### let-syntax: and leaves nothing behind

```scheme
(not (eq? (guard (e (quote gone)) z) 888))
```
---
    #t
