;The rest of lib_torch's surface: construction, the four elementwise
;operations, a reduction, and the two activations. `08-torch_lib.metta`
;covers matmul, sum, shape and autograd, and it is skipped outright because
;CI has no PyTorch; this file asks instead, so it RUNS wherever torch is
;importable and announces its skip where it is not.
!(import! &self (library lib_torch))

;Whether torch is importable is a question about the Python side, and the
;answer is recorded once as an atom so every guard below is a match rather
;than a repeated import attempt.
!(add-reduct &torch-status
             (available (if-error (catch (py-call (torch.zeros 1))) no yes)))
!(if (== (match &torch-status (available $v) $v) no)
     (println! "SKIPPED torch-library-surface: torch is not importable from this interpreter")
     True)

;The four constructors. Each is one `py-call`, so the tensor that comes back
;is a Python object held as a grounded atom and `torch-tolist` is the exit
;back to MeTTa data.
!(if (== (match &torch-status (available $v) $v) yes)
     (progn (test (torch-tolist (torch-zeros 3)) (0.0 0.0 0.0))
            (test (torch-tolist (torch-ones 3)) (1.0 1.0 1.0))
            (test (torch-tolist (torch-arange 4)) (0 1 2 3))
            (test (size-atom (torch-tolist (torch-randn 5))) 5))
     True)

;`torch-randn` draws from a normal distribution, so the one claim that does
;not depend on the draw is that two of them differ.
!(if (== (match &torch-status (available $v) $v) yes)
     (test (== (torch-tolist (torch-randn 8)) (torch-tolist (torch-randn 8)))
           False)
     True)

;The four elementwise operations, each broadcasting a scalar the way torch
;does, so a number and a tensor is a legal pair.
!(if (== (match &torch-status (available $v) $v) yes)
     (progn (test (torch-tolist (torch-add (torch-tensor (1.0 2.0))
                                           (torch-tensor (10.0 20.0))))
                  (11.0 22.0))
            (test (torch-tolist (torch-sub (torch-tensor (10.0 20.0))
                                           (torch-tensor (1.0 2.0))))
                  (9.0 18.0))
            (test (torch-tolist (torch-mul (torch-tensor (2.0 3.0))
                                           (torch-tensor (4.0 5.0))))
                  (8.0 15.0))
            (test (torch-tolist (torch-div (torch-tensor (10.0 20.0))
                                           (torch-tensor (4.0 5.0))))
                  (2.5 4.0)))
     True)

;`torch-mean` is a reduction, so it answers a zero-dimensional tensor and
;`torch-item` is what takes the number out of one.
!(if (== (match &torch-status (available $v) $v) yes)
     (progn (test (torch-item (torch-mean (torch-tensor (1.0 2.0 3.0)))) 2.0)
            (test (torch-item (torch-mean (torch-ones 4))) 1.0))
     True)

;The two activations, on the values that pin their shape: relu is the hinge
;at zero and sigmoid is a half at zero.
!(if (== (match &torch-status (available $v) $v) yes)
     (progn (test (torch-tolist (torch-relu (torch-tensor (-2.0 0.0 3.0))))
                  (0.0 0.0 3.0))
            (test (torch-item (torch-sigmoid (torch-tensor 0.0))) 0.5))
     True)

;They compose the way any other function does, which is the point of the
;library being MeTTa equations over `py-call` rather than a Python module
;with a MeTTa face: a pipeline is an ordinary nested call. The comparison is
;a tolerance because torch's default tensor is float32 and MeTTa's number is
;a double, so a third is not the same third on both sides.
!(if (== (match &torch-status (available $v) $v) yes)
     (test (< (abs-math (- (torch-item
                             (torch-mean
                               (torch-relu (torch-sub (torch-tensor (1.0 2.0 3.0))
                                                      (torch-tensor (2.0 2.0 2.0))))))
                           (/ 1.0 3.0)))
              0.000001)
           True)
     True)
