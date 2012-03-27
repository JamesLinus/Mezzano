(in-package #:sys.int)

(defvar *print-array* t)
(defvar *print-base* 10)
(defvar *print-case* :upcase)
(defvar *print-circle* nil)
(defvar *print-escape* t)
(defvar *print-gensym* t)
(defvar *print-length* nil)
(defvar *print-level* nil)
(defvar *print-lines* nil)
(defvar *print-miser-width* nil)
(defvar *print-pprint-dispatch* nil)
(defvar *print-pretty* nil)
(defvar *print-radix* nil)
(defvar *print-readably* nil)
(defvar *print-right-margin* nil)

(defvar *print-safe* nil)
(defvar *print-space-char-ansi* nil)

(defun write-unsigned-integer (x base stream)
  (unless (= x 0)
    (write-unsigned-integer (truncate x base) base stream)
    (write-char (schar "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                       (rem x base))
                stream)))

(defun write-integer (x &optional (base 10) stream)
  (cond ((= x 0)
         (write-char #\0 stream))
        ((< x 0)
         (write-char #\- stream)
         (write-unsigned-integer (- 0 x) base stream))
        (t (write-unsigned-integer x base stream))))

(defun terpri (&optional stream)
  (write-char #\Newline stream))

(defun fresh-line (&optional stream)
  (unless (start-line-p stream)
    (terpri stream)))

(defun write-string (string &optional stream)
  (dotimes (i (length string))
    (write-char (char string i) stream)))

(defun write-object (object stream)
  (typecase object
    (integer
     (when *print-radix*
       (case *print-base*
         (2 (write-string "#b" stream))
         (8 (write-string "#o" stream))
         (10) ; Nothing.
         (16 (write-string "#x" stream))
         (t (write-char #\# stream)
            (write-integer *print-base* 10 stream)
            (write-char #\r stream))))
     (write-integer object *print-base* stream)
     (when (and *print-radix* (eql *print-base* 10))
       (write-char #\. stream)))
    (cons
     (write-char #\( stream)
     (write (car object) :stream stream)
     (do ((i (cdr object) (cdr i)))
         ((atom i)
          (when i
            (write-string " . " stream)
            (write i :stream stream))
          (write-char #\) stream))
       (write-char #\Space stream)
       (write (car i) :stream stream)))
    (symbol
     (cond ((or *print-escape* *print-readably*)
            (cond ((null (symbol-package object))
                   (when *print-gensym*
                     (write-string "#:" stream)))
                  ((keywordp object)
                   (write-char #\: stream))
                  (t (multiple-value-bind (symbol status)
                         (find-symbol (symbol-name object) *package*)
                       (unless (and status (eql symbol object))
                         ;; Not accessible in the current package.
                         (multiple-value-bind (symbol status)
                             (find-symbol (symbol-name object) (symbol-package object))
                           (write-string (package-name (symbol-package object)) stream)
                           (write-char #\: stream)
                           (when (not (eql status :external))
                             (write-char #\: stream)))))))
            (write-string (symbol-name object) stream))
           (t (write-string (symbol-name object) stream))))
    (string
     (cond ((or *print-escape* *print-readably*)
            (write-char #\" stream)
            (dotimes (i (length object))
              (let ((c (char object i)))
                (case c
                  (#\\ (write-char #\\ stream) (write-char #\\ stream))
                  (#\" (write-char #\\ stream) (write-char #\" stream))
                  (t (write-char c stream)))))
            (write-char #\" stream))
           (t (write-string object stream))))
    (character
     (cond ((or *print-readably* *print-escape*)
            (write-char #\# stream)
            (write-char #\\ stream)
            (cond ((and (or *print-space-char-ansi* (not (eql object #\Space)))
                        (not (eql object #\Newline))
                        (standard-char-p object))
                   (write-char object stream))
                  (t (write-string (char-name object)))))
           (t (write-char object stream))))
    (function
     (print-unreadable-object (object stream :type t :identity t)
       (write (function-name object) :stream stream)))
    (vector
     (write-char #\# stream)
     (write-char #\( stream)
     (dotimes (i (length object))
       (unless (zerop i)
         (write-char #\Space stream))
       (write (aref object i) :stream stream))
     (write-char #\) stream))
    (t (if *print-safe*
           (print-unreadable-object (object stream :type t :identity t))
           (print-object object stream))))
  object)

(defun write (object &key (stream t) (base *print-base*) (escape *print-escape*) (readably *print-readably*) &allow-other-keys)
  (let ((*print-base* base)
        (*print-escape* escape)
        (*print-readably* readably))
    (write-object object stream)))

(defmacro print-unreadable-object ((object stream &rest keys &key type identity) &body body)
  `(%print-unreadable-object ,(when body `(lambda () (progn ,@body))) ,object ,stream ,@keys))

(defun %print-unreadable-object (fn object stream &key type identity)
  (write-char #\# stream)
  (write-char #\< stream)
  (when type
    (write (type-of object) :stream (make-case-correcting-stream stream :titlecase)))
  (when fn
    (when type
      (write-char #\Space stream))
    (funcall fn))
  (when identity
    (when (or type fn)
      (write-char #\Space stream))
    (write-integer (sys.int::lisp-object-address object) 16))
  (write-char #\>))
