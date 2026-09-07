;Six doors that load Prolog, and what separates them. Two live in lib_import,
;three in lib_zar, and one is the fast path for DATA rather than for code.
;
;The split is `consult` against `use_module`. A consult loads every clause a
;file has into the calling context; a use_module loads a file with a module
;header and takes only what it exports. Both come in a spelling that takes
;the path as an argument and a spelling that takes it through a `let`, which
;is the engine's convention for a Prolog predicate whose LAST argument is its
;answer.
!(import! &self (library lib_import))
!(import! &self (library lib_zar))
!(import! &self (library lib_file))

;lib_zar's `consult_file` takes the path as an ordinary argument, so the path
;can be computed rather than being a literal. Registration is a separate
;step, which is what makes this the low-level door.
!(test (consult_file "./examples/ch20-extending-the-engine/20-03-prolog-underneath/_fixtures/rung_functions.pl")
       True)
!(test (import_prolog_functions (noeval (rung_double rung_greeting))) True)
!(test (rung_double 21) 42)

;`use_module_file` is the same shape over a MODULE. Only the export list
;arrives: `rung_module_triple` is exported and `rung_module_hidden` is not,
;so registering the hidden one is refused by the absent-predicate rule.
!(test (use_module_file "./examples/ch20-extending-the-engine/20-03-prolog-underneath/_fixtures/rung_module.pl")
       True)
!(test (import_prolog_functions (noeval (rung_module_triple))) True)
!(test (rung_module_triple 14) 42)
!(test (let $reported (catch (import_prolog_functions (noeval (rung_module_hidden))))
         (unify $reported (Error $ball $context) (car-atom $ball) no-error))
       existence_error)

;`use_module_global` is the predicate-form spelling of the same load: its one
;argument is the answer position, so the path goes in through a `let` that
;unifies with it. lib_import's `import_prolog_functions_from_module` is that
;`let` plus a checked registration, in one call.
!(test (let "./examples/ch20-extending-the-engine/20-03-prolog-underneath/_fixtures/rung_global.pl"
            (use_module_global)
            loaded)
       loaded)
!(test (import_prolog_functions_from_module
         "./examples/ch20-extending-the-engine/20-03-prolog-underneath/_fixtures/rung_global.pl"
         (rung_global_six))
       True)
!(test (rung_global_six 7) 42)

;lib_zar's two `_pred` spellings are the same two operations again, written
;over `consult_file` and `use_module_file` rather than over the global
;predicates. They exist so a program can load and register in one call
;without lib_import's main.pl wrappers.
!(test (import_prolog_functions_from_file_pred
         "./examples/ch20-extending-the-engine/20-03-prolog-underneath/_fixtures/rung_pred_file.pl"
         (rung_pred_quad))
       True)
!(test (rung_pred_quad 10) 40)
!(test (import_prolog_functions_from_module_pred
         "./examples/ch20-extending-the-engine/20-03-prolog-underneath/_fixtures/rung_pred_module.pl"
         (rung_pred_five))
       True)
!(test (rung_pred_five 10) 50)

;`use-module!` is the shortest of them and the least general: it loads a
;library of SWI's own by bare name, `use_module(library(Name))`, so there is
;no path and nothing to register.
!(test (use-module! lists) True)

;`static-import!` is the odd one out, and it is for DATA rather than code. It
;reads a .metta file holding nothing but ground forms, writes one Prolog fact
;per form into the importing space's own storage module, compiles that to a
;.qlf and loads it, so a large table costs one compile rather than one parse
;per run. Every fact lands in the space, which is what makes it an import
;rather than a consult: `match` finds them.
!(test (static-import! &self "_fixtures/static_rows") True)
!(test (sort-atom (collapse (match &self (city $c france) $c))) (lyon paris))
!(test (collapse (match &self (population paris $n) $n)) (2100000))

;The two artefacts it wrote are beside the source, and the next run reuses
;them if they are newer than it. They are build products rather than
;examples, so this file removes them again; the directory's own .gitignore
;names them for the run that stops before it gets here.
!(test (file-exists "./examples/ch20-extending-the-engine/20-03-prolog-underneath/_fixtures/static_rows.pl")
       True)
!(test (file-exists "./examples/ch20-extending-the-engine/20-03-prolog-underneath/_fixtures/static_rows.qlf")
       True)
!(delete-file! "./examples/ch20-extending-the-engine/20-03-prolog-underneath/_fixtures/static_rows.pl")
!(delete-file! "./examples/ch20-extending-the-engine/20-03-prolog-underneath/_fixtures/static_rows.qlf")
!(test (file-exists "./examples/ch20-extending-the-engine/20-03-prolog-underneath/_fixtures/static_rows.pl")
       False)
