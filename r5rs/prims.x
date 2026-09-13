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
      (if (symbol? name) (%cvt-prim name %string) name)
      handlers)))

(def make-instance (prim-ref (lit type) (lit make-instance)))
(def type? (prim-ref (lit type) (lit ?)))

; --- Raw object slots --------------------------------------------------------
; %-private in the platform, and they take the receiver the % names all take --
; which the call site supplies, so a plain alias is correct.
(def obj-ref %obj-ref)
(def obj-set! %obj-set!)
