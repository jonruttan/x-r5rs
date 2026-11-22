; # x-r5rs -- R5RS Scheme on x-lang
;
; ## r5rs/syntax.x -- the Scheme highlighting grammar
;
; @description The grammar x/tool/syntax colours Scheme files with: comments,
;   strings, characters, numbers, booleans and the syntax keywords.
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; bundle.xon's (grammar scheme ...) form names this module, and x/tool/syntax
; imports it the first time a file needs the grammar, in whatever process is
; colouring: vi's, a REPL's, an HTML renderer's.  So it imports x-lang
; libraries only, never the interpreter.  It colours R7RS small, of which
; R5RS is most: x-r7rs reads its files through this grammar too.
;
; A ; comment runs to the line's end, a #| comment to its |#, and #; is a
; comment mark, the datum after it coloured as itself.  A string or a #|
; comment still open at the end of the text runs to it.  #\ and the bytes
; after it is a character; |...| is a symbol, plain.  An atom is a keyword
; when it is one of the syntax keywords, a constant when it is a boolean,
; a number when it reads as one, and otherwise plain.  Brackets are
; punctuation, the quote marks operators.  A line opening a form at its
; first column starts outside any string or comment.

(module r5rs/syntax)
(import x/type/list)
(import x/type/str)
(import x/reader/lexer)
(import x/tool/syntax)
(import x/core/doors str-byte-ref char->int str-byte-len)

; The syntax keywords of R5RS and R7RS small, and the auxiliary syntax
(def scheme-syntax-keywords
  (list "define" "define-syntax" "define-record-type" "define-values"
        "define-library" "lambda" "case-lambda" "let" "let*" "letrec" "letrec*"
        "let-values" "let*-values" "let-syntax" "letrec-syntax" "syntax-rules"
        "if" "cond" "case" "when" "unless" "and" "or" "do" "begin" "set!"
        "quote" "quasiquote" "unquote" "unquote-splicing" "delay" "delay-force"
        "parameterize" "guard" "import" "export" "include" "include-ci"
        "cond-expand" "else" "=>"))

(def scheme-syntax-booleans (list "#t" "#f" "#true" "#false"))

; An atom's bytes: every printing byte but a quote mark, a bracket, a ;, a "
; or a |, and every byte above 127
(def %scm-sx-atom
  (list 33 (pair 35 38) (pair 42 43) (pair 45 58) (pair 60 90) 92 (pair 94 95)
        (pair 97 123) (pair 125 126) (pair 127 255) (pair -128 -1)))

(def scheme-syntax-rules
  (fn (_)
    (list (Lexer until (lit comment) ";" "\n" (lit to-end))
          (Lexer until (lit comment) "#|" "|#" (lit to-end))
          (Lexer table (lit comment) (list "#;"))
          (Lexer nested (lit string) "\"" (lit dq) (list (list (lit dq) 34 92 ())) (lit to-end))
          (Lexer nested (lit bar) "|" (lit bar) (list (list (lit bar) 124 92 ())) (lit to-end))
          (Lexer pattern (lit char) (list (list "#" 1 1) (list "\\" 1 1) (list #t 1 1)
                                          (list %scm-sx-atom 0 ())))
          (Lexer run (lit blank) (list (pair 0 32)) (list (pair 0 32)))
          (Lexer table (lit open) (list "(" ")" "[" "]" "#(" "#u8("))
          (Lexer table (lit quote) (list "'" "`" "," ",@"))
          (Lexer run (lit atom) %scm-sx-atom %scm-sx-atom)
          (Lexer any (lit bad)))))

(def %scm-sx-byte (fn (_ s i) (char->int (str-byte-ref s i))))
(def %scm-sx-digit? (fn (_ b) (if (>= b 48) (<= b 57) #f)))

; Does TEXT read as a number: a digit first, or a sign or a dot before one,
; or a # radix or exactness prefix, or an infinity or a NaN
(def %scm-sx-number?
  (fn (_ text)
    (let ((n (str-byte-len text)) (b0 (%scm-sx-byte text 0)))
      (match
        ((%scm-sx-digit? b0) #t)
        ((List includes? text (list "+inf.0" "-inf.0" "+nan.0" "-nan.0")) #t)
        ((if (List includes? b0 (list 43 45 46)) (> n 1) #f)
          (let ((b1 (%scm-sx-byte text 1)))
            (if (%scm-sx-digit? b1) #t
              (if (= b1 46) (if (> n 2) (%scm-sx-digit? (%scm-sx-byte text 2)) #f) #f))))
        ((if (= b0 35) (> n 2) #f)
          (List includes? (%scm-sx-byte text 1) (list 120 88 98 66 111 79 100 68 101 69 105 73)))
        (#t #f)))))

(def %scm-sx-atom-class
  (fn (_ text)
    (match
      ((List includes? text scheme-syntax-keywords) (lit keyword))
      ((List includes? text scheme-syntax-booleans) (lit constant))
      ((%scm-sx-number? text) (lit number))
      (#t ()))))

(Syntax register!
  (let ((g (Syntax make (lit scheme) (scheme-syntax-rules)
             (list (pair (lit comment) (lit comment))
                   (pair (lit string) (lit string))
                   (pair (lit char) (lit char))
                   (pair (lit open) (lit punct))
                   (pair (lit quote) (lit operator))
                   (pair (lit atom) %scm-sx-atom-class)))))
    (g sync (fn (_ s ls) (if (< ls (str-byte-len s)) (= (%scm-sx-byte s ls) 40) #f)))
    g))

(provide r5rs/syntax scheme-syntax-rules scheme-syntax-keywords scheme-syntax-booleans)
