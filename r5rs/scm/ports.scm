; --- Ports (R5RS §6.6) ---
;
; A REWRITE, not a port.  The 2024 version of this file was 249 lines of
; hand-rolled FFI: dlopen/dlsym against libc, ptr-call for open/close/read, and
; obj-make to build a raw BUFFER object -- plus a hand-walked map of the base
; object's internal tree to find the file table.  obj-make no longer exists at
; all, not renamed but removed, and the rest are catalog entries now with a
; different calling convention.
;
; None of that comes back.  The platform ships `File` (x/sys/file), which does
; open/close/read/write/getc as syscalls with a collector that knows about the
; buffers, and that is what this drives.  Nothing here reaches into the base
; object's layout, so nothing here breaks when that layout moves again.
;
; AND THE DIALECT DOES NOT MOVE.  The old note here predicted that restoring
; ports would take the bundle from (dialect xe) to rn, because dlopen is a
; radon opt-in.  That was true of the dlopen implementation and is not true of
; this one: r5rs/base.x reaches File with an explicit (import x/sys/file), and
; a dialect decides what is PRELOADED rather than what is reachable.  Measured
; both ways with ports loaded -- 667/16 under xe, 667/16 under rn.

; --- The EOF object -------------------------------------------------------
;
; A fresh pair, so `eq?` identifies it and no ordinary value can be mistaken
; for it.  R5RS requires eof-object? to be false for every other datum, which
; rules out reusing '() or #f or -1 -- all three are things a port might
; legitimately yield.
(define %eof-object (cons '%eof '()))
(define (eof-object? x) (eq? x %eof-object))

; --- Ports ----------------------------------------------------------------
;
; (list '%port DIR FD) -- DIR is 'input or 'output, FD the descriptor.
;
; A list rather than a record because the predicates have to answer #f for
; ANY non-port without erroring: (input-port? 42) and (input-port? '()) are
; both ordinary questions in R5RS, so the test is pair? first and tag second.
; The fourth slot is a one-element box holding either '%unread or the list of
; forms still to be handed out by `read`.  It is what makes repeated reads on
; one port return successive data rather than re-parsing from the top.
(define (%make-port dir fd) (list '%port dir fd (list '%unread)))
(define (%port? p) (and (pair? p) (eq? (car p) '%port)))
(define (%port-dir p) (car (cdr p)))
(define (%port-fd p) (car (cdr (cdr p))))
(define (%port-box p) (car (cdr (cdr (cdr p)))))

(define (input-port? p) (and (%port? p) (eq? (%port-dir p) 'input)))
(define (output-port? p) (and (%port? p) (eq? (%port-dir p) 'output)))

; The standard descriptors, wrapped once.  current-input-port and
; current-output-port are procedures per R5RS, not variables.
(define %stdin-port (%make-port 'input 0))
(define %stdout-port (%make-port 'output 1))
(define (current-input-port) %stdin-port)
(define (current-output-port) %stdout-port)

; --- Opening and closing --------------------------------------------------
;
; File open answers a negative fd on error rather than raising, so the check
; is here: a port holding -2 would fail later and somewhere else.
(define (open-input-file path)
  (let ((fd (File open path 'rdonly)))
    (if (< fd 0)
      (error "open-input-file: cannot open" path)
      (%make-port 'input fd))))

(define (open-output-file path)
  (let ((fd (File open path (list 'wronly 'creat 'trunc))))
    (if (< fd 0)
      (error "open-output-file: cannot open" path)
      (%make-port 'output fd))))

(define (close-input-port p) (File close (%port-fd p)))
(define (close-output-port p) (File close (%port-fd p)))

; --- Reading --------------------------------------------------------------
;
; File getc answers the byte as a CHAR, or the integer -1 at EOF.  The test is
; char? rather than (= c -1): comparing a char to an integer with = is a type
; error, and the two returns are already distinguishable by type.
(define (read-char . rest)
  (let ((p (if (null? rest) (current-input-port) (car rest))))
    (let ((c (File getc (%port-fd p))))
      (if (char? c) c %eof-object))))

; `read` parses the WHOLE remaining port on first use and hands the forms out
; one at a time.  The alternative is reading character by character until a
; datum closes, which means re-implementing the reader's bracket matching in
; Scheme; the platform already has (tok read-str), and it takes text.
;
; The cost is honest and worth stating: a port is drained on the first read,
; so `read` cannot be interleaved with `read-char` on the same port, and an
; unterminated form at the end is dropped rather than reported.
(define %token-read-string (prim-ref 'tok 'read-str))

(define (%port-slurp-chars p acc)
  (let ((c (File getc (%port-fd p))))
    (if (char? c)
      (%port-slurp-chars p (cons c acc))
      (reverse acc))))

; The trailing space is required, not cosmetic: read-str drops an
; unterminated tail, so a file ending in a bare symbol loses its last token
; without one.
(define (%port-slurp-forms p)
  (let ((chars (%port-slurp-chars p '())))
    (if (null? chars)
      '()
      (%token-read-string (%base)
        (string-append (list->string chars) " ")))))

(define (read . rest)
  (let ((p (if (null? rest) (current-input-port) (car rest))))
    (let ((box (%port-box p)))
      (do
        (if (eq? (car box) '%unread)
          (set-car! box (%port-slurp-forms p))
          '())
        (let ((forms (car box)))
          (if (null? forms)
            %eof-object
            (do (set-car! box (cdr forms)) (car forms))))))))

; char-ready? on a regular file is always true -- a read will not block.  This
; is the honest answer for the ports this file can open; a terminal or a
; socket would need select, and neither is openable from here yet.
(define (char-ready? . rest) #t)

; --- Output sink ----------------------------------------------------------
;
; NOTHING HERE SHADOWS display OR write.  The platform's printer emits through
; a swappable box -- (first %print-sink) is a fn of one string -- so
; redirection and transcription are the same mechanism the printer already
; uses for (io display-to-str).  Shadowing the verbs instead would mean
; re-implementing every renderer they reach.
;
; Two boxes, consulted per emit rather than baked into a closure, so
; transcript-on can start recording in the middle of a redirect that is
; already running.
(define %out-fd (list 1))
(define %tr-fd (list #f))

(define (%emit-str s)
  (do
    (File write (car %out-fd) s (string-length s))
    (if (car %tr-fd)
      (File write (car %tr-fd) s (string-length s))
      '())))

; Installed lazily and removed again, so an ordinary program's output takes
; the platform's own path and this file costs nothing until something asks
; for a redirect or a transcript.
(define %sink-saved (list #f))

(define (%sink-install!)
  (if (car %sink-saved)
    '()
    (do
      (set-car! %sink-saved (first %print-sink))
      (%set-first! %print-sink (fn (_ s) (%emit-str s))))))

(define (%sink-restore!)
  (if (car %sink-saved)
    (do
      (%set-first! %print-sink (car %sink-saved))
      (set-car! %sink-saved #f))
    '()))

; --- The file-calling procedures ------------------------------------------
(define (call-with-input-file path proc)
  (let ((p (open-input-file path)))
    (let ((r (proc p)))
      (do (close-input-port p) r))))

(define (call-with-output-file path proc)
  (let ((p (open-output-file path)))
    (let ((r (proc p)))
      (do (close-output-port p) r))))

(define (with-input-from-file path thunk)
  (call-with-input-file path (lambda (p) (thunk))))

; The redirect is a saved-and-restored fd, not a saved-and-restored sink: the
; transcript may be installed underneath and must survive this returning.
(define (with-output-to-file path thunk)
  (let ((p (open-output-file path)))
    (let ((saved (car %out-fd)))
      (do
        (%sink-install!)
        (set-car! %out-fd (%port-fd p))
        (let ((r (thunk)))
          (do
            (set-car! %out-fd saved)
            (if (car %tr-fd) '() (%sink-restore!))
            (close-output-port p)
            r))))))

; --- Transcript -----------------------------------------------------------
(define (transcript-on path)
  (let ((fd (File open path (list 'wronly 'creat 'trunc))))
    (if (< fd 0)
      (error "transcript-on: cannot open" path)
      (do (%sink-install!) (set-car! %tr-fd fd)))))

(define (transcript-off)
  (if (car %tr-fd)
    (do
      (File close (car %tr-fd))
      (set-car! %tr-fd #f)
      (%sink-restore!))
    '()))

; --- load -----------------------------------------------------------------
;
; Reads the file whole and evaluates each form in the current environment.
; File read-all rather than a getc loop: the reader wants the text, and the
; platform already has the one-syscall-per-file version of this.
(define (%load-eval-each forms)
  (if (null? forms)
    '()
    (do (eval (car forms)) (%load-eval-each (cdr forms)))))

(define (load path)
  (let ((p (open-input-file path)))
    (let ((forms (%port-slurp-forms p)))
      (do (close-input-port p) (%load-eval-each forms)))))
