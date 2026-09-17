; Purpose: a class that inherits the seat's Space type is a prototype: each
;   instance is a knowledge base of its own, a handle around a space whose
;   facts are the instance's fields and whose equations are its private rules.
;   A method reads the instance through the receiver it is handed, never
;   through &self, which names the equation's defining home. The Python twin
;   declares `class Agent(Space)`; here its rows are written by hand.

!(add-atom &Agent (: Agent (-> SpaceType Agent)))
!(add-atom &Agent (internal _field-mood))
!(add-atom &Agent
  (= (Agent-mood (Agent $space)) (match $space (_field-mood $mood) $mood)))
!(add-atom &Agent
  (= (make-Agent $mood)
     (let $space (new-space)
       (progn
         (add-atom $space (from &Agent))
         (add-atom $space (_field-mood $mood))
         (Agent $space)))))
;decide is one equation over the receiver: two agents answer differently
;because their spaces hold different facts. The public head dispatches on
;the receiver's constructor.
!(add-atom &Agent
  (= (Agent-decide (Agent $space)) (act-on (Agent-mood (Agent $space)))))
!(add-atom &Agent (= (decide (Agent $space)) (Agent-decide (Agent $space))))

!(add-atom &self (from &Agent))

!(bind! &calm (make-Agent calm))
!(bind! &alert (make-Agent alert))

!(test (decide &calm) (act-on calm))
!(test (decide &alert) (act-on alert))

;A rule private to one agent lives in its space and runs through evalc there;
;from any other space the same expression stays unreduced.
!(let (Agent $space) &calm
   (add-atom $space (= (private-rule $agent) (secret (Agent-mood $agent)))))
!(test (let (Agent $space) &calm (evalc (private-rule &calm) $space)) (secret calm))
!(test (== (private-rule &calm) (quote (private-rule &calm))) True)

;A subclass's space references the class's, so it shares the equations and
;overrides decide with an equation over its own constructor.
!(add-atom &Scout (: Scout (-> SpaceType Scout)))
!(add-atom &Scout (:< Scout Agent))
!(add-atom &Scout (from &Agent))
!(add-atom &Scout
  (= (make-Scout $mood)
     (let $space (new-space)
       (progn
         (add-atom $space (from &Scout))
         (add-atom $space (_field-mood $mood))
         (Scout $space)))))
!(add-atom &Scout
  (= (Scout-decide (Scout $space)) (scouting (Agent-mood (Agent $space)))))
!(add-atom &Scout (= (decide (Scout $space)) (Scout-decide (Scout $space))))
!(add-atom &self (from &Scout))
!(bind! &scout (make-Scout curious))
!(test (decide &scout) (scouting curious))
