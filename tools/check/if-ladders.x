; # x-r5rs -- R5RS Scheme on x-lang
;
; ## tools/check/if-ladders.x -- report every nested `if` that should be a `match`
;
; @description Reads each module as s-expressions and prints one line per
;   MAXIMAL nested-if ladder at or above the threshold.
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
;     ., .,
;     {O,O}
;     (   )
;      " "
;
;   sh x.sh --no-pin -q -f tools/check/if-ladders.x -- FILE...
;
; Prints one "FILE NAME LENGTH" line per maximal ladder at or above the
; threshold, for tools/check/if-ladders.sh to aggregate per function and check
; against tools/contract/if-ladders.txt.
;
; `match` is an engine primitive and the flat way to write a decision with more
; than a couple of arms; a chain of `if`s nested through their else branches
; says the same thing one indent deeper per arm. This reads the file as
; s-expressions (never evaluates it), because an `if` ladder is a shape a grep
; cannot see. Symbol comparison is by name -- symbols intern per base.
;
; The .scm files are out of scope: this walker reads the file it is handed and
; does not follow includes, and those files are Scheme, where `cond` is the
; primitive.

(do
  (import x/sys/posix)
  (import x/sys/file)
  (import x/codec/xon)
  (import x/tool/contract)

  ; The guard stays on, and the walker is written to fit under it: it allocates
  ; no closure per node (an earlier lambda-per-node walk exhausted a 7GB CI
  ; runner in a runtime with no automatic GC), and each top-level form is swept
  ; before the next.
  (Contract alloc-guard!)

  ; A ladder of this many arms or more is reported.  Three arms is an
  ; ordinary two-way decision with a fallback; four is a table.
  (def %il-threshold 4)

  (def %il-argv (Contract argv))
  (when (null? %il-argv)
    (do (%stderr "Usage: x.sh --no-pin -q -f tools/check/if-ladders.x -- FILE...\n")
        (Sys exit 1)))

  (def %il-name (fn (_ x) (if (symbol? x) (symbol->str x) "")))
  (def %il-is? (fn (_ x s) (str=? (%il-name x) s)))

  ; (if TEST THEN ELSE) -- the three-armed form is the one that chains
  (def %il-if?
    (fn (_ f)
      (if (pair? f)
        (if (%il-is? (first f) "if") (= (List length f) 4) #f)
        #f)))

  ; how many arms this ladder has, following the else branch down
  (def %il-arms
    (fn (self f n)
      (if (%il-if? f) (self (List ref 3 f) (+ n 1)) n)))

  (def %il-walk ())
  ; the branches of every link, and whatever the last else is -- walked
  ; WITHOUT reporting the links themselves, which are this ladder
  (def %il-inside
    (fn (self f file top)
      (if (%il-if? f)
        (do (%il-walk (List ref 1 f) file top)
            (%il-walk (List ref 2 f) file top)
            (self (List ref 3 f) file top))
        (%il-walk f file top))))

  ; No lambda per node: the two walkers call each other by name, so a tree of a
  ; hundred thousand pairs allocates nothing but the walk. The list walk also
  ; survives an improper tail -- a parameter list is (a b . rest).
  (def %il-walk-list ())

  (set! %il-walk
    (fn (self form file top)
      (when (pair? form)
        (if (%il-if? form)
          (do
            (let ((n (%il-arms form 0)))
              (when (>= n %il-threshold)
                (do (display file) (display " ") (display top) (display " ")
                    (display n) (newline))))
            (%il-inside form file top))
          (%il-walk-list form file top)))))

  (set! %il-walk-list
    (fn (self form file top)
      (when (pair? form)
        (do (%il-walk (first form) file top)
            (self (rest form) file top)))))

  ; Three binders, because a bundle is written in two surfaces: r5rs/base.x and
  ; its neighbours load before the Scheme vocabulary exists and say `def`;
  ; everything under r5rs/scm/ says `define`, in the plain and curried
  ; spellings. A checker that knew only `def` would report those files' ladders
  ; under an empty name -- the aggregate keys on the first two fields, so a
  ; blank middle field slides the depth into the name.
  (def %il-binder?
    (fn (_ x)
      (let ((s (%il-name x)))
        (match ((str=? s "def")    #t)
               ((str=? s "set!")   #t)
               ((str=? s "define") #t)
               (#t                 #f)))))

  ; (def NAME ...) and (define NAME ...) name a symbol; Scheme's curried
  ; (define (NAME . args) body) names the head of a list.
  (def %il-bound-name
    (fn (_ x)
      (match ((pair? x) (%il-name (first x)))
             (#t        (%il-name x)))))

  ; A ladder that sits in no binder is named for the call it sits in, falling
  ; back to a placeholder only when there is no head to name it after -- a bare
  ; placeholder alone collapsed every call site in a file onto one key.
  ;
  ; Parenthesised, so a call site never collides with a definition: `(%foo)` is
  ; a ladder inside a call to %foo, and %foo the function of that name may also
  ; be defined in the same file. No space goes in either, so the row stays
  ; three fields.
  (def %il-head-name
    (fn (_ form)
      (let ((h (%il-name (first form))))
        (match ((str=? h "") "(top-level)")
               (#t           (Str8 append "(" (Str8 append h ")")))))))

  ; (def NAME ...) / (set! NAME ...) / (define NAME ...) and the curried
  ; (define (NAME . args) body) -- a form that BINDS, and has something to bind.
  (def %il-binding-form?
    (fn (_ form)
      (match ((not (pair? form))        #f)
             ((not (pair? (rest form))) #f)
             (#t (%il-binder? (first form))))))

  ; The name a ladder is reported under: what the top-level form binds, else
  ; what it calls, else the placeholder.
  (def %il-top-name
    (fn (_ form)
      (match ((%il-binding-form? form) (%il-bound-name (first (rest form))))
             ((pair? form)             (%il-head-name form))
             (#t                       "(top-level)"))))

  ; A sweep between top-level forms: nothing here collects on its own, and a
  ; large module is one long walk, so without this the guard could fire part
  ; way through the largest file.
  (def %il-file
    (fn (self forms file)
      (when (pair? forms)
        (do (%il-walk (first forms) file (%il-top-name (first forms)))
            (Heap collect)
            (self (rest forms) file)))))

  (List for-each
    (fn (_ file) (%il-file (Xon parse (File read-all file)) file))
    %il-argv))
