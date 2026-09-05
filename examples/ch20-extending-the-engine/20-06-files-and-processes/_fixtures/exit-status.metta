; Purpose: verify a nonzero exit in an isolated child process.
; [tested: test_exit_is_process_termination_even_inside_catch; commit=504f8dddfa890ced97e795a13ab10e239b1de2ce]
!(import! &self (library lib_file))
!(catch (exit! 17) $error (stderr! "caught"))
!(stderr! "unreachable")
