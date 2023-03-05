#lang racket

(require test-engine/racket-tests)

(struct bin (op fst snd) #:transparent) ; op is a symbol; fst, snd are ASTs.

(struct fun (param body) #:transparent) ; param is a symbol; body is an AST.

(struct app (fn arg) #:transparent) ; fn and arg are ASTs.

(struct ifzero (t tb fb) #:transparent)

(struct rec (nm nmd body) #:transparent)

;; An AST is a (union bin fun app).

(struct sub (name val) #:transparent)

;; A substitution is a (sub n v), where n is a symbol and v is a value.
;; An environment (env) is a list of substitutions.

(struct closure (var body envt) #:transparent #:mutable)

;; A closure is a (closure v bdy env), where
;; v is a symbol, bdy is an AST, and env is a environment.
;; A value is a (union number closure).

;; parse: sexp -> AST

(define (parse sx)
  (match sx
    [`(with ((,nm ,nmd)) ,bdy) (app (fun nm (parse bdy)) (parse nmd))]
    [`(rec ((,x ,E)) ,B) (rec x (parse E) (parse B))]
    [`(ifzero ,x ,y ,z) (ifzero (parse x) (parse y) (parse z))]
    [`(+ ,x ,y) (bin '+ (parse x) (parse y))]
    [`(* ,x ,y) (bin '* (parse x) (parse y))]
    [`(- ,x ,y) (bin '- (parse x) (parse y))]
    [`(/ ,x ,y) (bin '/ (parse x) (parse y))]
    [`(fun (,x) ,bdy) (fun x (parse bdy))]
    [`(,f ,x) (app (parse f) (parse x))]
    [x x]))

; op-trans: symbol -> (number number -> number)
; converts symbolic representation of arithmetic function to actual Racket function
(define (op-trans op)
  (match op
    ['+ +]
    ['* *]
    ['- -]
    ['/ /]))



;; lookup: symbol env -> value
;; looks up a substitution in an environment (topmost one)

(define (lookup var env)
  (cond
    [(empty? env) (error 'interp "unbound variable ~a" var)]
    [(symbol=? var (sub-name (first env))) (sub-val (first env))]
    [else (lookup var (rest env))]))

;; interp: AST env -> value

(define (interp ast-temp env-temp)
  (define ast
    (if (box? ast-temp) (closure-envt (unbox ast-temp)) ast-temp))
  (define env
    (if (box? env-temp) (closure-envt (unbox env-temp)) env-temp))
  (match ast
    [(fun v bdy) (closure v bdy env)]
    [(rec exp-name arg-exp fun-exp)
       (match (interp (fun exp-name fun-exp) env)
         [(closure v bdy cl-env)
          (match (interp arg-exp env)
            [(closure v2 bdy2 f)
             (define d (box (closure empty empty empty)))
             (set-box! d (closure v2 bdy2 'undefined))
             (set-box! d (closure v2 bdy2 (cons (sub v d) f)))
             (interp bdy d)]
            [else (interp bdy (cons (sub v (interp arg-exp env)) cl-env))])])]
    [(app fun-exp arg-exp)
       (match (if (box? (interp fun-exp env)) (unbox (interp fun-exp env)) (interp fun-exp env))
         [(closure v bdy cl-env)
          (interp bdy (cons (sub v (interp arg-exp env)) cl-env))])]
    [(bin op x y)
       ((op-trans op) (interp x env) (interp y env))]
    [(ifzero x y z) (if (zero? (interp x env)) (interp y env) (interp z env))]
    [x (if (number? x)
           x
           (lookup x env))]))