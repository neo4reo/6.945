(define (infix? exp) (tagged-list? exp 'infix))

(define (infix-exp exp) (cadr exp))

(define (analyze-infix exp)
  (analyze (infix->scheme (infix-exp exp))))

(defhandler analyze analyze-infix infix?)

(define (string->expr string)
  (define operators (list #\+ #\- #\* #\/ #\^))
  (define (add-spaces stuff)
    ;; add spaces around operators
    (if (null? stuff)
        '()
        (if (memq (car stuff) operators)
            (append (list #\space (car stuff) #\space)
                    (add-spaces (cdr stuff)))
            (cons (car stuff) (add-spaces (cdr stuff))))))
  (let* ((stringlist (string->list string))
         (stringlist-in-parens
          (append (list #\() stringlist (list #\))))
         (spaced-stringlist (add-spaces stringlist-in-parens))
         (spaced-string (list->string spaced-stringlist)))
    (builtin-read (string->input-port spaced-string))))

(define (infix->scheme string)
  (define unary-operators (list
    ; associate infix operators to scheme procedures
                           (list '- '- 0)
                           (list '/ '/ 1)))

  (define infix-operators (list
    ; associate infix operators to scheme procedures
                           (list '+ '+)
                           (list '- '-)
                           (list '* '*)
                           (list '/ '/)
                           (list '^ 'expt)))

  (define functions
    (list (list 'sqrt 'sqrt)))

  (define precedence (list
                      (list '^ 4)
                      (list '* 3)
                      (list '/ 3)
                      (list '+ 2)
                      (list '- 2)))

  (define (lookup x alist)
    (let ((result (assq x alist)))
      (if result
          (cadr result)
          #f)))

  (define (precedence-of operator)
    (lookup operator precedence))

  (define (unary-operator-expr? expr)
    ;; e.g. (- 1)
    (and (pair? expr)
         (>= (length expr) 2)
         (assq (car expr) unary-operators)))

  (define (infix-operator-expr? expr)
    ;; e.g. (1 + 1)
    (and (pair? expr)
         (>= (length expr) 3)
         (assq (cadr expr) infix-operators)))

  (define (singleton? expr)
    (and (pair? expr)
	 (equal? (length expr) 1)))

  (define (convert-function-calls expr)
    ;;; e.g. (... sqrt (...) ...) -> (... (sqrt ...) ...)
    (if (null? expr)
	'()
	(if (and (assq (car expr) functions)
		 (>= (length expr) 2))
	    (let ((scheme-proc (lookup (first expr) functions)))
	      (cons (list scheme-proc (second expr))
		    (list-tail expr 2)))
	    (cons (car expr) (convert-function-calls (cdr expr))))))

  (define (convert-unary-expr expr)
    ;; convert (- 2) to (0 - 2) and (/ 2) to (1 / 2). 
    (if (null? expr)
	'()
	(let ((operator-triple (assq (first expr) unary-operators)))
	  (if operator-triple
	      (cons (third operator-triple) expr)
	      expr))))

  (define (add-parentheses-around n expr)
    (append (list-head expr (- n 1))
	    (list (sublist expr (- n 1) (+ n 2)))
	    (list-tail expr (+ n 2))))

  (define (insert-parentheses expr)
    (define (find-highest-precedence expr)
      (define (iter expr n highest n-of-highest)
	(if (null? expr)
	    n-of-highest
	    (let ((op-precedence (precedence-of (car expr))))
	      (if (and op-precedence (> op-precedence highest))
		  (iter (cdr expr) (+ n 1) op-precedence n)
		  (iter (cdr expr) (+ n 1) highest n-of-highest)))))
      (iter expr 0 0 0))
    (if (<= (length expr) 3)
	expr ; base case: all possible parens added
	(insert-parentheses 
	 (add-parentheses-around (find-highest-precedence expr)
				 expr))))

  (define (infix->prefix expr)
    (if (not (pair? expr))
	expr
	(if (and (equal? (length expr) 3)
		 (assq (second expr) infix-operators))
	    (list (lookup (second expr) infix-operators)
		  (infix->prefix (first expr))
		  (infix->prefix (third expr)))
	    expr)))

  (define (parse-infix expr)
    (if (not (pair? expr))
	expr
	(let ((result (infix->prefix
		       (insert-parentheses
			(convert-unary-expr
			 (convert-function-calls
			  (map parse-infix expr)))))))
	  (if (singleton? result)
	      (car result)
	      result))))

  (parse-infix (string->expr string)))

