; # x-r5rs -- R5RS Scheme on x-lang
;
; ## r5rs/aliases.x -- Scheme's names, in x's current spellings
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; THIS FILE IS WHERE THE ROT LIVED.  Everything else in this bundle is Scheme
; written in Scheme; this is the one layer that names x-lang directly, so it is
; the one layer the platform's four-year drift landed on.  Three kinds of
; change, and only the first is a rename:
;
;   1. %-privatisation.  set-first! is %set-first!, and the % names take a
;      leading receiver -- which callers do not pass, because the receiver is
;      supplied at the call site.  (def set-car! %set-first!) is still correct.
;
;   2. Bare globals became CLASS METHODS.  length, append, map, filter and
;      reverse are unbound in every dialect now; they live on List.  vector-ref
;      is (Vector ref), string-length is (Str8 length).  These are not renames:
;      the receiver moved into the call, so each one needs a wrapper.
;
;   3. Ambient prims became CATALOG entries.  `convert` and `read` are fetched
;      with prim-ref rather than assumed.
;
; AND ONE THAT IS NONE OF THE THREE, and matters more than all of them:
;
;   (def lambda fn)
;
; was the 2024 line, and it is now wrong in a way that breaks every procedure
; in the bundle.  x's `fn` takes an explicit receiver -- (fn (_ n) ...) -- so
; aliasing lambda to it binds Scheme's FIRST PARAMETER to the receiver.
; ((lambda (x) x) 42) returns the closure, not 42, and every .scm file here is
; written in lambda.  It has to be an operative that splices the receiver in.

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
; lambda: splice x's receiver into Scheme's formals.  A dotted formal
; ((lambda args ...) -- a symbol rather than a list) has to keep its shape, so
; the receiver is spliced only when there is a list to splice into; a bare
; symbol becomes (_ . args), which is x's own spelling for the same thing.
; INTERIOR DEFINES ARE REWRITTEN AT CONSTRUCTION TIME, which is how Schemes
; handle them anyway (the letrec* conversion).  They cannot work at run time:
; `define` is an operative, so its `def` executes inside define's OWN frame,
; and in body position that frame is not in tail position -- the binding is
; created and discarded with it, leaving the name unbound EVERYWHERE rather
; than shadowed.  A literal `def` in the same slot binds in the body's frame
; and is visible to the forms after it.
;
; One level deep, deliberately: exactly the forms that ARE the body.  A define
; inside an `if` inside a body is not a definition context in Scheme either.
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

; define, in both spellings.
;
; NO LONGER A TCO TRICK.  This used to put its eval in tail position so that
; TCO would pop the operative's frame before `def` ran, leaving the save-stack
; empty and the binding global -- because `def` decides global-versus-local by
; save-stack depth and an operative has no other way to define for its caller.
; That worked and was extremely fragile: ONE extra wrapper frame between the
; caller and here and every definition landed nowhere, silently.  It is why
; x-r7rs cannot load its own `guard` (x-lang#527).
;
; eval! IS THE ANSWER, and it was there all along.  It evaluates with no env
; save/restore, so a `def` inside it persists in the caller's world whatever the
; frame depth -- no tail-position accident, no TCO dependency.
;
; This file briefly called (prim-ref (lit base) (lit def-global)), a primitive
; proposed on x-lang#527 and never shipped: engine v0.1.2 answers () for it, so
; every `define` called nil and bound nothing.  663 of 663 specs failed on
; unbound symbols, with no diagnostic pointing anywhere near here.  A prim-ref
; miss is indistinguishable from a legitimate nil until it is far away.
; THE VALUE IS QUOTED, and leaving it bare is a bug that hides for a long time.
; (list (lit def) n v) builds (def name <value>) and eval! then EVALUATES it --
; so the value is evaluated a second time.  Numbers, strings and procedures
; self-evaluate and nothing looks wrong; a SYMBOL value gets looked up.
;   (define %ellipsis-sym (string->symbol "..."))
; therefore died with `Unbound SYMBOL '...'`, three files away from the cause.
; Wrapping in (lit ...) makes def bind the value it was handed.
; TWO MECHANISMS, BECAUSE ONE OF THEM IS NOT ENOUGH ON ITS OWN.
;
; eval! evaluates with no env save/restore, so a `def` inside it lands in
; whatever env is CURRENT.  At top level that is global and everything works.
; It is not frame-independent: interpose one operative frame -- which
; shadowing any late-bound name does, R7RS `guard` being the live case --
; and the binding lands in that frame and is discarded with it.  Measured:
; with a bare passthrough guard loaded, (define v 42), (define (f p) p) and
; (define f (lambda (p) p)) ALL bind nothing.
;
; (base def-global) takes `def`'s top-level path unconditionally and is
; frame-independent.  It is not in engine v0.1.2, so this prefers it when
; present and falls back to eval! when not -- correct at the prompt on any
; engine, correct under frames on one that carries it.
;
; THE FALLBACK IS EXPLICIT ON PURPOSE.  prim-ref answers () for a member
; that is not there, so calling the result blind binds nothing and reports
; nothing; that cost two long hunts already.  See x-lang#527.
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
; SUBJECT-LAST, AND THAT IS THE TRAP.  These were bare globals in 2024 and are
; class methods now -- but the methods do not take their subject first:
;
;   (List ref n lst)      (Vector ref i v)      (Str8 ref i v)
;   (List drop n lst)     (Vector set! i x v)   (Str8 sub st LEN v)
;
; So this is not a receiver-shuffle, it is an argument reordering, and one that
; type-checks either way often enough to be found by a wrong answer rather than
; an error.  (Str8 sub) takes a LENGTH where Scheme's substring takes an END,
; which is the same hazard once more.  x-lang#66 tracks the convention itself.
;
; Every wrapper below exists to put Scheme's order back.
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

; CHAR TO STRING IS NOT A CONVERT.  (%cvt #\A %string) answers nil -- the
; char->string direction is not registered on the type -- so this goes through
; Str8 make, which builds a one-character string from a fill.
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
; AN EMPTY LIST CONVERTS TO NIL, NOT "".  %convert-to answers nil for a nil
; value by design -- absence stays absence -- but Scheme's (list->string '())
; is the empty STRING, and every builder above it (string, string-map,
; vector->string) inherits the difference.
(def list->string (fn (_ l) (if (null? l) "" (%cvt l %string))))
(def number->string
  (fn (_ n . rest)
    (if (null? rest) (%cvt n %string) (%cvt n %string (first rest)))))

; string->number: integer first, then float, #f on neither.  R5RS returns #f
; for an unparseable string, and the platform's convert returns nil for a miss
; -- two different spellings of "no", and the wrapper is where they meet.
; The 2024 version reached for string->float and (make-instance %float ...);
; both are in the tower the entry boots, so convert answers for them now.
(def string->number
  (fn (_ s . rest)
    (if (null? rest)
      (if (= (Str8 length s) 0)
        #f
        (let ((%i (guard (_ ()) (%cvt s %int))))
          (if (null? %i)
            (let ((%f (guard (_ ()) (%cvt s %float))))
              ; A ZERO FLOAT IS NOT PROOF OF A NUMBER.  The conversion runs
              ; strtod, which answers 0 for "abc" as readily as for "0.0", so a
              ; zero result only counts when the text actually begins with a
              ; digit.  Without this (string->number "abc") is 0.0 -- truthy --
              ; and R5RS's contract that a failure is #f quietly inverts.
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
; All of these were bare globals in 2024 and are Num methods now.  The order
; matches Scheme's here, so each is a straight forward.  min/max/gcd/lcm are
; variadic in R5RS and binary on the class, hence the folds.
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
; Both were bare globals in 2024 and are classes now.  R5RS's spellings are
; make-rectangular / real-part / imag-part; the class calls the constructor
; `make`, which is the only name here that is not a straight forward.
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
; 06-stdlib.spec.md tests the PLATFORM's functional vocabulary through this
; surface rather than R5RS's -- fold, zip, range, compose -- which is a
; reasonable thing for a personality's suite to assert: it is checking that the
; host library is still reachable.  Every one of these moved onto a class.
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
