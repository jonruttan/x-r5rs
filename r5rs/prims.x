; # x-r5rs -- R5RS Scheme on x-lang
;
; ## r5rs/prims.x -- the raw platform layer, under its 2024 names
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; The .scm files below this one reach past Scheme in three places -- multiple
; values and continuations need a custom TYPE, and the port layer needs the FFI
; -- and every one of those names was a bare global in 2024.  They are catalog
; entries now: `type` and `ffi` are de-registered as ambient namespaces (R5), so
; a consumer fetches its own references rather than assuming the platform left
; them lying around.
;
; ONE FILE, FETCHED ONCE.  Spreading prim-ref calls through the .scm files
; would put x-lang spellings into files that are otherwise Scheme, and would
; re-fetch on every load.  Here they are named once and the Scheme above stays
; Scheme -- which is also what makes the next platform rename a one-file edit
; instead of a search.

(provide r5rs/prims make-type make-instance type? obj-ref obj-set!)

; --- The type system ---------------------------------------------------------
; make-type takes a STRING name now; the 2024 callers passed a symbol
; ((lit VALUES)), which the current prim will not accept.  The wrapper converts,
; so the .scm files can keep either spelling.
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
