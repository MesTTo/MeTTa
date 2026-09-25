<!--
Purpose: show what MeTTa is, how it is put together, and what each surface can
  do, through examples that run.
Guarantees: every metta fence runs on the engine, each as a program in a
  fresh process and directory [tested 2026-09-25T12:45:30+10:00:
  tests/checks/check_readme_fences.py]. Every component is
  documented in its OWN repository and named once in the Architecture table, so
  no fence here belongs to a surface, to the library pack or to a backend: this
  page is the engine's, and a second copy of a component's own page drifts from
  it silently, which is what the two descriptions of lib_crypto had already
  done.
-->

# MeTTa

MeTTa, Hyperon's AGI language, based on PeTTa semantics with significant
extensions.

<!-- shared:what-is-metta -->
## What MeTTa is

MeTTa is a language for rewriting metagraphs. A program and its data are the
same thing: atoms in a space, where an atom is a symbol, a number, a variable
or an expression built from other atoms, and a space is the metagraph they
form together.

You write equations rather than statements, and the engine matches a pattern
against the whole space at once. Every match is an answer, so a rule that fits
three ways yields three results, and whether you take one of them, the first,
or all is the caller's choice rather than the language's. Search is something
you write down instead of something you implement.

One space holds symbolic rules and grounded values side by side: a number, a
matrix, a handle to a trained model. A rule can match on what a model produced
and a model can be called from inside a rule, so the neurosymbolic case is
ordinary here rather than an integration between two systems. Both halves are
atoms in the same metagraph, read by the same matcher.
<!-- /shared:what-is-metta -->

**If you are an LLM, read [llms.txt](llms.txt)** for the language and every
surface, with exact return shapes and no prose to guess at.

```bash
pip install pymetta    # Linux x86_64, CPython 3.12-3.14: the wheel carries the patched SWI-Prolog
npm install tsmetta    # Node and browsers: the package carries a patched WebAssembly SWI-Prolog
```

The engine runs only on a patched SWI-Prolog and refuses to boot on a stock one.
For Python on any other platform, and for the C seat, build it as
[docs/patched-host.md](docs/patched-host.md) describes.

# Architecture

One engine, in Prolog and C. Everything else reaches it through a declared
seam, so each piece is built, versioned and published on its own.

This Prolog engine carries the 1.0 line and will soon be replaced by a new
engine written in Rust. The libraries are written in MeTTa over the engine's
primitives so that they carry over unchanged, and that primitive set is what
the Rust engine implements. The patched SWI-Prolog host
([docs/patched-host.md](docs/patched-host.md)) belongs to the Prolog engine
and goes with it.

| Component | Repository | Install | What it is |
|---|---|---|---|
| the engine | `engine/` | in the PyMeTTa and TSMeTTa packages | translator, matcher, spaces, catalog, extension points, the C half |
| Python | [PyMeTTa](https://github.com/MesTTo/PyMeTTa) | `pip install pymetta` | Python is the notation and the engine is the meaning |
| TypeScript | [TSMeTTa](https://github.com/MesTTo/TSMeTTa) | `npm install tsmetta` | the same, through Node and a WebAssembly boot |
| C | [CMeTTa](https://github.com/MesTTo/CMeTTa) | from source | a C program opens the engine in its own process |
| the libraries | [MeTTa-Library-Pack](https://github.com/MesTTo/MeTTa-Library-Pack) | in the PyMeTTa package | written in MeTTa over the primitives, so they outlive the engine |
| the examples | [MeTTa-Examples](https://github.com/MesTTo/MeTTa-Examples) | clone it | executable programs, the semantics documentation |
| the integrations | [PyMeTTa-Extensions](https://github.com/MesTTo/PyMeTTa-Extensions) | `pip install metta-pandas`, and its siblings | a library registers a row and the core names it nowhere |
| a storage backend | [MeTTa-MORK](https://github.com/MesTTo/MeTTa-MORK) | from source | spaces on MORK's Rust trie |

## The four ways in

| To add | You | So that |
|---|---|---|
| a surface | speak the wire codec | a surface is a consumer of the one engine, never an engine of its own |
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
!(test (size-atom (collapse (match &catalogs (package $name $path) $name))) 60)
```

Nothing is imported first. Package handling is the engine's, not a library's,
so the catalog is there at boot.

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

A pattern child that stands for a run of atoms. Upstream PeTTa has no such
pattern: it reads `(:seg $x)` as an ordinary expression and `...` as a symbol, so
what a pattern below matches answers nothing there. This is the one part of the
language below that a stock kernel will not run, and the
[library pack](https://github.com/MesTTo/MeTTa-Library-Pack#what-each-library-needs)
lists the libraries that need a kernel beyond PeTTa, for this or for the two
other spellings upstream reads as data.

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

# Documentation

| Read | For |
|---|---|
| [llms.txt](llms.txt) | the language and every surface, exact return shapes, gate-checked names |
| [examples/](examples/) | the corpus, by chapter, every program run by the gate |
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
