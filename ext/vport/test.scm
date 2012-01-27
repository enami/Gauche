;;
;; testing vport
;;

(use gauche.test)

(test-start "vport")
(use gauche.vport)
(use gauche.uvector)
(use gauche.sequence)
(use srfi-1)
(use srfi-13)
(use file.util)
(test-module 'gauche.vport)

;;-----------------------------------------------------------
(test-section "virtual-input-port")

(test* "vanilla" (make-list 8 #t)
       (let ((p (make <virtual-input-port>)))
         (list (eof-object? (read-byte p))
               (eof-object? (read-char p))
               (eof-object? (read-line p))
               (eof-object? (read-block 10 p))
               (byte-ready? p)
               (char-ready? p)
               (eof-object? (peek-byte p))
               (eof-object? (peek-char p)))))

(test* "getc" '(#\a #\a #\a 97 97 97 #*"aaaaaaaaaa")
       (let* ((p (make <virtual-input-port> :getc (lambda () #\a)))
              (c0 (read-char p))
              (c1 (read-char p))
              (c2 (read-char p))
              (b0 (read-byte p))
              (b1 (read-byte p))
              (b2 (read-byte p))
              (s  (read-block 10 p)))
         (list c0 c1 c2 b0 b1 b2 s)))

(test* "getb" '(#\a #\a #\a 97 97 97 #*"aaaaaaaaaa")
       (let* ((p (make <virtual-input-port> :getb (lambda () 97)))
              (c0 (read-char p))
              (c1 (read-char p))
              (c2 (read-char p))
              (b0 (read-byte p))
              (b1 (read-byte p))
              (b2 (read-byte p))
              (s  (read-block 10 p)))
         (list c0 c1 c2 b0 b1 b2 s)))

(test* "peekc/peekb & getc" '(#\a #\a 98 #\b)
       (let* ((x '(#\a #\b #\c))
              (p (make <virtual-input-port>
                   :getc (lambda ()
                           (and (pair? x) (pop! x)))))
              (c0 (peek-char p))
              (c1 (read-char p))
              (c2 (peek-byte p))
              (c3 (read-char p))
              )
         (list c0 c1 c2 c3)))

(test* "peekc/peekb & getb" '(97 #\a #\b 98)
       (let* ((x '(97 98 99))
              (p (make <virtual-input-port>
                   :getb (lambda ()
                           (and (pair? x) (pop! x)))))
              (c0 (peek-byte p))
              (c1 (read-char p))
              (c2 (peek-char p))
              (c3 (read-byte p)))
         (list c0 c1 c2 c3)))

(test* "getc -> read-line" "abcd"
       (let* ((x '(#\a #\b #\c #\d))
              (p (make <virtual-input-port>
                   :getc (lambda ()
                           (and (pair? x) (pop! x))))))
         (read-line p)))

(test* "getc -> read-line" '("abcd" "efg")
       (let* ((x '(#\a #\b #\c #\d #\newline #\e #\f #\g #\newline))
              (p (make <virtual-input-port>
                   :getc (lambda ()
                           (and (pair? x) (pop! x))))))
         (port->string-list p)))
         
(test* "getb -> read-line" '("abcd" "efg")
       (let* ((x '(97 98 99 100 10 101 102 103 10))
              (p (make <virtual-input-port>
                   :getb (lambda ()
                           (and (pair? x) (pop! x))))))
         (port->string-list p)))

(test* "getc -> read-block" #*"abcd\ne"
       (let* ((x '(#\a #\b #\c #\d #\newline #\e #\f #\g #\newline))
              (p (make <virtual-input-port>
                   :getc (lambda ()
                           (and (pair? x) (pop! x))))))
         (read-block 6 p)))

(test* "getc -> read-block" #*"abcd\nefg\n"
       (let* ((x '(#\a #\b #\c #\d #\newline #\e #\f #\g #\newline))
              (p (make <virtual-input-port>
                   :getc (lambda ()
                           (and (pair? x) (pop! x))))))
         (read-block 200 p)))

(test* "getb -> read-block" #*"abcd\ne"
       (let* ((x '(97 98 99 100 10 101 102 103 10))
              (p (make <virtual-input-port>
                   :getb (lambda ()
                           (and (pair? x) (pop! x))))))
         (read-block 6 p)))

(test* "getb -> read-block" #*"abcd\nefg\n"
       (let* ((x '(97 98 99 100 10 101 102 103 10))
              (p (make <virtual-input-port>
                   :getb (lambda ()
                           (and (pair? x) (pop! x))))))
         (read-block 200 p)))

(test* "gets -> read-block" #*"this is fr"
       (let* ((buf "this is from gets")
              (p (make <virtual-input-port>
                   :getc (lambda () #f)
                   :getb (lambda () #f)
                   :gets (lambda (length)
                           (if (< length (string-size buf))
                             (substring buf 0 length)
                             buf)))))
         (read-block 10 p)))

;;-----------------------------------------------------------
(test-section "virtual-output-port")

(test* "putc" "abcdef"
       (call-with-output-string
         (lambda (o)
           (let* ((p (make <virtual-output-port>
                       :putc (lambda (c) (write-char c o)))))
             (write-char #\a p)
             (display "bcd" p)
             (write-byte 101 p)
             (write-char #\f p)
             (get-output-string o)))))

(test* "putb" "abcdef"
       (call-with-output-string
         (lambda (o)
           (let* ((p (make <virtual-output-port>
                       :putb (lambda (b) (write-byte b o)))))
             (write-char #\a p)
             (display "bcd" p)
             (write-byte 101 p)
             (write-char #\f p)
             (get-output-string o)))))

(test* "puts" "bcdxyz"
       (call-with-output-string
         (lambda (o)
           (let* ((p (make <virtual-output-port>
                       :putb (lambda (b) #f)
                       :putc (lambda (c) #f)
                       :puts (lambda (s) (display s o)))))
             (write-char #\a p)
             (display "bcd" p)
             (write-byte 101 p)
             (write-char #\f p)
             (display "xyz" p)
             (get-output-string o)))))

;;-----------------------------------------------------------
(test-section "buffered-input-port")

(let ()
  (define (test-biport file size)
    (let* ((ifile #`",(sys-dirname (current-load-path))/,file")
           (src (open-input-file ifile))
           (p (apply make <buffered-input-port>
                     :fill  (lambda (buf) (read-block! buf src))
                     :close (lambda () (close-input-port src))
                     (if size
                       (list :buffer-size size)
                       '())))
           (a (file->string-list ifile))
           (b (port->string-list p)))
      (close-input-port p)
      (list (equal? a b) (port-closed? src))))

  (test* "vport.c" '(#t #t) (test-biport "vport.c" #f))
  (test* "vport.h" '(#t #t) (test-biport "vport.h" #f))

  (test* "vport.c (bufsize=100)"
         '(#t #t) (test-biport "vport.c" 100))
  (test* "vport.h (bufsize=100)"
         '(#t #t) (test-biport "vport.h" 100))
  (test* "vport.c (bufsize=65536)"
         '(#t #t) (test-biport "vport.c" 65536))
  (test* "vport.h (bufsize=65536)"
         '(#t #t) (test-biport "vport.h" 65536))
  (test* "vport.c (bufsize=1)"
         '(#t #t) (test-biport "vport.c" 1))
  (test* "vport.c (bufsize=0)"
         '(#t #t) (test-biport "vport.c" 0))
  )

;; test with no seeker; pointed in WiLiKi:Gauche:Bugs
(let ()
  (define in
    (let1 index 0
      (make <buffered-input-port>
        :fill (lambda (buf)
                (for-each-with-index
                 (lambda (i _)
                   (u8vector-set! buf i (logand (+ index i) #xFF)))
                 buf)
                (let ((size (u8vector-length buf)))
                  (inc! index size)
                  size))
        )))
  (test* "buffered-input-port w/o seeker"
         '(0 1 #f 2)
         (let* ([a (read-byte in)]
                [b (read-byte in)]
                [s (port-seek in 5 SEEK_SET)] ;this shouldn't move the point
                [c (read-byte in)])
           (list a b s c)))
  )

;;-----------------------------------------------------------
(test-section "buffered-output-port")

(let ()
  (define (test-boport file size)
    (let* ((ifile #`",(sys-dirname (current-load-path))/,file")
           (src  (file->string ifile))
           (sink (open-output-string))
           (closed? #f)
           (p (apply make <buffered-output-port>
                     :flush (lambda (buf force?)
                              (write-block buf sink)
                              (u8vector-length buf))
                     :close (lambda () (set! closed? #t))
                     (if size
                       (list :buffer-size size)
                       '()))))
      (string-for-each (lambda (c) (write-char c p)) src)
      (close-output-port p)
      (list (equal? src (get-output-string sink))
            closed?)))
  
  (test* "vport.c"      '(#t #t) (test-boport "vport.c" #f))
  (test* "vport.h" '(#t #t) (test-boport "vport.h" #f))

  (test* "vport.c (bufsize=100)"
         '(#t #t) (test-boport "vport.c" 100))
  (test* "vport.h (bufsize=100)"
         '(#t #t) (test-boport "vport.h" 100))
  (test* "vport.c (bufsize=65536)"
         '(#t #t) (test-boport "vport.c" 65536))
  (test* "vport.h (bufsize=65536)"
         '(#t #t) (test-boport "vport.h" 65536))
  (test* "vport.c (bufsize=1)"
         '(#t #t) (test-boport "vport.c" 1))
  (test* "vport.c (bufsize=0)"
         '(#t #t) (test-boport "vport.c" 0))
  )

;;-----------------------------------------------------------
(test-section "uvector-input-port")

(let ()
  (define (tester size)
    (test* #`"size=,size" #t
           (let1 v (make-u8vector size 0)
             (dotimes (i size) (u8vector-set! v i (modulo i 256)))
             (let* ((p (open-input-uvector v))
                    (d (with-output-to-string
                         (lambda ()
                           (let loop ((b (read-byte p)))
                             (unless (eof-object? b)
                               (write-byte b)
                               (loop (read-byte p))))))))
               (equal? v (string->u8vector d))))))
  (tester 0)
  (tester 10)
  (tester 16385))

(let* ((size 1024)
       (v (make-u8vector size 0)))
  (dotimes (i size) (u8vector-set! v i (modulo i 256)))
  (let1 p (open-input-uvector v)
    (test* "port-seek (SEEK_SET)" (+ 128 256)
           (port-seek p (+ 128 256) SEEK_SET))
    (test* "read after seek" 128
           (read-byte p))
    (test* "port-seek (SEEK_CUR)" (+ 127 256)
           (port-seek p -2 SEEK_CUR))
    (test* "read after seek" 127
           (read-byte p))
    (test* "port-seek (SEEK_END)" (- size 5)
           (port-seek p -5 SEEK_END))
    (test* "read after seek" (- 256 5)
           (read-byte p))
    (test* "port-seek (oob)" #t
           (begin (port-seek p 10 SEEK_END)
                  (eof-object? (read-byte p))))
    ))

;;-----------------------------------------------------------
(test-section "uvector-output-port")

(let ()
  (define (tester size)
    (test* #`"size=,size" #t
           (let1 v (make-u8vector size 0)
             (dotimes (i size) (u8vector-set! v i (modulo i 256)))
             (let* ((dst (make-u8vector size 0))
                    (p (open-output-uvector dst)))
               (dotimes (i size)
                 (write-byte (u8vector-ref v i) p))
               (close-output-port p)
               (equal? v dst)))))
  (tester 0)
  (tester 10)
  (tester 16385))

(let* ((v (make-u8vector 16 0)))
  (let1 p (open-output-uvector v)
    (test* "port-seek (SEEK_SET)" 3 (port-seek p 3 SEEK_SET))
    (test* "write after seek" '#u8(0 0 0 #xff 0 0 0 0 0 0 0 0 0 0 0 0 )
           (begin (write-byte #xff p) (flush p) (u8vector-copy v)))
    (test* "port-seek (SEEK_CUR)" 8 (port-seek p 4 SEEK_CUR))
    (test* "write after seek" '#u8(0 0 0 #xff 0 0 0 0 #x77 0 0 0 0 0 0 0 )
           (begin (write-byte #x77 p) (flush p) (u8vector-copy v)))
    (test* "port-seek (SEEK_END)" 15 (port-seek p -1 SEEK_END))
    (test* "write after seek" '#u8(0 0 0 #xff 0 0 0 0 #x77 0 0 0 0 0 0 #x11)
           (begin (write-byte #x11 p) (flush p) (u8vector-copy v)))
    ))

;;-----------------------------------------------------------
(test-section "input-limited-length-port")

(let ()
  (define (tester size limit)
    (test* #`"size=,size limit=,limit" #t
           (let* ((source (string-tabulate
                           (lambda (i) (integer->char (modulo i 128)))
                           size))
                  (expected (if (<= limit size)
                              (string-take source limit)
                              source))
                  (sp (open-input-string source))
                  (p (open-input-limited-length-port sp limit))
                  (result (port->string p)))
             (equal? expected result))))

  (tester 10 0)
  (tester 10 1)
  (tester 10 5)
  (tester 10 9)
  (tester 10 10)
  (tester 10 15)
  
  (tester 20000 19999)
  (tester 20000 20000)
  (tester 20000 20001)
  
  (tester 0  0)
  (tester 0  1)
  (tester 0  10)
  )

(test-end)
