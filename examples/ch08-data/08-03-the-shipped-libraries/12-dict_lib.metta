;lib_dict: a dictionary IS a space of (key value) atoms, so every operation
;below is a write or a match and a dict is queryable with everything any
;other space has. That is the decision, taken because it costs no new type:
;a lookup is a match and "all of them" is the language's own answer set.
!(import! &self (library lib_dict))

;`dict-space` from lib_json builds one, and the operations here are what a
;dict needs past a decoded document.
!(bind! &prices (dict-space ((apple 3) (pear 5))))

;`dict-size` is the space's atom count and `dict-has` is a match reduced to
;a Bool.
!(test (dict-size &prices) 2)
!(test (dict-has &prices apple) True)
!(test (dict-has &prices durian) False)

;`dict-values` answers one value per key, which is nondeterminism rather than
;a list; `dict-pairs` is the whole thing collapsed, the shape `dict-space`
;reads back.
!(test (sort-atom (collapse (dict-values &prices))) (3 5))
!(test (sort-atom (dict-pairs &prices)) ((apple 3) (pear 5)))

;`dict-put` WRITES. It answers the same dict it was given, because a space is
;a handle and there is nothing else to answer; the key it puts is the key it
;replaces, so a dict stays a map rather than becoming a relation.
!(test (dict-size (dict-put &prices plum 7)) 3)
!(test (dict-size &prices) 3)
!(test (collapse (match &prices (plum $v) $v)) (7))

;Putting a key that is there is a replacement, written as a remove and an
;add, so the old pair is gone rather than shadowed.
!(test (dict-size (dict-put &prices apple 9)) 3)
!(test (collapse (match &prices (apple $v) $v)) (9))

;`dict-remove` takes a key out and answers the dict; removing a key that is
;not there is an ordinary answer rather than a failure, which is what the
;collapse inside it is for.
!(test (dict-size (dict-remove &prices pear)) 2)
!(test (dict-has &prices pear) False)
!(test (dict-size (dict-remove &prices durian)) 2)

;`dict-remove-pair` is the step under that one: it finds the key's pair as a
;VALUE and removes exactly it, answering the removal's own verdict per pair
;removed. `dict-remove` is this with the answers collapsed away.
!(test (collapse (dict-remove-pair &prices apple)) (True))
!(test (dict-has &prices apple) False)
!(test (collapse (dict-remove-pair &prices apple)) ())

;And because it is a space all along, the dict answers a pattern query no
;dictionary API would offer: which key holds a given value.
!(bind! &stock (dict-space ((apple 12) (pear 12) (plum 4))))
!(test (sort-atom (collapse (match &stock ($k 12) $k))) (apple pear))

;`dict-get` answers a value where `dict-values` and `get-value` answer nothing:
;a lookup that has to produce something takes the default with it.
!(test (dict-get &stock apple 0) 12)
!(test (dict-get &stock durian 0) 0)

;`dict-update` applies a function to the value that is there and puts the
;result back, so a read, a call and a write are one operation. An absent key
;leaves the dict alone, because there is no value to apply the function to.
!(test (dict-get (dict-update &stock plum (|-> ($v) (+ $v 6))) plum 0) 10)
!(test (dict-get (dict-update &stock durian (|-> ($v) (+ $v 6))) durian absent) absent)

;`dict-merge` puts every pair of the second dict into the first, so the
;second's value wins on a key they share.
!(bind! &delivery (dict-space ((pear 20) (fig 2))))
!(test (sort-atom (dict-pairs (dict-merge &stock &delivery)))
       ((apple 12) (fig 2) (pear 20) (plum 10)))

;`dict-pop` reads and removes in one operation. An absent key has no answer,
;which is what tells it apart from a stored value.
!(test (dict-pop &stock fig) 2)
!(test (dict-has &stock fig) False)
!(test (collapse (dict-pop &stock fig)) ())
