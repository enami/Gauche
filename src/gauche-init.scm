;;;
;;; gauche-init.scm - initialize standard environment
;;;
;;;  Copyright(C) 2000-2002 by Shiro Kawai (shiro@acm.org)
;;;
;;;  Permission to use, copy, modify, distribute this software and
;;;  accompanying documentation for any purpose is hereby granted,
;;;  provided that existing copyright notices are retained in all
;;;  copies and that this notice is included verbatim in all
;;;  distributions.
;;;  This software is provided as is, without express or implied
;;;  warranty.  In no circumstances the author(s) shall be liable
;;;  for any damages arising out of the use of this software.
;;;
;;;  $Id: gauche-init.scm,v 1.101 2002-12-13 13:17:55 shirok Exp $
;;;

(select-module gauche)

;;
;; Loading, require and provide
;;

;; Load path needs to be dealt with at the compile time.  this is a
;; hack to do so.   Don't modify *load-path* directly, since it causes
;; weird compiler-evaluator problem.
;; I don't like the current name "add-load-path", though---looks like
;; more a procedure than a compiler syntax---any ideas?
(define-macro (add-load-path path)
  `',(%add-load-path path))

;; Same as above.
(define-macro (require feature)
  `',(%require feature))

(define-macro (export-all)
  `',(%export-all))

;; Preferred way
;;  (use x.y.z) ==> (require "x/y/z") (import x.y.z)

(define (%module-name->path module)
  (let ((mod (cond ((symbol? module) module)
                   ((identifier? module) (identifier->symbol module))
                   (else (error "module name must be a symbol" module)))))
    ;; Here, there will be some module-name translator hook
    (string-join (%string-split-by-char (symbol->string mod) #\.) "/")))

(define-macro (use module)
  `(begin (with-module gauche (require ,(%module-name->path module)))
          (import ,module)))

(define-macro (extend . modules)
  `',(%extend (map (lambda (m)
                     (or (find-module m)
                         (begin
                           (%require (%module-name->path m))
                           (find-module m))
                         (error "undefined module" m)))
                   modules)))

;; Inter-version compatibility.
(define-macro (use-version version)
  (let ((compat (string-append "gauche/compat/" version)))
    (unless (provided? compat)
      (let ((path (string-append (gauche-library-directory) "/" compat ".scm")))
        (when (file-exists? path)
          (let ((module (string->symbol (string-append "gauche-" version))))
            `(begin
               (require ,compat)
               (import ,module))))))))

;; create built-in srfi-6 and srfi-8 modules, so that (use srfi-6)
;; won't complain.
(define-module srfi-6 )
(define-module srfi-8 )
(define-module srfi-10 )
(define-module srfi-17 )

;;
;; Autoload
;;

(define-macro (autoload file . vars)
  (define (bad)
    (error "bad autoload spec" (list* 'autoload file vars)))
  (define (macrodef? v)
    (and (pair? v) (eq? (car v) :macro) (symbol? (cadr v))))
  (receive (path module)
      (cond ((string? file) (values file #f))
            ((symbol? file)
             (values (string-join (%string-split-by-char (symbol->string file) #\.) "/")
                     file))
            (else (bad)))
    `(begin ,@(map (lambda (v)
                     (cond ((symbol? v)
                            `(define ,v (%make-autoload ',v ,path ',module)))
                           ((macrodef? v)
                            `(define-macro ,(cadr v)
                               ,(%make-autoload (cadr v) path module)))
                           (else (bad))))
                   vars))))

;; special macro to define autoload in Scheme module.
(define-macro (%autoload-scheme file . vars)
  `(begin
     ,@(map (lambda (v)
              `(define-in-module scheme ,v (%make-autoload ',v ,file)))
            vars)))

;;
;; Auxiliary definitions
;;

(define-in-module scheme call/cc call-with-current-continuation)

;; 
(define-in-module scheme (call-with-values producer consumer)
  (receive vals (producer) (apply consumer vals)))

(%autoload-scheme "gauche/listutil"
                  caaar caadr cadar caddr cdaar cdadr cddar cdddr
                  caaaar caaadr caadar caaddr cadaar cadadr caddar cadddr
                  cdaaar cdaadr cdadar cdaddr cddaar cddadr cdddar cddddr)

(%autoload-scheme "gauche/with"
                  call-with-input-file call-with-output-file
                  with-input-from-file with-output-to-file)

(autoload "gauche/with"
          with-output-to-string call-with-output-string
          with-input-from-string call-with-input-string
          with-string-io call-with-string-io
          write-to-string read-from-string)

(autoload "gauche/signal"
          (:macro with-signal-handlers))

(autoload gauche.portutil
          port->string port->list port->string-list port->sexp-list
          copy-port port-fold port-fold-right port-for-each port-map 
          port-position-prefix port-tell)

(%autoload-scheme "gauche/numerical"
                  exp log sqrt expt cos sin tan asin acos atan
                  gcd lcm numerator denominator
                  real-part imag-part)

(autoload "gauche/numerical"
          sinh cosh tanh asinh acosh atanh)

(autoload "gauche/logical"
          logtest logbit? copy-bit bit-field copy-bit-field logcount
          integer-length)

(autoload "gauche/common-macros"
          (:macro syntax-error) (:macro syntax-errorf) unwrap-syntax
          (:macro push!) (:macro pop!) (:macro inc!) (:macro dec!) (:macro update!)
          (:macro let1) (:macro begin0)
          (:macro dotimes) (:macro dolist) (:macro while) (:macro until))

(autoload gauche.regexp
          (:macro rxmatch-let) (:macro rxmatch-if)
          (:macro rxmatch-cond) (:macro rxmatch-case)
          regexp-replace regexp-replace-all regexp-quote)

(autoload gauche.procedure
          compose pa$ map$ for-each$ apply$ any-pred every-pred
          (:macro let-optionals*) (:macro let-keywords*)
          (:macro get-optional)
          arity procedure-arity-includes?
          <arity-at-least> arity-at-least? arity-at-least-value)

(autoload gauche.vm.debugger
          enable-debug disable-debug (:macro debug-print))

(autoload srfi-0 (:macro cond-expand))
(autoload srfi-26 (:macro cut) (:macro cute))
(autoload srfi-31 (:macro rec))

(autoload gauche.interpolate string-interpolate)

(define-reader-ctor 'string-interpolate
  (lambda (s) (string-interpolate s))) ;;lambda is required to delay loading

(autoload gauche.auxsys
          fmod frexp modf ldexp
          sys-abort sys-mkfifo
          sys-setgid sys-setpgid sys-getpgid sys-getpgrp
          sys-setsid sys-setuid sys-times sys-uname sys-ctermid
          sys-gethostname sys-getdomainname sys-putenv
          sys-gettimeofday sys-chown sys-utime
          sys-getgroups sys-getlogin sys-localeconv)

(autoload gauche.defvalues
          (:macro define-values) (:macro set!-values))

(autoload gauche.stringutil string-split)

;; these are so useful that I couldn't resist to add...
(define (file-exists? path)
  (sys-access path |F_OK|))
(define (file-is-regular? path)
  (and (sys-access path |F_OK|)
       (eq? (slot-ref (sys-stat path) 'type) 'regular)))
(define (file-is-directory? path)
  (and (sys-access path |F_OK|)
       (eq? (slot-ref (sys-stat path) 'type) 'directory)))

;; useful stuff
(define-syntax check-arg
  (syntax-rules ()
    ((_ test arg)
     (let ((tmp arg))
       (unless (test tmp)
         (errorf "bad type of argument for ~s: ~s" 'arg tmp))))
    ))

(define-syntax get-keyword*
  (syntax-rules ()
    ((_ key lis default)
     (let ((li lis))
       (let loop ((l li))
         (cond ((null? l) default)
               ((null? (cdr l)) (error "keyword list not even" li))
               ((eq? key (car l)) (cadr l))
               (else (loop (cddr l)))))))
    ((_ key lis) (get-keyword key lis))))

;; hash table iterators
(define (hash-table-map hash proc)
  (check-arg hash-table? hash)
  (let loop ((r '())
             (i (%hash-table-iter hash)))
    (receive (k v) (i)
      (if (eof-object? k)
          r
          (loop (cons (proc k v) r) i)))))

(define (hash-table-for-each hash proc)
  (check-arg hash-table? hash)
  (let loop ((i (%hash-table-iter hash)))
    (receive (k v) (i)
      (unless (eof-object? k)
        (proc k v) (loop i)))))

;; srfi-17
(define (getter-with-setter get set)
  (let ((proc (lambda x (apply get x))))
    (set! (setter proc) set)
    proc))

;; print (from SCM, Chicken)
(define (print . args)
  (for-each display args) (newline))

;; system object accessors (for backward compatibility)
(define (sys-stat->file-type s)  (slot-ref s 'type))
(define (sys-stat->mode s)  (slot-ref s 'mode))
(define (sys-stat->ino s)   (slot-ref s 'ino))
(define (sys-stat->dev s)   (slot-ref s 'dev))
(define (sys-stat->rdev s)  (slot-ref s 'rdev))
(define (sys-stat->nlink s) (slot-ref s 'nlink))
(define (sys-stat->size s)  (slot-ref s 'size))
(define (sys-stat->uid s)   (slot-ref s 'uid))
(define (sys-stat->gid s)   (slot-ref s 'gid))
(define (sys-stat->atime s) (slot-ref s 'atime))
(define (sys-stat->mtime s) (slot-ref s 'mtime))
(define (sys-stat->ctime s) (slot-ref s 'ctime))
(define (sys-stat->type s)  (slot-ref s 'type))

(define (sys-tm->alist tm)
  (map (lambda (n s) (cons n (slot-ref tm s)))
       '(tm_sec tm_min tm_hour tm_mday tm_mon tm_year tm_wday tm_yday tm_isdst)
       '(sec min hour mday mon year wday yday isdst)))

;;
;; Load object system
;;

(require "gauche/object")

;;
;; For convenience
;;

(let ((dotfile (sys-normalize-pathname "~/.gaucherc" :expand #t)))
  (when (sys-access dotfile |F_OK|)
    (load dotfile)))
