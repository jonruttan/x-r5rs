; # x-r5rs -- R5RS Scheme on x-lang
;
; ## r5rs/aliases.x -- Scheme's names, in x's current spellings
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; This is the one layer that names x-lang directly (everything else in the
; bundle is Scheme written in Scheme), so it carries three kinds of adaptation:
;
;   1. %-privatised names. set-first! is %set-first!, and the % names take a
;      leading receiver supplied at the call site.
;   2. Bare globals that became class methods. length, append, map, vector-ref,
;      string-length and the rest live on List/Vector/Str8 now; the receiver
;      moved into the call, so each needs a wrapper.
;   3. Ambient prims that became catalog entries: `convert` and `read` are
;      fetched with prim-ref.
;
; And `lambda`: it must be an operative that splices x's receiver in, not
; (def lambda fn). x's `fn` takes an explicit receiver -- (fn (_ n) ...) -- so
; aliasing lambda to it would bind Scheme's first parameter to the receiver,
; and every .scm file here is written in lambda.

(provide r5rs/aliases lambda define begin quote quasiquote)

; --- Catalog fetches ---------------------------------------------------------
(def %cvt (prim-ref (lit convert) (lit to)))
(def %prim-read (prim-ref (lit io) (lit read)))

; convert is applicative in Scheme's world.  NO EXPLICIT RECEIVER: every call
; supplies the `_` slot implicitly, `apply` included, so passing one by hand
; shifts every argument along -- (convert 'point %string) becomes
; (%convert-to 'point %string) with val=() and answers nil rather than raising.
; That silence is what makes it worth a comment: the first symptom was
; define-record-type failing 13 specs with `Str8 append: not a string`, three
; layers away.
(def convert (fn (_ v target . extra) (apply %cvt (pair v (pair target extra)))))

; --- The binding forms -------------------------------------------------------
; lambda: splice x's receiver into Scheme's formals. A dotted formal (a bare
; symbol rather than a list) keeps its shape -- the receiver is spliced only
; when there is a list to splice into, and a bare symbol becomes (_ . args).
; Interior defines are rewritten at construction time (the letrec* conversion
; Schemes use): a `define` in body position becomes a literal `def`, which
; binds in the body's frame and is visible to the forms after it. One level
; deep -- exactly the forms that are the body.
(def %r5rs-def-form
  (fn (_ form)
    (if (pair? form)
      (if (eq? (first form) (lit define))
        (if (pair? (first (rest form)))
          (list
            (lit def)
            (first (first (rest form)))
            (pair (lit lambda) (pair (rest (first (rest form))) (rest (rest form)))))
          (list (lit def) (first (rest form)) (first (rest (rest form)))))
        form)
      form)))

(def %r5rs-body-defs
  (fn (self body)
    (if (null? body)
      ()
      (pair (%r5rs-def-form (first body)) (self (rest body))))))

(def lambda
  (op (formals . body)
    e
    (eval
      (pair
        (lit fn)
        (pair
          (if (pair? formals)
            (pair (lit _) formals)
            (if (null? formals) (list (lit _)) (pair (lit _) formals)))
          (%r5rs-body-defs body)))
      e)))

; define, in both spellings. Binds globally via (base def-global), which takes
; def's top-level path unconditionally and is frame-independent; where the
; engine lacks it (prim-ref answers ()), the fallback is eval! of
; (def name (lit value)). The (lit ...) wrap matters: eval! evaluates the def
; form it is handed, which would evaluate the value a second time -- invisible
; for self-evaluating values, but a symbol value would be looked up. The eval!
; fallback is not frame-independent, so def-global is preferred where present.
; See x-lang#527.
(def %dg-prim (prim-ref (lit base) (lit def-global)))
(def %def-global
  (if (null? %dg-prim)
    (fn (_ n v) (eval! (list (lit def) n (list (lit lit) v))))
    (fn (_ n v) (%dg-prim n v))))
(def define
  (op (name-or-form . body)
    e
    (if (pair? name-or-form)
      (%def-global
        (first name-or-form)
        (eval (pair (lit lambda) (pair (rest name-or-form) body)) e))
      (%def-global name-or-form (eval (first body) e)))))

(def begin do)
(def quote lit)
(def quasiquote quasi)
(def else #t)

; --- Pairs -------------------------------------------------------------------
(def cons pair)
(def car first)
(def cdr rest)
(def set-car! %set-first!)
(def set-cdr! %set-rest!)

; --- Lists, vectors, strings: the classes, unwrapped ------------------------
; The class methods take their subject last, not first: (List ref n lst),
; (Vector set! i x v), (Str8 sub st len v). So these wrappers are an argument
; reordering, not a receiver shuffle, and (Str8 sub) takes a length where
; Scheme's substring takes an end. Every wrapper below puts Scheme's order
; back. x-lang#66 tracks the convention.
(def length (fn (_ l) (List length l)))
(def reverse (fn (_ l) (List reverse l)))
(def list-ref (fn (_ l n) (List ref n l)))
(def list-tail (fn (_ l n) (List drop n l)))
; append and string-append are variadic on both sides, but `apply` cannot
; deliver a variadic call to a CLASS -- the class is the receiver, not a
; callable -- so both fold over the binary form instead.  R5RS returns the last
; argument as-is (it may be an improper tail), which the fold preserves.
(def append (fn (_ . ls) (%r5rs-fold-append ls)))
(def %r5rs-fold-append
  (fn (self ls)
    (if (null? ls)
      ()
      (if (null? (rest ls))
        (first ls)
        (List append (first ls) (self (rest ls)))))))
; map/for-each are variadic over lists in R5RS and on the class, and the
; class's order already matches Scheme's (f first, lists after), so these are
; the one group that delegates cleanly.  memq/assq and friends are NOT here:
; scm/list.scm defines them in Scheme, which is where they belong.
(def map (fn (_ f . ls) (%r5rs-map-n f ls)))
(def for-each (fn (_ f . ls) (%r5rs-for-each-n f ls)))
(def filter (fn (_ pred l) (List filter pred l)))

(def %r5rs-map-n
  (fn (_ f ls)
    (if (null? (rest ls))
      (List map f (first ls))
      (List map f (first ls) (first (rest ls))))))

(def %r5rs-for-each-n
  (fn (_ f ls)
    (if (null? (rest ls))
      (List for-each f (first ls))
      (List for-each f (first ls) (first (rest ls))))))

; --- Vectors -----------------------------------------------------------------
(def make-vector
  (fn (_ n . rest) (Vector make n (if (null? rest) () (first rest)))))
(def vector-ref (fn (_ v i) (Vector ref i v)))
(def vector-set! (fn (_ v i x) (Vector set! i x v)))
(def vector-length (fn (_ v) (Vector length v)))
(def vector? (fn (_ v) (Vector vector? v)))

; --- Strings -----------------------------------------------------------------
(def string-length (fn (_ s) (Str8 length s)))
(def string-ref (fn (_ s i) (Str8 ref i s)))
(def string-append (fn (_ . ss) (%r5rs-fold-str-append ss)))
(def %r5rs-fold-str-append
  (fn (self ss)
    (if (null? ss)
      ""
      (if (null? (rest ss))
        (first ss)
        (Str8 append (first ss) (self (rest ss)))))))
; Scheme's substring is [start, end); Str8 sub is (start, LENGTH).
(def substring (fn (_ s a b) (Str8 sub a (- b a) s)))
(def string-copy (fn (_ s) (Str8 sub 0 (Str8 length s) s)))
(def make-string
  (fn (_ n . rest) (Str8 make n (if (null? rest) #\space (first rest)))))

; char->string is not a convert: (%cvt #\A %string) answers nil, since that
; direction is not registered on the type, so this goes through Str8 make,
; building a one-character string from a fill.
(def %r5rs-char->str (fn (_ c) (Str8 make 1 c)))

; --- Characters --------------------------------------------------------------
(def char->integer (fn (_ c) (%cvt c %int)))
(def integer->char (fn (_ n) (%cvt n %char)))
(def char-upcase (fn (_ c) (Char upcase c)))
(def char-downcase (fn (_ c) (Char downcase c)))
(def char-alphabetic? (fn (_ c) (Char alphabetic? c)))
(def char-numeric? (fn (_ c) (Char numeric? c)))
(def char-whitespace? (fn (_ c) (Char whitespace? c)))
(def char-upper-case? (fn (_ c) (Char upper-case? c)))
(def char-lower-case? (fn (_ c) (Char lower-case? c)))

; --- Conversions -------------------------------------------------------------
(def string->symbol (fn (_ s) (%cvt s %symbol)))
(def symbol->string (fn (_ s) (%cvt s %string)))
; An empty list converts to nil, not "": %convert-to answers nil for a nil
; value by design, but Scheme's (list->string '()) is the empty string, and
; every builder above (string, string-map, vector->string) inherits the
; difference.
(def list->string (fn (_ l) (if (null? l) "" (%cvt l %string))))
(def number->string
  (fn (_ n . rest)
    (if (null? rest) (%cvt n %string) (%cvt n %string (first rest)))))

; string->number: integer first, then float, #f on neither. R5RS returns #f
; for an unparseable string; the platform's convert returns nil for a miss, and
; the wrapper is where the two spellings of "no" meet.
(def string->number
  (fn (_ s . rest)
    (if (null? rest)
      (if (= (Str8 length s) 0)
        #f
        (let ((%i (guard (_ ()) (%cvt s %int))))
          (if (null? %i)
            (let ((%f (guard (_ ()) (%cvt s %float))))
              ; A zero float is not proof of a number: the conversion runs
              ; strtod, which answers 0 for "abc" as readily as for "0.0", so a
              ; zero result only counts when the text begins with a digit --
              ; otherwise (string->number "abc") would be 0.0, truthy, and
              ; R5RS's #f-on-failure contract would invert.
              (if (null? %f)
                #f
                (if (= %f 0)
                  (if (%r5rs-digit-start? s) %f #f)
                  %f)))
            %i)))
      (let ((%r (guard (_ ()) (%cvt s %int (first rest)))))
        (if (null? %r) #f %r)))))

(def %r5rs-digit-start?
  (fn (_ s)
    (if (= (Str8 length s) 0)
      #f
      (let ((%c (%cvt (Str8 ref 0 s) %int)))
        (if (< %c 48) #f (if (> %c 57) #f #t))))))

(def write-char (fn (_ c) (display (%r5rs-char->str c))))

; --- Composition accessors ---------------------------------------------------
; All 28, to four deep, as R5RS requires.  Kept explicit: a generated set would
; be shorter and would not be greppable, and these are what a Scheme programmer
; reaches for at 2am.
(def caar (fn (_ x) (first (first x))))
(def cadr (fn (_ x) (first (rest x))))
(def cdar (fn (_ x) (rest (first x))))
(def cddr (fn (_ x) (rest (rest x))))
(def caaar (fn (_ x) (first (first (first x)))))
(def caadr (fn (_ x) (first (first (rest x)))))
(def cadar (fn (_ x) (first (rest (first x)))))
(def caddr (fn (_ x) (first (rest (rest x)))))
(def cdaar (fn (_ x) (rest (first (first x)))))
(def cdadr (fn (_ x) (rest (first (rest x)))))
(def cddar (fn (_ x) (rest (rest (first x)))))
(def cdddr (fn (_ x) (rest (rest (rest x)))))
(def caaaar (fn (_ x) (first (first (first (first x))))))
(def caaadr (fn (_ x) (first (first (first (rest x))))))
(def caadar (fn (_ x) (first (first (rest (first x))))))
(def caaddr (fn (_ x) (first (first (rest (rest x))))))
(def cadaar (fn (_ x) (first (rest (first (first x))))))
(def cadadr (fn (_ x) (first (rest (first (rest x))))))
(def caddar (fn (_ x) (first (rest (rest (first x))))))
(def cadddr (fn (_ x) (first (rest (rest (rest x))))))
(def cdaaar (fn (_ x) (rest (first (first (first x))))))
(def cdaadr (fn (_ x) (rest (first (first (rest x))))))
(def cdadar (fn (_ x) (rest (first (rest (first x))))))
(def cdaddr (fn (_ x) (rest (first (rest (rest x))))))
(def cddaar (fn (_ x) (rest (rest (first (first x))))))
(def cddadr (fn (_ x) (rest (rest (first (rest x))))))
(def cdddar (fn (_ x) (rest (rest (rest (first x))))))
(def cddddr (fn (_ x) (rest (rest (rest (rest x))))))

; --- Numerics: the Num class, unwrapped -------------------------------------
; Num methods now; the order matches Scheme's, so each is a straight forward.
; min/max/gcd/lcm are variadic in R5RS and binary on the class, hence the
; folds.
(def zero? (fn (_ n) (Num zero? n)))
(def positive? (fn (_ n) (Num positive? n)))
(def negative? (fn (_ n) (Num negative? n)))
(def even? (fn (_ n) (Num even? n)))
(def odd? (fn (_ n) (Num odd? n)))
(def abs (fn (_ n) (Num abs n)))
(def expt (fn (_ b e) (Num expt b e)))
(def modulo (fn (_ a b) (Num modulo a b)))
(def min (fn (_ a . more) (%r5rs-fold-num a more (fn (_ x y) (Num min x y)))))
(def max (fn (_ a . more) (%r5rs-fold-num a more (fn (_ x y) (Num max x y)))))
(def gcd (fn (_ . ns) (if (null? ns) 0 (%r5rs-fold-num (first ns) (rest ns) (fn (_ x y) (Num gcd x y))))))
(def lcm (fn (_ . ns) (if (null? ns) 1 (%r5rs-fold-num (first ns) (rest ns) (fn (_ x y) (Num lcm x y))))))

(def %r5rs-fold-num
  (fn (self acc more f)
    (if (null? more) acc (self (f acc (first more)) (rest more) f))))

; --- Exactness ---------------------------------------------------------------
; R5RS's exact/inexact axis is x's INT/FLOAT split.  convert is the door both
; ways; `truncate` is what R5RS asks for on the inexact->exact direction.
(def float? (fn (_ n) (%float? n)))
(def exact->inexact (fn (_ n) (%cvt n %float)))
(def inexact->exact (fn (_ n) (%cvt n %int)))

; --- Strings: the comparisons ------------------------------------------------
; str=? and str? survived as bare globals; the ordering comparisons did not, so
; they are spelled through the class.  scm/string.scm builds >?, <=? and >=? on
; top of these two, so only the two primitives belong here.
(def string? (fn (_ s) (str? s)))
(def string=? (fn (_ a b) (str=? a b)))
(def string<? (fn (_ a b) (< (%r5rs-str-cmp a b) 0)))

; A three-way compare, because the class exposes ci<? but not a plain <?, and
; scm/string.scm needs an ordering it can build the other three from.
(def %r5rs-str-cmp
  (fn (self a b)
    (if (= (Str8 length a) 0)
      (if (= (Str8 length b) 0) 0 (- 0 1))
      (if (= (Str8 length b) 0)
        1
        (let ((%ca (%cvt (Str8 ref 0 a) %int))
              (%cb (%cvt (Str8 ref 0 b) %int)))
          (if (< %ca %cb)
            (- 0 1)
            (if (> %ca %cb)
              1
              (self (Str8 sub 1 (- (Str8 length a) 1) a)
                    (Str8 sub 1 (- (Str8 length b) 1) b)))))))))

; --- Vectors -----------------------------------------------------------------
(def vector (fn (_ . xs) (Vector from-list xs)))
(def vector->list (fn (_ v) (List from-seq v)))
(def list->vector (fn (_ l) (Vector from-list l)))

; --- The numeric tower: Rational and Complex --------------------------------
; Rational and Complex classes. R5RS's spellings are make-rectangular /
; real-part / imag-part; the class constructor is `make`, the only name here
; that is not a straight forward.
(def make-rectangular (fn (_ re im) (Complex make re im)))
(def real-part (fn (_ z) (Complex real-part z)))
(def imag-part (fn (_ z) (Complex imag-part z)))
(def magnitude (fn (_ z) (Complex magnitude z)))
(def angle (fn (_ z) (Complex angle z)))
(def make-polar (fn (_ m a) (Complex from-polar m a)))
(def numerator (fn (_ q) (Rational numerator q)))
(def denominator (fn (_ q) (Rational denominator q)))
(def rational? (fn (_ q) (Rational rational? q)))

; --- x-lang's own stdlib, reached through Scheme -----------------------------
; 06-stdlib.spec.md tests the platform's functional vocabulary through this
; surface -- fold, zip, range, compose -- checking that the host library is
; still reachable. Every one of these moved onto a class.
(def identity (fn (_ x) (Fn identity x)))
(def compose (fn (_ . fs) (%r5rs-compose-all fs)))
(def fold (fn (_ f init l) (List fold f init l)))
(def fold-right (fn (_ f init l) (List fold-right f init l)))
(def reduce (fn (_ f l) (List reduce f l)))
(def range (fn (_ a b) (List range a b)))
(def zip (fn (_ a b) (List zip a b)))
(def any? (fn (_ pred l) (List any? pred l)))
(def every? (fn (_ pred l) (List all? pred l)))
(def take (fn (_ n l) (List take n l)))
(def drop (fn (_ n l) (List drop n l)))
(def flatten (fn (_ l) (List flatten l)))
(def last (fn (_ l) (List last l)))
(def sum (fn (_ l) (List sum l)))
(def product (fn (_ l) (List product l)))

; compose is variadic and the class's is binary; R5RS-style right-to-left.
(def %r5rs-compose-all
  (fn (self fs)
    (if (null? fs)
      (fn (_ x) x)
      (if (null? (rest fs))
        (first fs)
        (Fn compose (first fs) (self (rest fs)))))))

; --- Float math: the FFI wrappers, %-privatised -----------------------------
; These were bare globals in lib/x/float.x and are %-prefixed in
; lib/x/num/float.x now.  A plain alias is correct -- the % names take the
; receiver every % name takes, and the call site supplies it.
(def fsqrt %fsqrt)
(def fsin %fsin)
(def fcos %fcos)
(def ftan %ftan)
(def fexp %fexp)
(def flog %flog)
(def fpow %fpow)
(def fabs %fabs)
(def fceil %fceil)
(def ffloor %ffloor)
(def ftrunc %ftrunc)
(def frint %frint)
(def fatan %fatan)
(def fatan2 %fatan2)
(def fasin %fasin)
(def facos %facos)
(def float->string %float->str)
(def string->float %str->float)

; --- The rest of the functional stdlib --------------------------------------
(def const (fn (_ x) (Fn const x)))
; (curry f x) is partial application here, not classic currying -- which is
; what the class means by it and what the suite asserts: (curry add 5) is a
; one-argument function, not a chain.
(def curry (fn (_ f x) (Fn curry f x)))
(def flip (fn (_ f) (Fn flip f)))
(def complement (fn (_ f) (Fn complement f)))

; zip pairs into two-element LISTS here, not into dotted pairs.  (List zip)
; returns ((1 . 4) ...); the suite -- and every Scheme that has zip -- expects
; ((1 4) ...), so this goes through zip-with rather than zip.
(def zip (fn (_ a b) (List zip-with (fn (_ x y) (list x y)) a b)))
