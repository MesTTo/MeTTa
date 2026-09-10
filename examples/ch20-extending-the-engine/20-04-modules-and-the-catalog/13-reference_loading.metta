; Purpose: demonstrate lazy/background policies and effect admission.
; [tested: examples/ch20-extending-the-engine/20-04-modules-and-the-catalog/13-reference_loading.metta; commit=90ba93eb8f6e98ebfefc55416859bf13de6a8427].

; Lazy publishes the manifest and compiles an equation when first called.
!(pragma! load lazy)
(from ../examples/ch20-extending-the-engine/20-04-modules-and-the-catalog/_fixtures/references/maps (prefix lazy.))
!(test (lazy.map-value 41) 42)
!(test (lazy.map-label) label)

; Background uses a worker. A call waits until its defining home is ready.
!(pragma! load background)
(from ../examples/ch20-extending-the-engine/20-04-modules-and-the-catalog/_fixtures/references/background)
!(test (background-value 41) 42)

; Both policies refuse an effectful initializer before it executes. The
; error names the source, the println! form and the eager-load remedy.
!(test (case (catch (add-atom &self (from ../examples/ch20-extending-the-engine/20-04-modules-and-the-catalog/_fixtures/references/effectful)))
             (((Error $form $reason) refused))) refused)
!(pragma! load lazy)
!(test (case (catch (add-atom &self (from ../examples/ch20-extending-the-engine/20-04-modules-and-the-catalog/_fixtures/references/effectful)))
             (((Error $form $reason) refused))) refused)
!(pragma! load eager)
