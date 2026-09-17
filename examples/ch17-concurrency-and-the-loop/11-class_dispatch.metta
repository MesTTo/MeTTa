; Purpose: inheritance is a head pattern. A method on a base class is one
;   equation over $self; a subclass that defines the same name adds an equation
;   over its own constructor; and super().describe() is the base's qualified
;   spelling, Shape-describe. The Python twin declares Shape, Circle and Square
;   with `@m.define`; here their rows are written by hand, each class in its
;   own space, a subclass referencing its base, and the base referencing the
;   public heads its subclasses contribute, which is how a call on the base's
;   $self reaches the subclass's equation.

!(add-atom &Shape (: Shape Type))
!(add-atom &Shape (= (Shape-describe $shape) (area-of (area $shape))))

!(add-atom &Circle (: Circle (-> Number Circle)))
!(add-atom &Circle (:< Circle Shape))
!(add-atom &Circle (from &Shape))
!(add-atom &Circle (= (Circle-area (Circle $r)) (* 3 (* $r $r))))
;Circle overrides describe and calls super().describe(), the base's equation.
!(add-atom &Circle (= (Circle-describe (Circle $r)) (circle (Shape-describe (Circle $r)))))
;The public heads dispatch on the receiver's constructor: one equation per
;defining class, MeTTa's own multiple dispatch.
!(add-atom &Circle (= (area (Circle $r)) (Circle-area (Circle $r))))
!(add-atom &Circle (= (describe (Circle $r)) (Circle-describe (Circle $r))))

!(add-atom &Square (: Square (-> Number Square)))
!(add-atom &Square (:< Square Shape))
!(add-atom &Square (from &Shape))
!(add-atom &Square (= (Square-area (Square $s)) (* $s $s)))
!(add-atom &Square (= (area (Square $s)) (Square-area (Square $s))))
!(add-atom &Square (= (describe (Square $s)) (Shape-describe (Square $s))))

;The base reads the public heads its subclasses contribute.
!(add-atom &Shape (from &Circle (only (area describe))))
!(add-atom &Shape (from &Square (only (area describe))))

!(add-atom &self (from &Shape))
!(add-atom &self (from &Circle))
!(add-atom &self (from &Square))

!(test (area (Circle 2)) 12)
!(test (area (Square 3)) 9)
!(test (describe (Square 3)) (area-of 9))
!(test (describe (Circle 2)) (circle (area-of 12)))
;isinstance is get-type with the :< edges: a Circle is a Circle and a Shape.
!(test (collapse (get-type (Circle 2))) (quote (Circle Shape)))
!(test (collapse (match &Circle (:< Circle $base) $base)) (Shape))
