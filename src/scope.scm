(load "mk.scm")
(load "matche.scm")
(load "pmatch.scm")
(load "test-check.scm")

(define occurs-free?
  (lambda (x e)
    (pmatch e
      (,y (guard (symbol? y))
       (eq? x y))
      ((lambda (,y) ,body)
       (cond
         ((eq? x y) #f)
         (else (occurs-free? x body))))
      ((,e1 ,e2)
       (or (occurs-free? x e1)
           (occurs-free? x e2))))))

(define occurs-bound?
  (lambda (x e)
    (pmatch e
      (,y (guard (symbol? y))
       #f)
      ((lambda (,y) ,body)
       (cond
         ((eq? x y)
          (or (occurs-free? x body)
              (occurs-bound? x body)))
         (else (occurs-bound? x body))))
      ((,e1 ,e2)
       (or (occurs-bound? x e1)
           (occurs-bound? x e2))))))

(test "occurs-free?-0"
  (occurs-free? 'z 'z)
  #t)

(test "occurs-free?-1"
  (occurs-free? 'z '(lambda (z) (lambda (z) z)))
  #f)

(test "occurs-bound?-0"
  (occurs-bound? 'z 'z)
  #f)

(test "occurs-bound?-1"
  (occurs-bound? 'z '(lambda (z) (lambda (z) z)))
  #t)

;;; careful here--my code doesn't know about 'let' or '+'
(test "shadowing-1"
  (let ((x 3))
    (let ((y 4))
      (+ x y)))
  7)

(test "shadowing-2"
  (let ((x 3))
    (let ((y 4))
      (let ((x 5))
        (+ x y))))
  9)

(test "lexical-scope-1"
  (let ((x 5))
    (let ((f (lambda (y) (+ x y))))
      (let ((x 6))
        (f x))))
  11)

;; avoiding overlapping answers in the application case is the tricky
;; part, and requires the 'not-occurs-freeo' helper relation.
(define occurs-freeo
  (lambda (x e)
    (fresh ()
      (symbolo x)
      (matche e
        (,y (symbolo y)
         (== x y))
        ((lambda (,y) ,body)
         (=/= x y)
         (occurs-freeo x body))
        ((,e1 ,e2)
         (conde
           ((occurs-freeo x e1))
           ((not-occurs-freeo x e1)
            (occurs-freeo x e2))))))))

(define not-occurs-freeo
  (lambda (x e)
    (fresh ()
      (symbolo x)
      (matche e
        (,y (symbolo y)
         (=/= x y))
        ((lambda (,y) ,body)
         (conde
           ((== x y))
           ((=/= x y)
            (not-occurs-freeo x body))))
        ((,e1 ,e2)
         (not-occurs-freeo x e1)
         (not-occurs-freeo x e2))))))



(define occurs-boundo
  (lambda (x e)
    (fresh ()
      (symbolo x)
      (matche e
        ((lambda (,y) ,body)
         (conde
           ((=/= x y)
            (occurs-boundo x body))
           ((== x y)
            (conde
              ((occurs-freeo x body))
              ((not-occurs-freeo x body)
               (occurs-boundo x body))))))
        ((,e1 ,e2)
         (conde
           ((occurs-boundo x e1))
           ((not-occurs-boundo x e1)
            (occurs-boundo x e2))))))))

(define not-occurs-boundo
  (lambda (x e)
    (fresh ()
      (symbolo x)
      (matche e
        (,y (symbolo y))
        ((lambda (,y) ,body)
         (conde
           ((=/= x y)
            (not-occurs-boundo x body))
           ((== x y)
            (not-occurs-freeo x body)
            (not-occurs-boundo x body))))
        ((,e1 ,e2)
         (not-occurs-boundo x e1)
         (not-occurs-boundo x e2))))))



(test "occurs-freeo-0"
  (run* (q) (occurs-freeo 'z 'z))
  '(_.0))

(test "occurs-freeo-1"
  (run* (q) (occurs-freeo 'z '(lambda (z) (lambda (z) z))))
  '())

(test "occurs-freeo-2"
  (run 10 (q) (occurs-freeo 'z q))
  '(z
    ((lambda (_.0) z) (=/= ((_.0 z))))
    (z _.0)
    ((lambda (_.0) (lambda (_.1) z)) (=/= ((_.0 z)) ((_.1 z))))
    ((lambda (_.0) (z _.1)) (=/= ((_.0 z))))
    ((_.0 z) (=/= ((_.0 z))) (sym _.0))
    (((lambda (_.0) z) _.1) (=/= ((_.0 z))))
    ((lambda (_.0) (lambda (_.1) (lambda (_.2) z))) (=/= ((_.0 z)) ((_.1 z)) ((_.2 z))))
    ((z _.0) _.1)
    ((lambda (_.0) (lambda (_.1) (z _.2))) (=/= ((_.0 z)) ((_.1 z))))))



(define answer-contains-constraints?
  (letrec ((memq*
            (lambda (x y)
              (cond
                ((null? y) #f)
                ((pair? y) (or (memq* x (car y)) (memq* x (cdr y))))
                ((eq? x y) #t)
                (else #f)))))
    (lambda (ans)
      (and (list? ans)
           (or (memq* '=/= ans)
               (memq* 'sym ans)
               (memq* 'num ans)
               (memq* 'absento ans))))))


(test "occurs-freeo-3"
  (for-all
   (lambda (e)
     (let ((e (if (answer-contains-constraints? e) (car e) e)))
       (occurs-free? 'z e)))
   (run 100 (q) (occurs-freeo 'z q)))
  #t)

(test "occurs-freeo-10"
  (run* (q) (occurs-freeo 'a '(a b)))
  '(_.0))

(test "occurs-freeo-9"
  (run* (q) (occurs-freeo 'a '(b a)))
  '(_.0))

(test "occurs-freeo-8"
  (run* (q) (occurs-freeo 'a '(((lambda (z) (v (w z))) w) a)))
  '(_.0))

(test "occurs-freeo-7"
  (run* (q) (occurs-freeo 'a '(a ((lambda (z) (v (w z))) w))))
  '(_.0))

(test "occurs-freeo-6"
  (run* (q) (occurs-freeo 'a '(lambda (w) (a ((lambda (z) (v (w z))) w)))))
  '(_.0))

(test "occurs-freeo-5"
  (run* (q) (occurs-freeo 'a '(lambda (w) (((lambda (z) (v (w z))) w) a))))
  '(_.0))

(test "occurs-freeo-4"
  (run* (q) (occurs-freeo q '(lambda (w) (((lambda (z) (v (w z))) w) a))))
  '(v a))

(test "occurs-freeo-11"
  (run 5 (q) (fresh (x e) (occurs-freeo x e) (== `(,x ,e) q)))
  '(((_.0 _.0) (sym _.0))
    ((_.0 (lambda (_.1) _.0)) (=/= ((_.0 _.1))) (sym _.0))
    ((_.0 (_.0 _.1)) (sym _.0))
    ((_.0 (lambda (_.1) (lambda (_.2) _.0))) (=/= ((_.0 _.1)) ((_.0 _.2))) (sym _.0))
    ((_.0 (lambda (_.1) (_.0 _.2))) (=/= ((_.0 _.1))) (sym _.0))))


(test "occurs-boundo-0"
  (run* (q) (occurs-boundo 'z 'z))
  '())

(test "occurs-boundo-1"
  (run* (q) (occurs-boundo 'z '(lambda (z) (lambda (z) z))))
  '(_.0))

(test "occurs-boundo-2"
  (run* (q) (occurs-boundo q '(lambda (w) (((lambda (z) (v (w z))) w) a))))
  '(w z))

(test "occurs-boundo-3"
  (run 10 (q) (occurs-boundo 'z q))
  '((lambda (z) z)
    ((lambda (z) (lambda (_.0) z)) (=/= ((_.0 z))))
    ((lambda (_.0) (lambda (z) z)) (=/= ((_.0 z))))
    ((lambda (z) z) _.0)
    (lambda (z) (z _.0))
    ((lambda (z) (lambda (_.0) (lambda (_.1) z))) (=/= ((_.0 z)) ((_.1 z))))
    (lambda (z) (lambda (z) z))
    ((_.0 (lambda (z) z)) (sym _.0))
    ((lambda (z) (lambda (_.0) (z _.1))) (=/= ((_.0 z))))
    ((lambda (z) (_.0 z)) (=/= ((_.0 z))) (sym _.0))))

(test "occurs-boundo-4"
  (for-all
   (lambda (e)
     (let ((e (if (answer-contains-constraints? e) (car e) e)))
       (occurs-bound? 'z e)))
   (run 100 (q) (occurs-boundo 'z q)))
  #t)

(test "occurs-boundo-5"
  (run 5 (q) (fresh (x e) (occurs-boundo x e) (== `(,x ,e) q)))
  '(((_.0 (lambda (_.0) _.0)) (sym _.0))
    ((_.0 (lambda (_.0) (lambda (_.1) _.0))) (=/= ((_.0 _.1))) (sym _.0))
    ((_.0 (lambda (_.1) (lambda (_.0) _.0))) (=/= ((_.0 _.1))) (sym _.0))
    ((_.0 ((lambda (_.0) _.0) _.1)) (sym _.0))
    ((_.0 (lambda (_.0) (_.0 _.1))) (sym _.0))))



(define union
  (lambda (s1 s2)
    (cond
      ((null? s1)
       s2)
      ((memv (car s1) s2)
       (union (cdr s1) s2))
      (else
       (cons (car s1) (union (cdr s1) s2))))))

(test "union-1"
  (union '() '())
  '())

(test "union-2"
  (union '(a b c) '())
  '(a b c))

(test "union-3"
  (union '() '(a b c))
  '(a b c))

(test "union-4"
  (union '(a b c) '(d e f))
  '(a b c d e f))

(test "union-5"
  (union '(a) '(a))
  '(a))

(test "union-6"
  (union '(a b c d) '(c a d e))
  '(b c a d e))


(define free
  (lambda (e)
    (letrec ((free
              (lambda (e bound-vars)
                (pmatch e
                  (,x (guard (symbol? x))
                      (if (memv x bound-vars)
                          '()
                          `(,x)))
                  ((lambda (,x) ,body)
                   (free body `(,x . ,bound-vars)))
                  ((,e1 ,e2)
                   (union (free e1 bound-vars)
                          (free e2 bound-vars)))))))
      (free e '()))))

(test "free-1"
  (free '(lambda (w) (((lambda (z) (v (w z))) w) a)))
  '(v a))

(define bound
  (lambda (e)
    (letrec ((bound
              (lambda (e bound-vars)
                (pmatch e
                  (,x (guard (symbol? x))
                      (if (memv x bound-vars)
                          `(,x)
                          '()))
                  ((lambda (,x) ,body)
                   (bound body `(,x . ,bound-vars)))
                  ((,e1 ,e2)
                   (union (bound e1 bound-vars)
                          (bound e2 bound-vars)))))))
      (bound e '()))))

(test "bound-1"
  (bound '(lambda (w) (((lambda (z) (v (w z))) w) a)))
  '(z w))


(define membero
  (lambda (x ls)
    (matche ls
      ((,y . ,rest)
       (conde
         ((== x y))
         ((=/= x y)
          (membero x rest)))))))

(test "membero-1"
  (run* (q) (membero 'x '()))
  '())

(test "membero-2"
  (run* (q) (membero 'x '(x)))
  '(_.0))

(test "membero-3"
  (run* (q) (membero 'x '(x x)))
  '(_.0))

(test "membero-4"
  (run* (q) (membero 'x '(y z)))
  '())

(test "membero-5"
  (run* (q) (membero q '(y z)))
  '(y z))


;; really should be replaced with set constraints
(define uniono
  (lambda (s1 s2 out)
    (matche s1
      (()
       (== s2 out))
      ((,a . ,rest)
       (conde
         ((membero a s2)
          (uniono rest s2 out))
         ((fresh (res)
            (== `(,a . ,res) out)
            (absento a s2)
            (uniono rest s2 res))))))))

(test "uniono-1"
  (run* (q) (uniono '() '() q))
  '(()))

(test "uniono-2"
  (run* (q) (uniono '(a b c) '() q))
  '((a b c)))

(test "uniono-3"
  (run* (q) (uniono '() '(a b c) q))
  '((a b c)))

(test "uniono-4"
  (run* (q) (uniono '(a b c) '(d e f) q))
  '((a b c d e f)))

(test "uniono-5"
  (run* (q) (uniono '(a) '(a) q))
  '((a)))

(test "uniono-6"
  (run* (q) (uniono '(a b c d) '(c a d e) q))
  '((b c a d e)))



;; Really need set constraints to do this right The absento is too
;; heavy-weight, uniono doesn't work very well, membero should be set
;; membership...
(define freeo
  (lambda (e out)
    (letrec ((freeo
              (lambda (e bound-vars out)
                (matche e
                  (,x (symbolo x)
                      (conde
                        ((== `(,x) out)
                         (absento x bound-vars))
                        ((== '() out)
                         (membero x bound-vars))))
                  ((lambda (,x) ,body)
                   (freeo body `(,x . ,bound-vars) out))
                  ((,e1 ,e2)
                   (fresh (res1 res2)
                     (freeo e1 bound-vars res1)
                     (freeo e2 bound-vars res2)
                     (uniono res1 res2 out)))))))
      (freeo e '() out))))

(test "freeo-1"
  (run* (q) (freeo '(lambda (w) (((lambda (z) (v (w z))) w) a)) q))
  '((v a)))

(define boundo
  (lambda (e out)
    (letrec ((boundo
              (lambda (e bound-vars out)
                (matche e
                  (,x (symbolo x)
                      (conde
                        ((== '() out)
                         (absento x bound-vars))
                        ((== `(,x) out)
                         (membero x bound-vars))))
                  ((lambda (,x) ,body)
                   (boundo body `(,x . ,bound-vars) out))
                  ((,e1 ,e2)
                   (fresh (res1 res2)
                     (boundo e1 bound-vars res1)
                     (boundo e2 bound-vars res2)
                     (uniono res1 res2 out)))))))
      (boundo e '() out))))

(test "boundo-1"
  (run* (q) (boundo '(lambda (w) (((lambda (z) (v (w z))) w) a)) q))
  '((z w)))