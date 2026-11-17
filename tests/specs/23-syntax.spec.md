# @weight 1

## r5rs/syntax -- the Scheme highlighting grammar

The bundle's lang.xon declares a grammar, `scheme`, that x/tool/syntax
colours Scheme files with. Its module, `r5rs/syntax`, imports x-lang
libraries only, and registers the grammar as it loads.

The cases share one process, and a registered grammar stays registered, so
the catalogue's case comes first: it finds the grammar through lang.xon,
before anything has imported the module.

### the catalogue finds scheme by suffix, by #! and by modeline

```scheme
(import x/sys/posix) (import x/sys/file) (import x/tool/syntax)
(define root (Str8 replace "/r5rs/syntax.x" "" (%module-resolve-file "r5rs/syntax.x")))
(define tmp (File temp "/tmp/x-r5rs-spec-langs-"))
(File close (car tmp))
(define d (cdr tmp))
(File unlink d)
(File mkdir d)
(File symlink root (Str8 append d "/r5rs"))
(define was (Sys getenv "X_LANG_DIR"))
(Sys setenv "X_LANG_DIR" d)
(Syntax forget!)
(define row (List find (lambda (r) (eq? (car r) 'scheme)) (Syntax catalogue)))
(define (grammar-of path . text)
  (let ((g (apply Syntax (cons 'for-file (cons path text))))) (if (null? g) '() (g name))))
(define seen
  (list (List ref 1 row)
        (grammar-of "x.scm") (grammar-of "lib.sld")
        (grammar-of "run" "#!/usr/bin/env guile\n(display 1)\n")
        (grammar-of "run" "(display 1)\n; vi: set ft=scheme:\n")
        (grammar-of "x.txt")
        (let ((g (Syntax named 'scheme))) (list (g files) (g interpreters)))))
(File unlink (Str8 append d "/r5rs"))
(File rmdir d)
(Sys setenv "X_LANG_DIR" (if (null? was) "" was))
(Syntax forget!)
seen
```
---
    (r5rs/syntax scheme scheme scheme scheme () ((".scm" ".ss" ".sld") ("scheme" "guile" "chibi-scheme" "csi" "gosh")))

### a file's spans: comments, keywords, quotes, characters, booleans, numbers

```scheme
(import x/tool/syntax) (import r5rs/syntax)
((Syntax named 'scheme) spans
  "; c\n(define (f x) #| b |# '(a . \"s\") #\\space #t -1.5 #x1F x)\n")
```
---
    ((0 3 comment) (4 1 punct) (5 6 keyword) (12 1 punct) (16 1 punct) (18 7 comment) (26 1 operator) (27 1 punct) (32 3 string) (35 1 punct) (37 7 char) (45 2 constant) (48 4 number) (53 4 number) (59 1 punct))

### a datum comment mark, brackets, auxiliary syntax, |symbols|, an open string

`#;` is a comment mark and the datum after it colours as itself.  A
`|...|` symbol is plain.

```scheme
(import x/tool/syntax) (import r5rs/syntax)
((Syntax named 'scheme) spans "#;(x) [cond (else => f)] |a b| `(,@y) \"open")
```
---
    ((0 2 comment) (2 1 punct) (4 1 punct) (6 1 punct) (7 4 keyword) (12 1 punct) (13 4 keyword) (18 2 keyword) (22 1 punct) (23 1 punct) (31 1 operator) (32 1 punct) (33 2 operator) (36 1 punct) (38 5 string))
