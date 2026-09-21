<!--
Purpose: show what MeTTa is, how it is put together, and what each surface can
  do, through examples that run.
Guarantees: every metta fence runs on the engine [tested: python -m pytest
  extensions/python/tests/repository/test_readme.py -q]; the c fence is the text
  of a file its own gate builds and runs. The Python and TypeScript surfaces are
  documented in their own repositories, so no fence here is theirs.
-->

# MeTTa

MeTTa, Hyperon's AGI language, based on PeTTa semantics with significant
extensions.

**If you are an LLM, read [llms.txt](llms.txt)** for the language and every
surface, with exact return shapes and no prose to guess at.

```bash
sudo apt install swi-prolog          # macOS: brew install swi-prolog
                                     # Windows: winget install SWI-Prolog.SWI-Prolog
```

# Architecture

One engine, in Prolog and C. Everything else reaches it through a declared
seam, so each piece is built, versioned and published on its own.

| Component | Repository | What it is |
|---|---|---|
| the engine | `engine/` | translator, matcher, spaces, catalog, extension points, the C half |
| the libraries | [MeTTa-Library-Pack](https://github.com/MesTTo/MeTTa-Library-Pack) | 61 libraries, written in MeTTa over the primitives |
| the examples | [MeTTa-Examples](https://github.com/MesTTo/MeTTa-Examples) | 360 executable programs, the semantics documentation |
| C | [CMeTTa](https://github.com/MesTTo/CMeTTa) | a C program opens the engine in its own process |
| a storage backend | [MeTTa-MORK](https://github.com/MesTTo/MeTTa-MORK) | spaces on MORK's Rust trie |

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

A pattern child that stands for a run of atoms. Upstream PeTTa has no such
pattern, so this is the one part of the language below that a stock kernel will
not parse, and the sixteen libraries listed under [the library pack](#the-library-pack)
are written with it.

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

# The library pack

Sixty-one libraries sit under `lib/`. None is loaded until a program names it,
and every example below is run by the gate on a fresh space, so a line that
stops being true fails the build instead of going stale on the page.

Sixteen of them are written in a language upstream PeTTa does not accept. They
use the sequence variables above, `(:seg $rest)` and its anonymous `...`, in
their own definitions and signatures: `lib_sets` types union as
`(-> (:seg Expression) Expression)` so it takes any number of sets, and
`lib_strategy` types `seq` the same way. What they mean is PeTTa's; what they
are written in is a superset of it, so these sixteen need this kernel:

> `lib_builtin_types`, `lib_combinatorics`, `lib_database`, `lib_datastructures`, `lib_encoding`, `lib_functional`, `lib_graph`, `lib_package`, `lib_pairs`, `lib_parsing`, `lib_random`, `lib_sets`, `lib_statistics`, `lib_strategy`, `lib_tabling`, `lib_uuid`.

The other forty-four import and run on either. `lib_gitimport` is the
sixty-first and has no MeTTa half at all: it is the Prolog backing
`lib_package` calls to fetch a repository, reached through a package
requirement rather than through `import!`.

One example each is what this page is for. Every head a library exports, with
its own `(@doc ...)` text, is in `website/reference/metta-libraries.md`,
generated from the live atoms by `extensions/python/tools/libdoc.py`; `help!`
and `get-doc` answer the same atoms at the prompt.

### `lib_builtin_types`

Arithmetic, comparison and the format machinery every other library assumes.  Needs sequence variables.

```metta
!(import! &self (library lib_builtin_types))
!(test (format-args "{} and {}" ("only")) "only and ")
```

### `lib_cli`

Argument vectors, typed options and generated help.

```metta
!(import! &self (library lib_cli))
!(test (cli-types) (boolean integer float atom string metta))
```

### `lib_combinatorics`

Ranges, subsets, permutations and k-combinations.  Needs sequence variables.

```metta
!(import! &self (library lib_combinatorics))
!(test (choose2l (a b c)) ((a b) (a c) (b c)))
```

### `lib_compression`

Gzip and zlib over bytes and files, and archive entries.

```metta
!(import! &self (library lib_compression))
!(test (compression-formats) (gzip zlib))
```

### `lib_conformance`

Prove a foreign space provider against the same contract the Python kit uses.

```metta
!(import! &self (library lib_conformance))
!(test (get-type check-space-provider) (-> Atom Expression))
```

### `lib_constraints`

Rational and boolean constraint solving, CLP(Q) and CLP(B).

```metta
!(import! &self (library lib_constraints))
!(test (clpq (= (+ $x 1) 3)) True)
```

### `lib_crypto`

Hashes, HMACs, password records and random bytes.

```metta
!(import! &self (library lib_crypto))
!(test (crypto-hash sha256 "") "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
```

### `lib_csv`

Lossless CSV text, bounded streaming and transactional file writes.

```metta
!(import! &self (library lib_csv))
!(test (csv-parse "001,\"a,b\"\r\n002,9\r\n") (("001" "a,b") ("002" "9")))
```

### `lib_database`

A persistent journal a space reads and writes through.  Needs sequence variables.

```metta
!(import! &self (library lib_database))
!(test (get-type database-open!) (-> %Undefined% Symbol %Undefined%))
```

### `lib_datastructures`

Finger trees and persistent maps.  Needs sequence variables.

```metta
!(import! &self (library lib_datastructures))
!(test (map-size (map-from-pairs ((a 1) (b 2)))) 2)
```

### `lib_datetime`

Timestamps, calendar fields and formatting.

```metta
!(import! &self (library lib_datetime))
!(test (day-of-week 1766188800) Saturday)
```

### `lib_derived`

The derived control forms, `once` among them: the forms the compiler keeps
fused, written out as translator rules so a program can have the smaller
instruction set and pay the difference knowingly. `add-translator-rule!`
registers for every space and the rest of the session, so a program that only
wanted it briefly gives it back.

```metta
!(import! &self (library lib_derived))
!(test (once (superpose (1 2 3))) 1)
!(remove-translator-rule! once)
```

### `lib_dict`

A space used as a dictionary.

```metta
!(import! &self (library lib_dict))
!(test (dict-size (dict-put (new-space) a 1)) 1)
```

### `lib_doc`

Documentation as data, queryable like anything else.

```metta
!(import! &self (library lib_doc))
!(test (get-metatype (get-doc get-doc)) Expression)
```

### `lib_encoding`

Base64, hex and UTF-8 between text and bytes.  Needs sequence variables.

```metta
!(import! &self (library lib_encoding))
!(test (utf8-encode "hi") (104 105))
```

### `lib_file`

Files, directories, handles and transactional publication.

```metta
!(import! &self (library lib_file))
!(test (path-join "one" "two") "one/two")
```

### `lib_functional`

Zip, chunk, window, partition and the folds.  Needs sequence variables.

```metta
!(import! &self (library lib_functional))
!(test (zip (1 2 3) (a b c)) ((1 a) (2 b) (3 c)))
```

### `lib_graph`

Vertices, edges, reachability and topological order.  Needs sequence variables.

```metta
!(import! &self (library lib_graph))
!(test (graph-topological-order ((a (b)) (b ()))) (a b))
```

### `lib_he`

The hyperon-experimental compatibility surface.

```metta
!(import! &self (library lib_he))
!(test (unify (f a) (f $x) $x none) a)
```

### `lib_http`

HTTP requests and a local server.

```metta
!(import! &self (library lib_http))
!(test (http-methods) (delete get head post put patch options))
```

### `lib_import`

Loading MeTTa and Prolog from files and modules.

```metta
!(import! &self (library lib_import))
!(test (get-metatype use-module!) Grounded)
```

### `lib_json`

JSON to atoms, to spaces, and back.

```metta
!(import! &self (library lib_json))
!(test (json-decode "[1,2,3]") (1 2 3))
```

### `lib_logging`

Levelled, topic-scoped logging.

```metta
!(import! &self (library lib_logging))
!(test (log-levels) (debug informational warning error))
```

### `lib_markup`

XML and HTML parsing with selectors.

```metta
!(import! &self (library lib_markup))
!(test (markup-text (markup-parse-xml "<p>hi</p>")) "hi")
```

### `lib_math`

Gcd, rationals, factorisation and exact roots.

```metta
!(import! &self (library lib_math))
!(test (math-gcd (12 18)) 6)
```

### `lib_measure`

Instruction and inference counters around a goal.

```metta
!(import! &self (library lib_measure))
!(test (get-metatype measure) Symbol)
```

### `lib_memo`

Memoised evaluation with an explicit cache.

```metta
!(import! &self (library lib_memo))
!(test (get-metatype memo) Symbol)
```

### `lib_mm2`

Minimal MeTTa 2, the small kernel.

```metta
!(import! &self (library lib_mm2))
!(test (get-type ＋) (-> Atom %Undefined%))
```

### `lib_nars`

Non-axiomatic reasoning.

```metta
!(import! &self (library lib_nars))
!(test (get-metatype nars) Symbol)
```

### `lib_observe`

Trace and observe a source as it loads.

```metta
!(import! &self (library lib_observe))
!(test (get-type observe-source) (-> SpaceType String String SpaceType))
```

### `lib_package`

Packages, their catalogs, requirements and native backings.  Needs sequence variables.

```metta
!(import! &self (library lib_package))
!(test (size-atom (collapse (match &catalogs (package $n $p) $n))) 61)
```

### `lib_pairs`

Association lists, grouped, sorted and looked up.  Needs sequence variables.

```metta
!(import! &self (library lib_pairs))
!(test (pairs-lookup ((a 1) (b 2)) b) 2)
```

### `lib_parsing`

Parser combinators over a grammar term.  Needs sequence variables.

```metta
!(import! &self (library lib_parsing))
!(test (grammar-parse (lit "ab") "ab") "ab")
```

### `lib_patrick`

Composition and iteration combinators.

```metta
!(import! &self (library lib_patrick))
!(test (get-type compose) (-> Atom _ _))
```

### `lib_pln`

Probabilistic logic networks, truth and confidence.

```metta
!(import! &self (library lib_pln))
!(test (Truth_w2c 1) 0.5)
```

### `lib_pln2`

The second PLN formulation.

```metta
!(import! &self (library lib_pln2))
!(test (get-metatype pln2) Symbol)
```

### `lib_process`

Run a program, wait on it, signal it.

```metta
!(import! &self (library lib_process))
!(test (process-run! "echo" ("hi")) (process-result 0 "hi\n" ""))
```

### `lib_random`

Shuffles, samples and the named distributions.  Needs sequence variables.

```metta
!(import! &self (library lib_random))
!(test (random-shuffle! ()) ())
```

### `lib_redis`

A Redis server as a space.

```metta
!(import! &self (library lib_redis))
!(test (get-metatype redis-open!) Symbol)
```

### `lib_reflect`

Ask the engine about its own atoms.

```metta
!(import! &self (library lib_reflect))
!(test (atom-variables (f $x $y)) ($x $y))
```

### `lib_regex`

Match, capture, split and replace.

```metta
!(import! &self (library lib_regex))
!(test (re-match "(?i)^needle" "Needle in a haystack") True)
```

### `lib_roman`

Roman numerals, as a worked small library.

```metta
!(import! &self (library lib_roman))
!(test (get-metatype roman) Symbol)
```

### `lib_sets`

Sets over expressions, with variadic union and intersection.  Needs sequence variables.

```metta
!(import! &self (library lib_sets))
!(test (set-of (3 1 2 1)) (1 2 3))
```

### `lib_socket`

TCP and UDP endpoints.

```metta
!(import! &self (library lib_socket))
!(test (socket-wait! () infinite) ())
```

### `lib_soft`

Soft symbol similarity and scoring.

```metta
!(import! &self (library lib_soft))
!(test (sym-sim a a) 1.0)
```

### `lib_spaces`

Move, copy, drain and count atoms between spaces.

```metta
!(import! &self (library lib_spaces))
!(test (match-count (new-space) ($x)) 0)
```

### `lib_statistics`

Means, quantiles, ranks and correlation.  Needs sequence variables.

```metta
!(import! &self (library lib_statistics))
!(test (stats-mean (1 2 3)) 2)
```

### `lib_strategy`

Rewriting strategies, seq and choice among them.  Needs sequence variables.

```metta
!(import! &self (library lib_strategy))
!(test (get-type seq) (-> Atom (:seg Atom) %Undefined%))
```

### `lib_string`

Codepoint text, slicing, padding and similarity.

```metta
!(import! &self (library lib_string))
!(test (string-length "a🦊é") 3)
```

### `lib_system`

The environment, the working directory and platform facts.

```metta
!(import! &self (library lib_system))
!(test (collapse (env-get "NO_SUCH_VARIABLE_HERE")) ())
```

### `lib_tabling`

Tabled evaluation with explicit cache control.  Needs sequence variables.

```metta
!(import! &self (library lib_tabling))
!(test (get-type tabled) (-> Atom Bool))
```

### `lib_testing`

The test harness the corpus itself runs on, and this page with it.

```metta
!(import! &self (library lib_testing))
!(test (== 1 1) True)
```

### `lib_thread`

Spawn, scope, capture and the parallel forms.

```metta
!(import! &self (library lib_thread))
!(test (get-type spawn) (-> Atom %Undefined%))
```

### `lib_torch`

PyTorch tensors as grounded atoms.

```metta
!(import! &self (library lib_torch))
!(test (get-type torch-tensor) (-[det,writesState]-> %Undefined% %Undefined%))
```

### `lib_unicode`

Normalisation, graphemes and character properties.

```metta
!(import! &self (library lib_unicode))
!(test (unicode-normalize nfkc "ﬃ") "ffi")
```

### `lib_uri`

Parse, build, resolve and normalise URIs.

```metta
!(import! &self (library lib_uri))
!(test (uri-parts "") (("path" "")))
```

### `lib_uuid`

UUID generation, parsing and versions.  Needs sequence variables.

```metta
!(import! &self (library lib_uuid))
!(test (uuid-version (uuid-random!)) 4)
```

### `lib_vector`

Dot, norm, cosine and the elementwise operations.

```metta
!(import! &self (library lib_vector))
!(test (dot (1.0 2.0) (3.0 4.0)) 11.0)
```

### `lib_yaml`

YAML to atoms and back.

```metta
!(import! &self (library lib_yaml))
!(test (yaml-decode "- 1\n- 2\n") (1 2))
```

### `lib_zar`

Consult Prolog files and import their predicates.

```metta
!(import! &self (library lib_zar))
!(test (get-type consult_file) (-> %Undefined% %Undefined%))
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
