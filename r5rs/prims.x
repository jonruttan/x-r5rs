; # x-r5rs -- R5RS Scheme on x-lang
;
; ## r5rs/prims.x -- the raw platform layer, under the names the .scm files use
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; The .scm files reach past Scheme in three places -- multiple values and
; continuations need a custom type, and the port layer needs the FFI -- and
; `type` and `ffi` are de-registered as ambient namespaces (R5), so those
; references are fetched with prim-ref. Named once here so the .scm files stay
; Scheme and the next platform rename is a one-file edit.

; The type handles this bundle asks convert and the type prims for, fetched
; by name through the platform's public door.  r5rs/aliases.x and
; scm/numeric.scm read them too.
(def %r5rs-int-type (Type named INTEGER))
(def %r5rs-string-type (Type named STRING))
(def %r5rs-symbol-type (Type named SYMBOL))
(def %r5rs-char-type (Type named CHARACTER))
(def %r5rs-float-type (Type named FLOAT))
(def %r5rs-rational-type (Type named RATIONAL))

(provide r5rs/prims make-type make-instance type? obj-ref obj-set!)

; --- The type system ---------------------------------------------------------
; make-type takes a string name; a symbol (which the .scm callers may pass) is
; current prim will not accept, so the wrapper converts and the .scm files can
; keep either spelling.
(def %type-make (prim-ref (lit type) (lit make)))
(def %cvt-prim (prim-ref (lit convert) (lit to)))

(def make-type
  (fn (_ name handlers)
    (%type-make
      (if (symbol? name) (%cvt-prim name %r5rs-string-type) name)
      handlers)))

(def make-instance (prim-ref (lit type) (lit make-instance)))
(def type? (prim-ref (lit type) (lit ?)))

; --- Raw object slots --------------------------------------------------------
; Fetched from the catalog, like the type prims above.  They take the receiver
; the platform's prims all take, which the call site supplies.
(def obj-ref (prim-ref (lit obj) (lit ref)))
(def obj-set! (prim-ref (lit obj) (lit set!)))
