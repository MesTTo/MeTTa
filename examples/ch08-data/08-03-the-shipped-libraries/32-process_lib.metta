; Purpose: running a program with an argument vector, and watching one that outlives
; the call.
; [tested: sh test.sh examples/ch08-data/08-03-the-shipped-libraries/32-process_lib.metta; commit=WORKTREE].
!(import! &self (library lib_process))

; A run answers (process-result Code Output Error): the exit code as a Number and
; both streams as Strings. The program is named and the arguments are a COLLECTION,
; so nothing in them can become a second command.
!(test (process-run! "echo" ("hi")) (process-result 0 "hi\n" ""))
!(test (process-run! "echo" ("one" "two")) (process-result 0 "one two\n" ""))
!(test (process-run! "true" ()) (process-result 0 "" ""))

; A nonzero exit is a STATUS and not an error, because a program that ran and failed
; is not the same as one that could not run.
!(test (process-run! "false" ()) (process-result 1 "" ""))
!(test (index-atom (process-run! "sh" ("-c" "exit 7")) 1) 7)

; Both streams are captured separately, which is what lets a program's diagnostics be
; read apart from its output.
!(test (process-run! "sh" ("-c" "echo out; echo err 1>&2; exit 3"))
       (process-result 3 "out\n" "err\n"))

; An argument is never parsed: this file name would be two commands to a shell, and
; here it is one argument, so `echo` prints it and nothing runs.
!(test (process-run! "echo" ("; echo hacked")) (process-result 0 "; echo hacked\n" ""))
; Running a shell is the caller's own choice, and it says so in the program's name.
!(test (process-run! "sh" ("-c" "echo shell")) (process-result 0 "shell\n" ""))

; A program that reads its input is fed without a temporary file, and the stream is
; closed so it sees the end.
!(test (process-run-input! "cat" () "fed") (process-result 0 "fed" ""))
!(test (process-run-input! "wc" ("-c") "1234") (process-result 0 "4\n" ""))

; A program that could not be launched is a refusal naming it, which is the one thing
; that is not a status.
!(test (if-error (catch (process-run! "no_such_program_anywhere" ())) refused fine) refused)
; A path with a separator is a path rather than a PATH search, and a missing one is
; the same refusal.
!(test (if-error (catch (process-run! "/no/such/binary" ())) refused fine) refused)

; A started process is the caller's: it answers an identifier, `process-status` asks
; without waiting, and `process-wait!` answers the code. This one ends by itself.
!(bind! &quick (process-start! "true" ()))
!(test (> &quick 0) True)
!(test (process-wait! &quick) 0)
; Waiting twice is a refusal, because the host has already forgotten the process.
!(test (if-error (catch (process-wait! &quick)) refused fine) refused)

; A process that outlives the call is signalled, and a signalled program answers the
; negative of its signal number, which is what every shell reports.
!(bind! &sleeper (process-start! "sleep" ("30")))
!(test (process-status &sleeper) running)
!(test (process-signal! &sleeper term) True)
!(test (process-wait! &sleeper) -15)

; Every signal the library sends is data, and one it does not know is refused with
; all four listed.
!(test (process-signals) (term kill int hup))
!(test (if-error (catch (process-signal! 1 nosuch)) refused fine) refused)

; The refusals for what is not a program, not a vector and not a process.
!(test (if-error (catch (process-run! "echo" "not a collection")) refused fine) refused)
!(test (if-error (catch (process-run! "echo" ((nested)))) refused fine) refused)
!(test (if-error (catch (process-run! 7 ())) refused fine) refused)
!(test (if-error (catch (process-wait! "not a process")) refused fine) refused)
