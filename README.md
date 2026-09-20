<!--
Purpose: show what MeTTa is, how it is put together, and what each surface can
  do, through examples that run.
Guarantees: every python fence executes in a namespace of its own and every
  metta fence runs on the engine [tested: python -m pytest
  extensions/python/tests/repository/test_readme.py -q]; the ts and c fences are
  the text of files their own gates build and run.
-->

# MeTTa

MeTTa, Hyperon's AGI language, based on PeTTa semantics with significant
extensions.

**If you are an LLM, read [llms.txt](llms.txt)** for the language and every
surface, with exact return shapes and no prose to guess at.

```bash
sudo apt install swi-prolog          # macOS: brew install swi-prolog
                                     # Windows: winget install SWI-Prolog.SWI-Prolog
pip install 'PyMeTTa[engine]'        # Python
npm install tsmetta                  # TypeScript, brings its own engine
```

# Architecture

One engine, in Prolog and C. Everything else reaches it through a declared
seam, so each piece is built, versioned and published on its own.

| Component | Repository | What it is |
|---|---|---|
| the engine | `engine/` | translator, matcher, spaces, catalog, extension points, the C half |
| the libraries | [MeTTa-Library-Pack](https://github.com/MesTTo/MeTTa-Library-Pack) | 61 libraries, written in MeTTa over the primitives |
| the examples | [MeTTa-Examples](https://github.com/MesTTo/MeTTa-Examples) | 360 executable programs, the semantics documentation |
| Python | [PyMeTTa](https://github.com/MesTTo/PyMeTTa) | 104 root exports over 20 modules |
| integrations | [PyMeTTa-Extensions](https://github.com/MesTTo/PyMeTTa-Extensions) | 17 distributions, each registering one row |
| TypeScript | [TSMeTTa](https://github.com/MesTTo/TSMeTTa) | on a WebAssembly SWI-Prolog, in your Node process |
| C | [CMeTTa](https://github.com/MesTTo/CMeTTa) | a C program opens the engine in its own process |
| a storage backend | [MeTTa-MORK](https://github.com/MesTTo/MeTTa-MORK) | spaces on MORK's Rust trie |

## The four ways in

| To add | You | So that |
|---|---|---|
| a surface | speak the wire codec | Python, TypeScript and C are three consumers of one engine, not three engines |
| a backend | claim your space names and FAIL for the rest | the next provider's clause gets to answer |
| an integration | register a row against a declared point | the core names no third-party library at all |
| a library | write MeTTa over the primitives | it survives the engine being replaced |

## Extension points

`engine/ext_points.pl` declares every point in four kinds, and `clauses_from/2`
fixes who may contribute each.

```prolog
clauses_from(event,       extension).
clauses_from(ownership,   extension).
clauses_from(declaration, extension).
clauses_from(service,     engine).
```

A backend claims the names it owns and fails for the rest, which is the whole
protocol:

```prolog
seam:foreign_space('&catalogs').
seam:foreign_capability('&catalogs', match).
seam:foreign_capability('&catalogs', enumerate).
seam:foreign_atoms('&catalogs', Row) :- package_catalog_row(Row).
```

## The catalog

Everything the engine knows about itself is atoms you can query, including what
each library is and where it came from.

```metta
!(import! &self (library lib_package))
!(test (size-atom (collapse (match &catalogs (package $name $path) $name))) 61)
```

# The language

## Atoms

Four kinds, and that is the whole representation.

```metta
!(test (get-metatype Tom) Symbol)                   ; a name that denotes itself
!(test (get-metatype $x) Variable)                  ; stands for anything
!(test (get-metatype 42) Grounded)                  ; a number, a string, a host object
!(test (get-metatype (Parent Tom Bob)) Expression)  ; atoms in order
```

Terms read and print as themselves.

```metta
!(test (repr 42) "42")
!(test (repr "42") "\"42\"")
!(test (repr (A (B C))) "(A (B C))")
!(test (repr (A (, B , C ,))) "(A (, B , C ,))")
!(test (repr 2025_12_12) "2025_12_12")
!(test (repr ()) "()")
```

## Spaces and matching

A space is where a program lives, and `match` reads it.

```metta
(= (matchtrickery)
   (let* (($t1 (add-atom &self (foo a)))
          ($t2 (add-atom &self (foo b))))
         (match &self (foo $1) (bar $1))))

!(test (collapse (matchtrickery))
       ((bar a) (bar b)))
```

A pattern's head can be a constant, so the head is just another position.

```metta
(= (h (justdata haha $B) $C)
   (+ $B $C))

!(test (h (justdata haha 30) 40) 70)
```

## Equations

An equation is an atom, so partial application and composition fall out of the
same rule.

```metta
(= (mp) (+))

!(test (mp 1 1) 2)

(= (.. $f1 $f2 $arg) ($f1 ($f2 $arg)))

(= (plus1times2) (.. (* 2) (+ 1)))

!(test (plus1times2 1) 4)
```

## Many answers

Nondeterminism is the default, and `empty` is the answer with no answers.

```metta
(= (y) (empty))

!(test (collapse (y))
       ())
```

`once` commits to the first.

```metta
(foo 1)
(foo 2)

(= (match-single $space $pat $ret)
   (once (match $space $pat $ret)))

!(let $x (match-single &self (foo $1) $1) (add-atom &self (bar $x)))

!(test (collapse (match &self (bar $1) (bar $1)))
       ((bar 1)))
```

## Control flow

`if` takes a boolean and two branches.

```metta
!(test (if True 42) 42)
```

`case` dispatches on shape.

```metta
(= (casetest $x)
   (case $x ((4 42)
             ($otherpattern 44)
             ($otherother $45))))

!(test (casetest 5) 44)
```

`chain` sequences.

```metta
!(test (chain (+ 2 4) $n (* 3 $n))
       18)

!(test (chain (+ 1 3) $n (chain (* 2 $n) $m (+ $n $m)))
       12)
```

A cut commits to what has been found.

```metta
(foo 1)
(foo 2)

(= (match-single $space $pat $ret)
   (let* (($x (match $space $pat $ret))
          ($temp (cut)))
         $x))

!(let $x (match-single &self (foo $1) $1) (add-atom &self (bar $x)))

!(test (collapse (match &self (bar $1) (bar $1)))
       ((bar 1)))
```

Recursion under an explicit branch budget.

```metta
(= (fib $N)
   (if (< $N 2)
       $N
       (+ (fib (- $N 1))
          (fib (- $N 2)))))

!(test (with-pragma! ((max-stack-depth 100000000)) (fib 30)) 832040)
```

## Data

Multiset operations over atoms.

```metta
!(test (unique-atom (a b c d d)) (a b c d))
!(test (union-atom (a b b c) (b c c d)) (a b b c b c c d))
!(test (intersection-atom (a b c c) (b c c c d)) (b c c))
!(test (subtraction-atom (a b b c) (b c c d)) (a b))
!(test (intersection-atom (a b c c) (b c d)) (b c))
!(test (intersection-atom (a a a) (a)) (a))
!(test (subtraction-atom (a a a) (a)) (a a))
!(test (intersection-atom (a b) ()) ())
```

## Sequence variables

A pattern child that stands for a run of atoms.

```metta
!(test (collapse (let ((:seg $pre) SEP (:seg $post)) (a b SEP c SEP d)
                      (pair $pre $post)))
       ((pair (a b) (c SEP d)) (pair (a b SEP c) (d))))

!(test (let (row (:seg $r)) (row) $r) ())
!(test (let (row (:seg $r)) (row a b c) $r) (a b c))

!(test (get-metatype (let (row (:seg $r)) (row a b) $r)) Expression)
!(test (size-atom (let (row (:seg $r)) (row a b) $r)) 2)
!(test (car-atom (let (row (:seg $r)) (row a b) $r)) a)

!(test (let (f (:seg $x) g (:seg $x)) (f a b g a b) $x) (a b))
!(test (collapse (let (f (:seg $x) g (:seg $x)) (f a b g c) $x)) ())
!(test (let (f (:seg $x) g (:seg $x)) (f 1 g 1.0) took) took)

!(test (collapse (let (f ... g ...) (f a g b c) done)) (done))

!(test (let (f (g ...) b) (f (g 1 2) b) nested) nested)
!(test (collapse (let (A ... D) (A b c E) never)) ())

!(add-atom &self (edge a b))
!(add-atom &self (edge b c d))
!(add-atom &self (tag b hot))
!(test (collapse (match &self (edge a ... $last) $last)) (b))
!(test (collapse (match &self (, (edge ... $mid) (tag $mid $heat)) ($mid $heat)))
       ((b hot)))
```

## Numbers

```metta
!(test (exp-math 0) 1.0)
!(test (exp-math 1.0) 2.718281828459045)
!(test (< (abs-math (- (exp-math 2.0) (* 2.718281828459045 2.718281828459045))) 1.0e-12) true)
!(test (< (abs-math (- (log-math 2.718281828459045 (exp-math 3.0)) 3.0)) 1.0e-12) true)

(= (in-range $lo $hi $x) (and (<= $lo $x) (<= $x $hi)))
!(test (in-range 1 6 (random-int 1 6)) true)
!(test (in-range 0.0 1.0 (random-float 0.0 1.0)) true)
!(test (in-range 5 5 (random-int 5 5)) true)
```

## Python as a notation

```metta
!(test (repr (py-call (str true))) "True")
!(test (repr (py-call (str false))) "False")
!(test (py-call (sorted (true false))) (false true))
!(test (py-call (len (true false true))) 3)
!(test (py-call (isinstance true (py-call (type false)))) true)
!(test (py-call (bool 1)) true)
!(test (py-call (bool 0)) false)
!(test (py-call (.bit_length true)) 1)
!(test (repr (py-call (.upper abc))) "ABC")
```

## Types

Optional, and parametric.

```metta
(: apply (-> (-> $tx $ty) $tx $ty))
(= (apply $f $x) ($f $x))
!(apply not False) ; True
!(get-type (apply not False))
!(test (let (get-type apply) (-> (-> Bool Bool) Bool $result) $result)
       Bool)
```

## Errors and refusals

A refusal names what went wrong rather than failing silently.

```metta
!(test (throw (my-ball 1)) (Error (throw (my-ball 1)) (my-ball 1)))
!(test (throw "text") (Error (throw "text") "text"))

!(test (if-error (throw oops) caught fine) caught)
!(test (if-error 42 caught fine) fine)
!(test (return-on-error (throw oops) carried-on) (Error (throw oops) oops))
!(test (return-on-error 42 carried-on) carried-on)

!(test (throw (Error (inner 1) because)) (Error (inner 1) because))
!(test (throw (throw first)) (Error (throw first) first))

(= (half $n) (if (== (% $n 2) 0) (/ $n 2) (throw (odd $n))))
!(test (half 10) 5)
!(test (half 7) (Error (throw (odd 7)) (odd 7)))
!(test (if-error (half 7) refused (half 7)) refused)

!(test (trace! "the answer" 42) 42)
!(test (+ 1 (trace! "adding one to" 41)) 42)
!(test (trace! (half 10) (half 10)) 5)

!(test (trace! (checking (odd 7)) ok) ok)
```

## Testing

Every example checks itself, using the same forms you would.

```metta
!(import! &self (library lib_he))

(= (add 1 2) 3)

!(test (id 5) 5)

!(test (=alpha (Father $X) (Father $Y)) True)

!(test (=alpha (Father $X) (Son $X)) False)

!(test (if-equal 1 1 "Equal" "Not Equal") "Equal")
```

## Seeing your program

```metta
!(import! &self (library lib_string))

!(test (> (current-time) 1700000000.0) True)

!(test (<= (current-time) (current-time)) True)

!(test (format-time "abc") abc)
!(test (== (format-time "abc") "abc") False)
!(test (string-length (format-time "a literal")) 9)
!(test (string-length (format-time "")) 0)
!(test (string-length (format-time "%%")) 1)

!(test (string-length (format-time "%Y")) 4)
!(test (string-length (format-time "%Y-%m-%d")) 10)
!(test (string-length (format-time "%H:%M:%S")) 8)

!(test (collapse (argv 999)) ())
!(test (collapse (argv -1)) ())

!(test (== (argv 0) (argv 0)) True)

(= (argument-or $index $default)
   (let $found (collapse (argv $index))
        (if (== $found ()) $default (car-atom $found))))
!(test (argument-or 999 no-such-argument) no-such-argument)
!(test (== (argument-or 0 no-such-argument) no-such-argument) False)
```

## Events and standing queries

```metta
!(test (match &metta (vocabulary delivery $a $b $c) ($a $b $c))
       (at-most-once at-least-once per-write-exactly))
!(test (match &metta (vocabulary event-order $a $b) ($a $b))
       (ordered unordered))
!(test (match &metta (kind events $ctx $delivery $order) $delivery)
       (one-of delivery))

!(test (if-error (catch (add-atom &metta (events &feed eventually)))
                 refused admitted)
       refused)

!(add-atom &native-events (reading 1))
!(test (collapse (match &metta (events &native-events $d $o) declared)) ())

!(test (match &metta (vocabulary agenda-policy $a $b $c $d $e) ($a $b $c $d $e))
       (declaration recency specificity priority user))
!(test (match &metta (policy reaction-order $knob $default) ($knob $default))
       (agenda declaration))
!(test (match &metta (kind agenda $ctx $policy $fn) $policy)
       (one-of agenda-policy))

!(test (match &metta (kind on $ctx $pattern $op $priority) $priority)
       (optional integer))
```

## Concurrency

```metta
!(add-atom &Point (: Point (-> Number Number Point)))
!(add-atom &Point (= (Point-x (Point $x $y)) $x))
!(add-atom &Point (= (Point-y (Point $x $y)) $y))

!(add-atom &Point
  (= (Point-norm (Point $x $y)) (sqrt-math (+ (* $x $x) (* $y $y)))))

!(add-atom &Point
  (= (Point-add (Point $x1 $y1) (Point $x2 $y2)) (Point (+ $x1 $x2) (+ $y1 $y2))))

!(add-atom &Point
  (= (Point-quadrant $p)
     (case $p (((Point 0 0) origin) ((Point 0 $y) axis) ((Point $x $y) plane)))))

!(add-atom &self (from &Point))

!(test (Point-norm (Point 3 4)) 5.0)
!(test (Point-add (Point 1 2) (Point 3 4)) (Point 4 6))
!(test (Point-quadrant (Point 0 0)) origin)
!(test (Point-quadrant (Point 0 4)) axis)
!(test (Point-quadrant (Point 3 4)) plane)
!(test (== (Point-add (Point 1 2) (Point 3 4)) (Point 4 6)) True)
```

## Worlds and state

```metta
!(bind! state (new-state rest))
!(test (get-state state) rest)

!(test (change-state! state active) true)
!(test (get-state state) active)

!(test (get-type (new-state 5)) (StateMonad Number))
!(test (get-type (new-state "hi")) (StateMonad String))

!(test (let $cell (new-state 1)
            (let $_ (change-state! $cell 2) (get-state $cell)))
       2)
```

## Performance

Memoisation is a library, not a keyword.

```metta
!(import! &self (library lib_memo))

!(memoize sq)
(= (sq $x) (* $x $x))

!(test (sq 9) 81)
!(test (sq 9) 81)
!(test (sq 9) 81)
```

## Spaces backed by anything

A space of your own, inheriting what it does not answer.

```metta
!(add-atom &family-parent (edge a b))
!(add-atom &family-parent (parent-only kept))
!(add-atom &family-parent (layer parent))
!(new-space &family-child (inherits &family-parent))
!(add-atom &family-child (edge b c))
!(add-atom &family-child (child-only local))
!(add-atom &family-child (layer child))

!(test (collapse (match &family-child
                         (, (edge $x $y) (edge $y $z))
                         ($x $z)))
       ((a c)))

!(test (collapse (match &family-child (layer $x) $x)) (child parent))
!(test (space-atom-count &family-child) 3)

!(test (collapse (match &family-parent (parent-only $x) $x)) (kept))
!(test (collapse (match &family-child (parent-only $x) $x)) (kept))
!(test (collapse (match &family-parent (child-only $x) $x)) ())
```

Rows in a CSV file, queried as atoms.

```metta
!(import! &self (library lib_csv))
!(import! &self (library lib_file))

!(bind! &csv-path (temp-path! "metta-csv-example"))
!(write-file! &csv-path "id,amount\n001,12.50\n002,9\n002,9\n")
!(bind! &sales (csv-space &csv-path))

!(test (collapse (match &sales (row $id $amount) ($id $amount)))
       (("id" "amount") ("001" "12.50") ("002" "9") ("002" "9")))
!(test (match &sales (row "001" $amount) (parse-number $amount)) 12.5)

!(write-file! &csv-path "003,42\n")
!(test (collapse (match &sales (row $id $amount) ($id $amount)))
       (("003" "42")))
!(delete-file! &csv-path)
```

## A reasoner

```metta
(= (myf $M)
   (and (and (member a $M)
             (member b $M))
        (== (size-atom $M) 2)))

!(test (if (once (myf $M)) $M)
       (a b))
```

## Weighted answers

```metta
!(import! &self (library lib_pln))

(= (STV A) (stv 0.5 0.9))
(= (STV B) (stv 0.25 0.9))
(= (STV C) (stv 0.25 0.9))
(= (STV D) (stv 0.5 0.9))

(= (kb)
   ((Sentence ((Inheritance A B) (stv 0.25 0.9)) (1))
    (Sentence ((Inheritance A C) (stv 0.25 0.9)) (2))
    (Sentence ((Inheritance B D) (stv 0.5 0.9)) (3))
    (Sentence ((Inheritance C D) (stv 0.5 0.9)) (4))
   ))

!(test (with-pragma! ((max-stack-depth 100000000))
                     (PLN.Query (kb) (Inheritance A D)))
       ((stv 0.5 0.9473684210526316) (1 2 3 4)))
```

## Search

```metta
!(add-atom &self (= (fib $N)
                    (if (< $N 2)
                        $N
                        (+ (fib (- $N 1))
                           (fib (- $N 2))))))

!(test (with-pragma! ((max-stack-depth 100000000)) (fib 30)) 832040)
```

## Extending the engine

A translator rule changes what a form compiles to.

```metta
(= (runtime42 $arg)
   (cons 42 $arg))

(= (compileeval42 $arg)
   (cons 42 $arg))

(= (compile42 $arg)
   (noeval (cons 42 $arg)))

!(add-translator-rule! compileeval42)
!(add-translator-rule! compile42)

!(test (runtime42 (43)) (42 43))
!(test (compileeval42 (43)) (42 43))
!(test (compile42 (43)) (42 43))
```

Prolog underneath, when you want it.

```metta
!(test (progn (translatePredicate (is $x 2))
              (translatePredicate (+ $x 40 $z)) $z)
       42)
```

MeTTa's own evaluator, written in MeTTa.

```metta
(: myinterpreter (-> Atom %Undefined%))
(= (myinterpreter $code)
   (let $temp (println! ("Runtime-interpreting code" $code))
        (eval $code)))

(= (w) 42)
(= (v) 43)

!(test (myinterpreter (if (== 1 1) (w) (v))) 42)
!(test (myinterpreter (if (== 1 2) (w) (v))) 43)
```

`git-import!` fetches and builds a library from source; see
[the example](examples/ch20-extending-the-engine/20-04-modules-and-the-catalog/06-git_import.metta).
# PyMeTTa

`pip install PyMeTTa`. 104 root exports over 20 public modules.
[Repository](https://github.com/MesTTo/PyMeTTa) ·
[llms.txt](extensions/python/llms.txt)

| Feature | Doors |
|---|---|
| Terms | `S`, `V`, `G`, operators on variables, the bracket door for heads outside identifier grammar |
| Spaces | `space`, `add`, `del`, `match`, `eval`, `atoms`, `len`, nested spaces, views |
| Querying | conjunctions as joins, `where=`, prepared `solve` with `given=`, `to_dicts`, `to_df` |
| Defining | `@m.define`, `@m.pure`, `@m.reads`, `equation(...).to(...)`, `lower`, `trace` |
| Types | `metta.typing`, arrow types, `cast`, bounds, `-> Type` annotations |
| Algebras | `counting`, `prov`, `prob`, `tropical`, and the rest of `Semiring` |
| Concurrency | `EnginePool`, `ProcessPool`, `Scope`, `Channel`, `par_map`, `race`, `spawn` |
| Reactivity | `subscribe`, `Event`, `Subscription`, `Live`, `Changes`, `Delta` |
| Remote | `serve`, `connect`, `RemoteSpace`, `Gateway`, Bearer tokens, `authorize` |
| Foreign spaces | `SpaceProvider` and 20 capability protocols |
| Integrations | `metta.integrate` over the `metta.extensions` entry-point group |
| Observability | `m.stats()`, `m.trace()`, `m.debug()`, `m.record()` |
| Testing | Hypothesis strategies, `SpaceComplianceSuite`, `GatewayComplianceSuite`, `Laws` |

Atoms are built, never parsed.

```python
from metta import S, V

term = S.Parent(S.Tom, S.Bob)
assert str(term) == "(Parent Tom Bob)"
assert str(S.f(V.x) & S.g(V.x)) == "(and (f $x) (g $x))"
assert str(V.age.ge(18)) == "(>= $age 18)"     # an operator by its own name
assert str(S["prime?"](V.n)) == "(prime? $n)"  # brackets for a head with no name
```

A space is a store you query, and a conjunction is a join.

```python
from metta import S, V, space

m = space()
m.add(S.Parent(S.Tom, S.Bob), S.Parent(S.Bob, S.Ann))

assert m.match(S.Parent(S.Tom, V.child)).to_dicts() == [{"child": "Bob"}]

# A conjunction is a join.
assert m.match(S.Parent(V.x, V.y), S.Parent(V.y, V.z)).to_dicts() == [
    {"x": "Tom", "y": "Bob", "z": "Ann"}
]

m.add(S.Age(S.Tom, 62), S.Age(S.Bob, 40))
assert m.match(S.Age(V.p, V.n), where=V.n.ge(60)).to_dicts() == [
    {"p": "Tom", "n": 62}
]
assert len(m.match(S.Age(V.p, V.n), limit=1)) == 1

# Facts for one block only.
with m.assuming(S.Parent(S.Ann, S.Zoe)):
    assert m.match(S.Parent(S.Ann, V.c)).to_dicts() == [{"c": "Zoe"}]

# A prepared statement: the shape and its columns build once, then every
# solve() reuses them. given= adds facts for one solve and leaves nothing.
grand = m.prepare(S.Parent(V.x, V.y), S.Parent(V.y, V.z))
assert grand.solve().to_dicts() == [{"x": "Tom", "y": "Bob", "z": "Ann"}]
assert len(grand.solve(given=[S.Parent(S.Ann, S.Zoe)])) == 2
```

Equations are atoms, so a definition is something you add.

```python
from metta import S, V, equation, space

m = space()
m.add(equation(S.price(V.x)).to(10))      # an equation is an atom you add
assert m.eval(S.price(S.apple)) == [10]

m.add(equation(S.price(S.apple)).to(3))   # a second one, at run time
assert sorted(a.value for a in m.eval(S.price(S.apple))) == [3, 10]

heads = {str(row.head) for row in m.match(equation(V.head).to(V.body))}
assert "(price apple)" in heads           # the program can read itself
```

Python functions become equations the engine holds, and they run backwards.

```python
from metta import space

m = space()

@m.define
def fib(n=0):                          # -> the arm (0 0)
    return 0

@m.define
def fib(n=1):                          # -> the arm (1 1)
    return 1

@m.define
def fib(n):                            # -> ($n (+ (fib (- $n 1)) (fib (- $n 2))))
    return fib(n - 1) + fib(n - 2)

# the three together:
# (= (fib $n) (case $n ((0 0) (1 1) ($n (+ (fib (- $n 1)) (fib (- $n 2)))))))

assert fib(10) == [55]           # callable from Python, answers a list
assert fib.py(10) == 55          # and the Python twin stays callable
```

```python
from metta import S, V, space

m = space()

@m.define
def double(x: int) -> int:
    return 2 * x

assert double(5) == [10]                  # forwards, and callable from Python
assert m.solve(10, S.double(V.x)).x == 5  # backwards, no second definition
assert m.solve(5, V.p + 2).p == 3         # every operator solves for its slot
assert m.solve(12, V.q * 4).q == 3
```

Rows are dicts, dataframes or Arrow.

```python
from metta import S, V, space

m = space()
m.add(S.user(1, "Ada"), S.user(2, "Bob"))
rows = m.match(S.user(V.id, V.name))
assert rows.to_dicts() == [{"id": 1, "name": "Ada"}, {"id": 2, "name": "Bob"}]
assert len(rows) == 2
```

Transactions roll back.

```python
from metta import S, space

m = space()

def stage():
    m.add(S.tentative(1))
    raise RuntimeError("something went wrong")

try:
    m.transaction(stage)          # all of it, or none of it
except RuntimeError:
    pass
assert len(m) == 0                # the add was rolled back
```

Real threads over one shared space, answering in completion order.

```python
import metta
from metta import S, V, space

m = space()
m += [(S.Reading, S.north, 12), (S.Reading, S.south, 30)]

@m.define
def above(limit: int) -> int:
    return len(m.match(S.Reading(V.site, V.value), where=V.value.ge(limit)))

# Branches run on real threads over the one shared space, and answer in
# COMPLETION order, so `collapse` has nothing to do here.
assert sorted(a.value for a in m.parallel(S.above(10), S.above(20))) == [1, 2]

# A parallel MAP is a different promise: it keeps the INPUT's order.
assert str(m.eval(metta.par_map(S.above, (10, 20)))[0]) == "(2 1)"
```

Standing queries.

```python
from metta import S, V, space

m = space()
seen = []
m.subscribe(S.Alarm(V.what), seen.append)
m.add(S.Alarm(S.fire))

assert [str(event.atom) for event in seen] == ["(Alarm fire)"]
assert str(seen[0].bindings["what"]) == "fire"
```

Implement one method and the engine queries your data as atoms.

```python
import metta
from metta import S, V
from metta.foreign import SpaceProvider

class Rows(SpaceProvider):
    def __init__(self, rows):
        self.rows = rows

    def atoms(self):
        return [S.user(i, name) for i, name in self.rows]

metta.attach("&catalogue", Rows([(1, "Ada"), (2, "Bob")]))
rows = metta.space("&catalogue").match(S.user(V.id, V.name))
assert rows.to_dicts() == [{"id": 1, "name": "Ada"}, {"id": 2, "name": "Bob"}]
```

Serve a space over HTTP.

```python
from metta import S, space, remote

m = space()
m.add(S.edge(S.a, S.b))

with remote.serve(m, spaces=[m.name]) as server:
    server.url          # another process attaches to this
```

No wrapper, no registry entry, no hardcoded name.

```python
import math
from metta import space
from metta.integrate import module_ops

m = space()
module_ops(m, math, ["sqrt", "gcd"], effect="pureStructural")
assert list(m.fn.sqrt(16.0)) == [4.0]
```

## Example

Two literatures that never cite each other, one red herring, and the same
question asked symbolically, then by embedding, then for its provenance.

```python
import torch
from metta import TRUE, G, S, V, counting, prov, space
from metta_arrays import EmbeddingStore

m = space()

# Two literatures that never cite each other, and a red herring. Each claim
# carries the paper it came from. Nothing here states a conclusion.
for paper, agent, verb, target in [
    ("p1", "omega-3", "lowers", "blood-viscosity"),
    ("p2", "blood-viscosity", "aggravates", "raynaud"),
    ("p4", "omega-3", "lowers", "platelet-aggregation"),
    ("p5", "platelet-aggregation", "aggravates", "raynaud"),
    ("p3", "aspirin", "lowers", "inflammation"),
]:
    m.add_tagged_fact(S[paper], S.reports(S[agent], S[verb], S[target]))

# Swanson's ABC rule, tagged like any other source.
m.add_tagged_rule(
    S.abc,
    S.suggests(V.agent, V.condition),
    S.reports(V.agent, S.lowers, V.factor),
    S.reports(V.factor, S.aggravates, V.condition),
)

TERMS = {"omega-3": [0.90, 0.10, 0.0], "fish-oil": [0.88, 0.16, 0.0],
         "aspirin": [0.10, 0.90, 0.0], "blood-viscosity": [0.0, 0.10, 0.90]}
store = EmbeddingStore(m, name="terms", mirror=False)
for term, vector in TERMS.items():
    store.add(S[term], torch.tensor(vector))

class Like:
    """Unifies with whatever the embedding puts within `floor`. `match_` is the
    whole interface: no registration, and it composes with `unify`."""
    def __init__(self, key, floor=0.95):
        self.key, self.floor = key, floor
    def match_(self, other):
        for key, score in store.ranked(self.key, len(TERMS)):
            if str(key) == str(other) and float(score) >= self.floor:
                yield other

near_fish_oil = S.unify(G(Like(S.fish_oil)), V.agent, TRUE, S.superpose(()))

# Symbolically there is nothing. No paper contains the phrase.
assert m.match(S.reports(S.fish_oil, S.lowers, V.factor)).to_dicts() == []

# The same corpus, asked with a term the embedding can place. The join is the
# engine's; deciding that fish-oil IS omega-3 is the tensor's.
found = m.match(S.suggests(V.agent, S.raynaud), where=near_fish_oil, under=prov).one()
assert str(found.value) == "(suggests omega-3 raynaud)"

# How much independent support? The same question under a different algebra.
assert m.match(S.suggests(S["omega-3"], S.raynaud), under=counting).one().annotation == 2

# Which papers? A provenance polynomial: `times` is joint use, `plus` is an
# alternative derivation. Read it as "the rule with p1 and p2, or with p4 and p5".
assert str(found.annotation) == (
    "(plus (times (times abc p1) p2) (times (times abc p4) p5))"
)
assert all(name in found.why().render() for name in ("abc", "p1", "p2", "p4", "p5"))
```

# TSMeTTa

`npm install tsmetta`. The engine is a WebAssembly SWI-Prolog inside your Node
process, so there is nothing to install, and the same code runs in a browser.
[Repository](https://github.com/MesTTo/TSMeTTa) ·
[llms.txt](extensions/node/llms.txt)

| Feature | Surface |
|---|---|
| Terms | `S`, `V`, `fn`, camelCase reaching MeTTa's hyphens, `Term` |
| Spaces | `space`, `spaces`, `view`, `State`, `ScopeHandle`, `World`, `Limits`, `Stats` |
| Answers | `answers`, `matching`, `derivation`, `strategies`, `schema` |
| Defining | `define`, `trace`, `lower` |
| Algebras | `algebra` |
| Concurrency | `parallel`: `race`, `merge`, `parMap` |
| Reactivity | `events`: `EventStream`, `Fold`, `publish`, `stream`; `subscribe` |
| Remote | `remote`, `saga` |
| Extending | `seam`, `provider`, `integrate`, `library`, `convert`, `factories` |
| Tooling | `cli`, `lint`, `manifest`, `present`, `config`, `random`, `paths`, `naming` |

```ts
import { metta, S, type Term, V } from "tsmetta";

const m = await metta();
m.add(S.parent(S.tom, S.bob), S.parent(S.bob, S.ann));

// Rows are keyed by the pattern's own variable names.
for await (const { child } of m.match(S.parent(S.tom, V.child))) {
  console.log(String(child));                  // bob
}

// An ordinary TypeScript function becomes ONE equation the engine holds, so a
// call costs no host crossing at all.
const twice = m.define(function twice(n: number): number {
  return n * 2;
});
console.log(String(await twice(21).one())); // 42

// A generator body is traced into clauses; `yield*` asks, `yield` emits.
const grandparent = m.define(function* grandparent(x: Term) {
  const { y } = yield* m.match(S.parent(x, V.y));
  const { z } = yield* m.match(S.parent(y, V.z));
  return z;
});
console.log(String(await grandparent(S.tom).one())); // ann

// And a TypeScript function the engine calls back into, from the middle of a
// reduction, awaited if it answers with a promise.
m.op(async function fetchJson(url: string): Promise<unknown> {
  return (await fetch(url)).json();
});
console.log(m.effectOf("fetch-json")); // oracleIO

m.dispose();
```

# CMeTTa

A C program opens the engine in its own process, builds terms and asks.
[Repository](https://github.com/MesTTo/CMeTTa) ·
[llms.txt](extensions/cmetta/llms.txt)

| Feature | Doors |
|---|---|
| Runtime | `mt_open`, `mt_close`, `mt_verbose`, `mt_thread_attach`, `mt_thread_detach` |
| Constructors | `mt_sym`, `mt_var`, `mt_text`, `mt_num`, `mt_real`, `mt_bool`, `mt_unit`, `mt_bigint`, `mt_rational`, `mt_spaceref`, `mt_exprv` |
| References | `mt_keep`, `mt_drop` |
| Inspection | `mt_kind_of`, `mt_name`, `mt_int`, `mt_float`, `mt_truth`, `mt_len`, `mt_at`, `mt_eq`, `mt_hash` |
| Unification | `mt_unify`, `mt_unifyv`, `mt_bindings_*`, `mt_substitute` |
| Spaces | `mt_self`, `mt_catalog`, `mt_space_open`, add/del/match/eval/atoms/count/wipe |
| Answers | `mt_run`, `mt_load`, `mt_do`, `mt_next`, `mt_row_next`, `mt_bound` |
| Text | `mt_parse`, `mt_show`, `mt_write_dup`, `mt_free` |
| Errors | `mt_error`, `mt_errmsg`, `mt_remedy`, `mt_ground`, `mt_ok`, `mt_clear` |
| Defining | `mt_def` for a C function, `mt_lower` for equations from C tokens |

```c
#define MT_SHORTHAND
#include <cmetta.h>
#include <stdio.h>

/* --- the two doors, side by side ------------------------------------ *
 *
 * mt_def publishes a C function. The engine CALLS it, and because nothing can
 * be seen of what it does, it must declare an effect class.
 *
 * mt_lower installs an EQUATION. It is MeTTa, so the engine reads it,
 * type-checks it, specialises it, matches on it, and a call crosses into no
 * host at all.
 *
 * The preprocessor is what makes the second one possible in C. Python lowers
 * by reading a function's __code__ and Node by reading its toString(); C has
 * neither at run time, but `#` is access to the program's own source at the
 * one moment C offers it.
 */

static mt_status op_triple(mt_call *call, void *user)
{ int64_t v;
  (void)user;
  mt_clear();
  v = mt_int(mt_arg(call, 0));
  if ( !mt_ok() ) return mt_fail(call, "triple wants a Number");
  return mt_answer(call, N(v * 3));
}

/* --- one body, two languages ---------------------------------------- *
 *
 * The operators are parameters, so the same body expands to C in one mode and
 * to MeTTa tokens in the other. The function exists once and is callable from
 * both, which is what the other seats' twins buy, bought the way C buys it.
 */
#define POLY(ADD, MUL, x)  ADD(MUL(3, x), 1)
#define C_ADD(a, b)        ((a) + (b))
#define C_MUL(a, b)        ((a) * (b))
#define M_ADD(a, b)        (+ a b)
#define M_MUL(a, b)        (* a b)

static int64_t poly(int64_t x) { return POLY(C_ADD, C_MUL, x); }

int main(void)
{ metta *m = mt_open(NULL);
  if ( !m ) return fprintf(stderr, "boot: %s\n", mt_errmsg()), 1;

  /* Called: the engine crosses into C, and had to be told the effect class. */
  mt_def(m, (mt_op){ .name = "triple", .arity = 1,
                     .effect = MT_PURE, .fn = op_triple });
  printf("called   (triple 7) = %lld\n",
         (long long)mt_one_int(mt_run(m, "!(triple 7)")));

  /* Lowered: the body is C tokens the compiler saw, installed as MeTTa. No
     quoting, no escaped newlines, and unbalanced parentheses are a compile
     error rather than a runtime one. */
  mt_lower(m, (twice $x), (* 2 $x));
  mt_lower(m, (fib $n), (if (< $n 2) $n
                            (+ (fib (- $n 1)) (fib (- $n 2)))));
  printf("lowered  (twice 21) = %lld\n",
         (long long)mt_one_int(mt_run(m, "!(twice 21)")));
  printf("lowered  (fib 20)   = %lld\n",
         (long long)mt_one_int(mt_run(m, "!(fib 20)")));

  /* One body, both languages. */
  mt_lower(m, (poly $x), POLY(M_ADD, M_MUL, $x));
  printf("in MeTTa (poly 5)   = %lld\n",
         (long long)mt_one_int(mt_run(m, "!(poly 5)")));
  printf("in C     poly(5)    = %lld\n", (long long)poly(5));

  /* And the difference that matters: a lowered equation is an ATOM in the
     space, so the engine can be asked about it. A published C function is
     opaque and there is nothing to ask. */
  mt_each (a, mt_match(mt_self(m), E("=", E("poly", V("x")), V("body"))))
      printf("the engine can see: %s\n", mt_show(a));

  mt_each (a, mt_match(mt_self(m), E("=", E("triple", V("x")), V("body"))))
      printf("...but not this:    %s\n", mt_show(a));
  printf("(nothing printed above, because a called function has no equation)\n");

  mt_close(m);
  return 0;
}
```

# Documentation

| Read | For |
|---|---|
| [llms.txt](llms.txt) | the language and every surface, exact return shapes, gate-checked names |
| [examples/](examples/) | 360 programs in 22 chapters, every one run by the gate |
| [EXTENDING.md](EXTENDING.md) | writing an integration |
| [CONTRIBUTING.md](CONTRIBUTING.md) | working on this repository |
| [SECURITY.md](SECURITY.md) | reporting a vulnerability |

## Citing

```bibtex
@software{petta,
  author = {Hammer, Patrick},
  title  = {PeTTa},
  url    = {https://github.com/patham9/PeTTa},
  note   = {The MeTTa implementation whose semantics this engine follows}
}

@software{metta_kernel,
  author  = {MesTTo},
  title   = {MeTTa Kernel},
  url     = {https://github.com/MesTTo/MeTTa},
  version = {0.8.0}
}
```

## Licence

Apache-2.0. See [LICENSE](LICENSE).
