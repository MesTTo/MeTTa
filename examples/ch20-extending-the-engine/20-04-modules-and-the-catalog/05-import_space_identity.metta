; Purpose: demonstrate independent source imports, queryable records and undo.
; [tested: sh run.sh examples/ch20-extending-the-engine/20-04-modules-and-the-catalog/05-import_space_identity.metta; commit=4f2d6c0f8eb293b73f8dde30a1c84e24834f7393]
!(import! &self (library lib_import))

!(bind! &import-space-a (new-space))
!(bind! &import-space-b (new-space))

!(import! &import-space-a _fixtures/imports/overhaul/space_payload)
!(import! &import-space-b _fixtures/imports/overhaul/space_payload)

!(test (collapse (match &import-space-a (import-space-marker) present)) (present))
!(test (collapse (match &import-space-b (import-space-marker) present)) (present))

; Each importing space runs its own copy, once: one identity per space.
!(test (collapse (metta (import-space-function) %Undefined% &import-space-a)) (one-result))
!(test (collapse (metta (import-space-function) %Undefined% &import-space-b)) (one-result))

; The caller did not import this payload, so its function name stays data:
; an alias import admits nothing into the running context.
!(test (collapse (import-space-function)) ((import-space-function)))

; Imports are data in a read-only view of the receiving space's records.
!(test (collapse (match (imports &import-space-a) (import $path) imported))
       (imported))

; A caller's equal atom survives undo of the source's own occurrence.
!(add-atom &import-space-a (import-space-marker))
!(unimport! &import-space-a _fixtures/imports/overhaul/space_payload)
!(test (collapse (match &import-space-a (import-space-marker) present)) (present))
!(test (collapse (match (imports &import-space-a) (import $path) $path)) ())

; Undo is idempotent, and the other space still owns its own program.
!(unimport! &import-space-a _fixtures/imports/overhaul/space_payload)
!(test (collapse (metta (import-space-function) %Undefined% &import-space-b)) (one-result))
!(test (collapse (metta (import-space-function) %Undefined% &import-space-a)) ((import-space-function)))

; Re-import restores one source occurrence beside the caller's atom.
!(import! &import-space-a _fixtures/imports/overhaul/space_payload)
!(test (collapse (match &import-space-a (import-space-marker) present)) (present present))
