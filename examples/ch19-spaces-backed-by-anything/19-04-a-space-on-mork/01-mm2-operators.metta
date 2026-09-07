;A space whose atoms live in MORK's Rust trie, reached over an FFI. lib_mm2
;is five operators over `&mork`, and they are notation rather than a second
;language: each one is one equation over an ordinary space operation.
;
;The example skips itself when the backend has not been built, because a Rust
;toolchain is not one of the engine's requirements. It says so when it skips
;rather than passing quietly, the way the C-space example beside it does.
;See extensions/mork/build.sh for the build line.
!(import! &self (library lib_file))

;`require-extension!` is the engine's answer for the half that is missing. A
;seat nobody ships is refused BY NAME rather than at the first call into it,
;which is the whole reason lib_mm2 opens with one: without it, each of its
;five operators failed at call time with nothing naming the cause.
!(test (repr (catch (require-extension! nosuchseat)))
       "(Error (metta_extension_required nosuchseat unknown) none)")

;A seat that IS loaded answers the unit, so a library can state its
;dependency and carry on.
!(test (require-extension! python) ())

;The import has to be its own runnable, so the operators exist before
;anything below compiles against them.
!(if (file-exists "./extensions/mork/mork_ffi/target/release/libmork_ffi.so")
     (import! &self (library lib_mm2))
     (println! "SKIPPED mm2-operators: libmork_ffi.so is not built, see extensions/mork/build.sh"))

;＋ is add-atom and － is remove-atom, both on &mork. The names are full-width
;plus and minus, which is what keeps them from colliding with arithmetic.
!(if (file-exists "./extensions/mork/mork_ffi/target/release/libmork_ffi.so")
     (progn (＋ (edge a b))
            (test (sort-atom (collapse (? (edge $x $y) ($x $y)))) ((a b)))
            (－ (edge a b))
            (test (collapse (? (edge $x $y) ($x $y))) ()))
     True)

;＋* is the bulk add: a whole expression of atoms in one crossing, MORK
;parsing the batch itself rather than the engine handing them over one at a
;time.
!(if (file-exists "./extensions/mork/mork_ffi/target/release/libmork_ffi.so")
     (progn (＋* ((edge a b) (edge b c) (edge c d)))
            (test (sort-atom (collapse (? (edge $x $y) ($x $y))))
                  ((a b) (b c) (c d))))
     True)

;`mork-add-atoms` is the operation under ＋*, taking the space explicitly, and
;`mork-flush` makes queued additions visible without performing another
;operation.
!(if (file-exists "./extensions/mork/mork_ffi/target/release/libmork_ffi.so")
     (progn (mork-add-atoms &mork ((tag 1) (tag 2)))
            (mork-flush &mork)
            (test (sort-atom (collapse (? (tag $n) $n))) (1 2)))
     True)

;~> is the transform, and it is MORK's own MM2 calculus rather than a MeTTa
;rewrite: the head is a conjunction of patterns and the body is an output
;block of additions and removals. It writes one (exec 0 head body) atom and
;then runs a step.
!(if (file-exists "./extensions/mork/mork_ffi/target/release/libmork_ffi.so")
     (progn (~> (, (edge $x $y)) (O (+ (path $x $y))))
            (test (sort-atom (collapse (? (path $x $y) ($x $y))))
                  ((a b) (b c) (c d))))
     True)

;`mm2-exec` is the step itself, and a transform that both removes and adds is
;how a rule REPLACES facts rather than accumulating them.
!(if (file-exists "./extensions/mork/mork_ffi/target/release/libmork_ffi.so")
     (progn (~> (, (path $x $y)) (O (- (path $x $y)) (+ (route $x $y))))
            (mm2-exec &mork 1)
            (test (sort-atom (collapse (? (route $x $y) ($x $y))))
                  ((a b) (b c) (c d)))
            (test (collapse (? (path $x $y) ($x $y))) ()))
     True)

;Cleaning up after itself, because &mork is one store for the whole process.
!(if (file-exists "./extensions/mork/mork_ffi/target/release/libmork_ffi.so")
     (progn (collapse (let ($x $y) (? (edge $x $y) ($x $y)) (－ (edge $x $y))))
            (collapse (let ($x $y) (? (route $x $y) ($x $y)) (－ (route $x $y))))
            (collapse (let $n (? (tag $n) $n) (－ (tag $n))))
            True)
     True)
