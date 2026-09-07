;Five doors the builtin library opens straight onto SWI's own term
;operations, spelled the way Prolog spells them. They are here because the
;reference corelib registers them and this engine answers to the same names;
;the hyphenated MeTTa vocabulary above covers most of what they do, and these
;are the cases where it does not.
;
;`atom_chars` takes a name or a string apart into its characters, as an
;expression of one-character symbols. The number 123 goes through the same
;door, because a number has a written form too.
!(test (atom_chars abc) (a b c))
!(test (atom_chars "abc") (a b c))
!(test (size-atom (atom_chars 123)) 3)
;The characters are SYMBOLS, one character each, so the answer for 123 is not
;the three numbers the same source text would read as.
!(test (== (atom_chars 123) (1 2 3)) False)
!(test (atom_concat (car-atom (atom_chars abc)) bc) abc)

;`atom_concat` joins two written forms and answers a SYMBOL, whatever the
;operands were: a string in, a name out.
!(test (atom_concat ab cd) abcd)
!(test (atom_concat "ab" cd) abcd)
!(test (atom_concat ab 1) ab1)
;Which is a real difference and not a spelling: the answer is the NAME
;abcd, so it is not the string of the same characters.
!(test (== (atom_concat "ab" "cd") "abcd") False)

;`copy_term` answers the same structure with FRESH variables. Sharing
;survives the copy, which is the whole point: the two positions of a repeated
;variable stay one variable, they are just no longer the caller's.
!(test (=alpha (copy_term (foo $x $y)) (foo $a $b)) True)
!(test (let ($p $q) (copy_term ($x $x)) (=? $p $q)) True)
!(test (let ($p $q) (copy_term ($x $y)) (== $p $q)) False)

;`term_hash` is a number that depends only on the term's written structure,
;so equal terms hash equal and different terms almost never do.
!(test (== (term_hash (foo 1)) (term_hash (foo 1))) True)
!(test (== (term_hash (foo 1)) (term_hash (foo 2))) False)
!(test (== (+ 0 (term_hash (foo 1))) (term_hash (foo 1))) True)

;It is defined for GROUND terms only. A term with a variable in it leaves the
;answer unbound rather than inventing a number, because a hash that varied
;with a variable's name would break the one property a hash is for.
!(test (is-ground (foo 1)) True)
!(test (is-ground (foo $x)) False)
!(test (let $h (term_hash (foo $x)) (is-var $h)) True)

;`pretty-atom` is the writer, answering the atom's source text as a String.
;It renames variables to the engine's own numbering, so two alpha-equivalent
;atoms print the same, which `repr` above does not promise.
!(test (pretty-atom (noeval (= (f 1) (+ 1 1)))) "(= (f 1) (+ 1 1))")
!(test (== (pretty-atom (noeval (f $x)))
           (pretty-atom (noeval (f $y))))
       True)
!(test (pretty-atom 1) "1")
