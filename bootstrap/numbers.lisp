(in-package "SYSTEM.INTERNALS")

(defmacro define-commutative-arithmetic-operator (name base identity)
  `(progn (defun ,name (&rest numbers)
            (declare (dynamic-extent numbers))
            (let ((result ,identity))
              (dolist (n numbers)
                (setf result (,base result n)))
              result))
          (define-compiler-macro ,name (&rest numbers)
            (declare (dynamic-extent numbers))
            (cond ((null numbers) ',identity)
                  ((null (rest numbers))
                   `(the number ,(first numbers)))
                  (t (let ((result (first numbers)))
                       (dolist (n (rest numbers))
                         (setf result (list ',base result n)))
                       result))))))

(define-commutative-arithmetic-operator + binary-+ 0)
(define-commutative-arithmetic-operator * binary-* 1)
(define-commutative-arithmetic-operator logand binary-logand -1)
(define-commutative-arithmetic-operator logeqv binary-logeqv -1)
(define-commutative-arithmetic-operator logior binary-logior 0)
(define-commutative-arithmetic-operator logxor binary-logxor 0)

;;; - and / do not fit into the previous template, so have to be
;;; explicitly defined.

(defun - (number &rest more-numbers)
  (declare (dynamic-extent more-numbers))
  (cond (more-numbers
         (let ((result number))
           (dolist (n more-numbers)
             (setf result (binary-- result n)))
           result))
        (t (binary-- 0 number))))

(define-compiler-macro - (number &rest more-numbers)
  (declare (dynamic-extent more-numbers))
  (cond ((null more-numbers) `(binary-- 0 ,number))
        (t (let ((result number))
             (dolist (n more-numbers)
               (setf result `(binary-- ,result ,n)))
             result))))

(defun / (number &rest more-numbers)
  (declare (dynamic-extent more-numbers))
  (cond (more-numbers
         (let ((result number))
           (dolist (n more-numbers)
             (setf result (binary-/ result n)))
           result))
        (t (binary-/ 1 number))))

(define-compiler-macro / (number &rest more-numbers)
  (declare (dynamic-extent more-numbers))
  (cond ((null more-numbers) `(binary-/ 1 ,number))
        (t (let ((result number))
             (dolist (n more-numbers)
               (setf result `(binary-/ ,result ,n)))
             result))))

(defmacro define-comparison-operator (name base)
  `(progn (defun ,name (number &rest more-numbers)
            (declare (dynamic-extent more-numbers))
            (check-type number number)
            (dolist (n more-numbers t)
              (unless (,base number n)
                (return nil))
              (setf number n)))
          (define-compiler-macro ,name (&whole whole number &rest more-numbers)
            (declare (dynamic-extent more-numbers))
            (cond ((null more-numbers) 't)
                  ((null (rest more-numbers))
                   `(,',base ,number ,(first more-numbers)))
                  (t whole)))))

(define-comparison-operator < binary-<)
(define-comparison-operator <= binary-<=)
(define-comparison-operator > binary->)
(define-comparison-operator >= binary->=)
(define-comparison-operator = binary-=)

(defun min (number &rest more-numbers)
  (declare (dynamic-extent more-numbers))
  (check-type number number)
  (dolist (n more-numbers number)
    (when (< n number)
      (setf number n))))

(define-compiler-macro min (number &rest more-numbers)
  (cond
    ((null more-numbers)
     `(the number ,number))
    ((null (rest more-numbers))
     (let ((lhs (gensym))
           (rhs (gensym)))
       `(let ((,lhs ,number)
              (,rhs ,(first more-numbers)))
          (if (< ,lhs ,rhs)
              ,lhs
              ,rhs))))
    (t (let* ((n (gensym))
              (symbols (mapcar (lambda (x)
                                 (declare (ignore x))
                                 (gensym))
                               more-numbers)))
         `(let ,(cons (list n number)
                      (mapcar 'list symbols more-numbers))
            ,@(mapcar (lambda (sym)
                        `(when (< ,sym ,n)
                           (setf ,n ,sym)))
                      symbols)
            ,n)))))

(defun max (number &rest more-numbers)
  (declare (dynamic-extent more-numbers))
  (check-type number number)
  (dolist (n more-numbers number)
    (when (> n number)
      (setf number n))))

(define-compiler-macro max (number &rest more-numbers)
  (cond
    ((null more-numbers)
     `(the number ,number))
    ((null (rest more-numbers))
     (let ((lhs (gensym))
           (rhs (gensym)))
       `(let ((,lhs ,number)
              (,rhs ,(first more-numbers)))
          (if (> ,lhs ,rhs)
              ,lhs
              ,rhs))))
    (t (let* ((n (gensym))
              (symbols (mapcar (lambda (x)
                                 (declare (ignore x))
                                 (gensym))
                               more-numbers)))
         `(let ,(cons (list n number)
                      (mapcar 'list symbols more-numbers))
            ,@(mapcar (lambda (sym)
                        `(when (> ,sym ,n)
                           (setf ,n ,sym)))
                      symbols)
            ,n)))))
