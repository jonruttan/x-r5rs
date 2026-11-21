# x-r5rs card

## Run

```sh
x -l r5rs
x -l r5rs -f PROGRAM.scm
x -l r5rs -f tests/card/fact.scm -> 3628800
```

```r5rs
(define (fact n)
  (if (= n 0) 1 (* n (fact (- n 1)))))

(display (fact 10))                     ; -> 3628800
(newline)
```

| Run                   | Is                                                |
|-----------------------|---------------------------------------------------|
| `x -l r5rs`           | the prompt: each form's value is printed          |
| `x -l r5rs -f FILE`   | a program in a file: only what it writes is printed |

## Definitions

| Form                              | Does                                  |
|-----------------------------------|---------------------------------------|
| `(define NAME VALUE)`             | names a value                         |
| `(define (NAME ARG ...) BODY ...)` | names a procedure                    |
| `(lambda (ARG ...) BODY ...)`     | a procedure with no name              |
| `(lambda (A . REST) BODY ...)`    | REST is a list of the further arguments |
| `(set! NAME VALUE)`               | changes what NAME names               |
| `(let ((N V) ...) BODY ...)`      | local names, each V worked out outside |
| `(let* ((N V) ...) BODY ...)`     | each V sees the names before it       |
| `(letrec ((N V) ...) BODY ...)`   | each V sees every name: for recursion |
| `(let LOOP ((N V) ...) BODY ...)` | a loop: `(LOOP V ...)` goes round     |
| `(begin FORM ...)`                | the forms in order; the last one's value |

```r5rs
(define x 10)
(define (square n) (* n n))
(define add (lambda (a b) (+ a b)))
(define (count first . rest) (+ 1 (length rest)))
(display (square x)) (newline)          ; -> 100
(display (add 1 2)) (newline)           ; -> 3
(display (count 'a 'b 'c)) (newline)    ; -> 3
(set! x (+ x 1))
(display x) (newline)                   ; -> 11
(display (let ((a 1) (b 2)) (+ a b))) (newline)         ; -> 3
(display (let* ((a 1) (b (+ a 1))) (* a b))) (newline)  ; -> 2
(display (letrec ((even? (lambda (n) (if (= n 0) #t (odd? (- n 1)))))
                  (odd? (lambda (n) (if (= n 0) #f (even? (- n 1))))))
           (even? 10)))
(newline)                               ; -> #t
(display (let loop ((i 0) (acc 0))
           (if (= i 5) acc (loop (+ i 1) (+ acc i)))))
(newline)                               ; -> 10
```

## Conditionals

| Form                               | Gives                                |
|------------------------------------|--------------------------------------|
| `(if TEST A B)`                    | A when TEST is not `#f`, else B      |
| `(cond (TEST FORM ...) ... (else FORM ...))` | the first clause that holds |
| `(cond (TEST => PROC))`            | PROC called on TEST's value          |
| `(case KEY ((DATUM ...) FORM ...) ...)` | the clause that lists KEY       |
| `(and A B ...)`                    | the first `#f`, or the last value    |
| `(or A B ...)`                     | the first value that is not `#f`     |
| `(not A)`                          | `#t` when A is `#f`                  |
| `(do ((N INIT STEP) ...) (TEST RESULT) BODY ...)` | a loop, until TEST   |

```r5rs
(define (size n)
  (cond ((< n 10) 'small)
        ((< n 100) 'medium)
        (else 'large)))
(display (size 5)) (display " ") (display (size 500)) (newline)
; -> small large
(display (if (> 3 2) 'yes 'no)) (newline)               ; -> yes
(display (case (* 2 3)
           ((2 3 5 7) 'prime)
           ((1 4 6 8 9) 'composite)
           (else 'other)))
(newline)                               ; -> composite
(display (cond ((assv 'b '((a 1) (b 2))) => cadr) (else 'none)))
(newline)                               ; -> 2
(display (and 1 2 3)) (display " ") (display (and 1 #f 3)) (newline)
; -> 3 #f
(display (or #f 2 3)) (display " ") (display (not 0)) (newline)
; -> 2 #f
(display (do ((i 0 (+ i 1)) (sum 0 (+ sum i))) ((= i 5) sum)))
(newline)                               ; -> 10
```

## Numbers

| Procedures                         | For                                  |
|------------------------------------|--------------------------------------|
| `+ - * /`                          | arithmetic; `/` of integers is exact |
| `= < > <= >=`                      | comparison, of any number of numbers |
| `quotient` `remainder` `modulo`    | integer division                     |
| `abs` `min` `max` `gcd` `lcm`      | the usual                            |
| `expt` `sqrt` `exp` `log` `sin` `cos` `atan` | powers, roots, the rest    |
| `floor` `ceiling` `round` `truncate` | to a whole number                  |
| `number?` `integer?` `rational?` `real?` | which kind                     |
| `exact?` `inexact?` `exact->inexact` `inexact->exact` | exactness         |
| `zero?` `positive?` `negative?` `odd?` `even?` | tests                    |
| `number->string` `string->number`  | to and from text                     |

```r5rs
(display (+ 1 2 3)) (display " ") (display (- 10 3 2)) (newline) ; -> 6 5
(display (/ 1 3)) (display " ") (display (/ 6 3)) (newline)     ; -> 1/3 2
(display (exact->inexact (/ 1 3))) (newline)    ; -> 0.333333333333333
(display (+ 0.5 (/ 1 2))) (newline)             ; -> 1.0
(display (quotient 17 5)) (display " ")
(display (remainder -17 5)) (display " ")
(display (modulo -17 5)) (newline)              ; -> 3 -2 3
(display (max 1 5 3)) (display " ") (display (gcd 12 18)) (newline) ; -> 5 6
(display (expt 2 10)) (display " ") (display (sqrt 16)) (newline) ; -> 1024 4
(display (round 2.5)) (display " ") (display (floor -2.5)) (newline)
; -> 2 -3
(display (< 1 2 3)) (display " ") (display (= 1 1.0)) (newline) ; -> #t #t
(display (exact? (/ 1 3))) (display " ")
(display (integer? 2.0)) (newline)              ; -> #t #t
(display (number->string 255 16)) (display " ")
(display (string->number "100")) (newline)      ; -> ff 100
```

## Equivalence

| Procedure      | Holds for                                          |
|----------------|----------------------------------------------------|
| `eq?`          | the same object: symbols, `'()`, one pair          |
| `eqv?`         | that, and equal numbers and characters             |
| `equal?`       | that, and lists, vectors and strings alike all through |

```r5rs
(display (eq? 'a 'a)) (display " ")
(display (eq? '() '())) (newline)               ; -> #t #t
(display (eqv? 2 2)) (display " ")
(display (eqv? "ab" "ab")) (newline)            ; -> #t #f
(display (equal? "ab" "ab")) (display " ")
(display (equal? '(1 (2)) '(1 (2)))) (newline)  ; -> #t #t
(display (eq? (list 1) (list 1))) (newline)     ; -> #f
```

## Pairs and lists

| Procedures                        | For                                   |
|-----------------------------------|---------------------------------------|
| `cons` `car` `cdr`                | a pair, and its two halves            |
| `cadr` `cddr` `caar` ...          | `car` and `cdr` composed, to four deep |
| `list` `length` `append` `reverse` | making and joining lists             |
| `list-tail` `list-ref`            | a list from, or the item at, a position |
| `memq` `memv` `member`            | the rest of a list from an item       |
| `assq` `assv` `assoc`             | the pair with a key, in a list of pairs |
| `map` `for-each` `apply`          | a procedure over lists                |
| `pair?` `null?` `list?`           | tests                                 |
| `set-car!` `set-cdr!`             | change a pair                         |

```r5rs
(define l (list 1 2 3))
(display (cons 0 l)) (newline)                  ; -> (0 1 2 3)
(display (car l)) (display " ") (display (cdr l)) (display " ")
(display (cadr l)) (newline)                    ; -> 1 (2 3) 2
(display (cons 1 2)) (newline)                  ; -> (1 . 2)
(display (append l '(4 5))) (display " ")
(display (reverse l)) (newline)                 ; -> (1 2 3 4 5) (3 2 1)
(display (length l)) (display " ")
(display (list-ref l 2)) (display " ")
(display (list-tail l 1)) (newline)             ; -> 3 3 (2 3)
(display (memq 'c '(a b c d))) (display " ")
(display (member "x" '("y"))) (newline)         ; -> (c d) #f
(display (assoc 'b '((a 1) (b 2)))) (newline)   ; -> (b 2)
(display (map + '(1 2 3) '(10 20 30))) (newline) ; -> (11 22 33)
(display (map (lambda (n) (* n n)) l)) (newline) ; -> (1 4 9)
(for-each (lambda (n) (display n) (display ",")) l)
(newline)                                       ; -> 1,2,3,
(display (apply + 1 2 '(3 4))) (newline)        ; -> 10
(set-car! l 9)
(display l) (display " ") (display (list? l)) (display " ")
(display (null? '())) (newline)                 ; -> (9 2 3) #t #t
```

## Symbols, characters and strings

| Procedures                              | For                             |
|-----------------------------------------|---------------------------------|
| `symbol?` `symbol->string` `string->symbol` | symbols                     |
| `#\a` `#\space` `#\newline`             | a character                     |
| `char->integer` `integer->char` `char-upcase` | characters                |
| `char=?` `char<?` `char-alphabetic?` `char-numeric?` | tests              |
| `string-length` `string-ref` `substring` | parts of a string              |
| `string-append` `string` `make-string`  | making one                      |
| `string=?` `string<?` `string-ci=?`     | comparison                      |
| `string->list` `list->string`           | to and from a list of characters |
| `string-set!` `string-fill!` `string-copy` | changing one, and a copy     |

```r5rs
(define s "Hello")
(display (string-length s)) (display " ")
(write (string-ref s 1)) (display " ")
(write (substring s 1 3)) (newline)             ; -> 5 #\e "el"
(write (string-append s ", " "World")) (newline) ; -> "Hello, World"
(display (string=? "a" "a")) (display " ")
(display (string<? "a" "b")) (display " ")
(display (string-ci=? "A" "a")) (newline)       ; -> #t #t #t
(write (string->list "abc")) (newline)          ; -> (#\a #\b #\c)
(write (list->string (list #\x #\y))) (newline) ; -> "xy"
(display (char->integer #\A)) (display " ")
(write (integer->char 97)) (display " ")
(write (char-upcase #\a)) (newline)             ; -> 65 #\a #\A
(display (symbol->string 'abc)) (display " ")
(display (string->symbol "Hello")) (display " ")
(display (symbol? 'a)) (newline)                ; -> abc Hello #t
(write (string->number "42")) (display " ")
(write (number->string 42)) (newline)           ; -> 42 "42"
```

## Vectors

| Procedures                          | For                                |
|-------------------------------------|------------------------------------|
| `#(1 2 3)` `(vector 1 2 3)` `(make-vector N FILL)` | making one          |
| `vector-length` `vector-ref` `vector-set!` | its size, an item, changing one |
| `vector->list` `list->vector` `vector-fill!` | to and from a list; filling |

```r5rs
(define v (vector 1 2 3))
(vector-set! v 0 'x)
(display v) (display " ") (display (vector-length v)) (display " ")
(display (vector-ref v 2)) (newline)            ; -> #(x 2 3) 3 3
(display (make-vector 3 0)) (display " ")
(display (vector->list v)) (display " ")
(display (list->vector '(a b))) (newline)       ; -> #(0 0 0) (x 2 3) #(a b)
```

## Quotation

| Form                 | Gives                                             |
|----------------------|---------------------------------------------------|
| `'X` `(quote X)`     | X itself, not its value                           |
| `` `X ``             | X, with the unquoted parts worked out             |
| `,X`                 | inside `` ` ``: the value of X                    |
| `,@X`                | inside `` ` ``: the items of the list X, spliced in |

```r5rs
(define n 3)
(define l '(a b))
(display '(+ 1 2)) (newline)                    ; -> (+ 1 2)
(display `(n is ,n)) (newline)                  ; -> (n is 3)
(display `(1 ,@l 2 ,(* n n))) (newline)         ; -> (1 a b 2 9)
(display (eval '(+ 1 2) (interaction-environment))) (newline)   ; -> 3
```

## Macros

| Form                                         | Is                         |
|----------------------------------------------|----------------------------|
| `(define-syntax NAME RULES)`                 | a macro                    |
| `(syntax-rules (LITERAL ...) (PATTERN TEMPLATE) ...)` | its RULES        |
| `...` after a pattern item                   | any number of that item    |
| `(let-syntax ((NAME RULES)) BODY ...)`       | a macro for BODY alone     |

```r5rs
(define-syntax swap!
  (syntax-rules ()
    ((_ a b) (let ((tmp a)) (set! a b) (set! b tmp)))))
(define tmp 1)
(define other 2)
(swap! tmp other)
(display (list tmp other)) (newline)            ; -> (2 1)

(define-syntax my-or
  (syntax-rules ()
    ((_) #f)
    ((_ e) e)
    ((_ e rest ...) (let ((t e)) (if t t (my-or rest ...))))))
(define t 5)
(display (my-or #f t)) (newline)                ; -> 5

(define-syntax while
  (syntax-rules ()
    ((_ test body ...) (let loop () (if test (begin body ... (loop)) #f)))))
(define i 0)
(while (< i 3) (display i) (set! i (+ i 1)))
(newline)                                       ; -> 012
```

## Control

| Form                                   | Does                              |
|----------------------------------------|-----------------------------------|
| `(call-with-current-continuation PROC)` | PROC gets the way out of the call |
| `(dynamic-wind BEFORE THUNK AFTER)`    | BEFORE and AFTER, around THUNK    |
| `(delay FORM)` `(force PROMISE)`       | FORM worked out once, when asked  |
| `(values A B)` `(call-with-values MAKE USE)` | several values; taking them |
| `(procedure? X)`                       | whether X can be called           |

```r5rs
(display (call-with-current-continuation
           (lambda (k) (+ 1 (k 42)))))
(newline)                                       ; -> 42

(define (find-first pred items)
  (call-with-current-continuation
    (lambda (return)
      (for-each (lambda (x) (if (pred x) (return x))) items)
      #f)))
(display (find-first even? '(1 3 4 5))) (newline)       ; -> 4

(dynamic-wind
  (lambda () (display "in "))
  (lambda () (display "body "))
  (lambda () (display "out")))
(newline)                                       ; -> in body out

(define p (delay (begin (display "once ") 7)))
(display (force p)) (display " ") (display (force p)) (newline)
; -> once 7 7
(call-with-values (lambda () (values 1 2))
                  (lambda (a b) (display (+ a b))))
(newline)                                       ; -> 3
```

## Output and input

| Procedure                         | Does                                  |
|-----------------------------------|---------------------------------------|
| `(display X)`                     | writes X for a person: a string bare  |
| `(write X)`                       | writes X as it is read: a string quoted |
| `(newline)` `(write-char C)`      | ends the line; writes one character   |
| `(read)` `(read-char)` `(peek-char)` | reads a datum; a character         |
| `(open-input-file NAME)` `(open-output-file NAME)` | a port on a file     |
| `(call-with-output-file NAME PROC)` | PROC with a port, closed after      |
| `(with-output-to-file NAME THUNK)` | THUNK's output goes to the file      |
| `(eof-object? X)`                 | whether a read met the end            |

```r5rs
(display "text") (display " ") (write "text") (newline) ; -> text "text"
(display #\a) (display " ") (write #\a) (newline)       ; -> a #\a
(write-char #\x) (newline)                              ; -> x
(write '(1 "two" #\3 4.5)) (newline)            ; -> (1 "two" #\3 4.5)
```

## Differs

| Here                                   | In the report                      |
|----------------------------------------|------------------------------------|
| `(expt 2 100)` is 1.26765060022823e+30 | an exact integer                   |
| `(sqrt -4)` is nan                     | may be a complex number            |
| `(round 2.5)` is 2, `(floor -2.5)` -3  | 2.0 and -3.0: inexact, as given    |
| `(string->number "1e3")` is `#f`       | 1000.0                             |
| a float is written to 15 digits        | as many as read back the same      |
| `(display car)` writes `#<prim>`       | not specified                      |
| a value with none is written `()`      | not specified                      |

## More

| Where                             | What                                |
|-----------------------------------|-------------------------------------|
| `README.md`                       | what is built, and the suite        |
| `docs/r5rs.pdf`                   | the report                          |
| `tests/specs/15-r5rs-compliance.spec.md` | the report's own examples    |
| `make card`                       | runs every program on this page     |
