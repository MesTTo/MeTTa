; Purpose: demonstrate standard streams and explicit process termination.
; [tested: test_standard_streams_and_explicit_exit; commit=504f8dddfa890ced97e795a13ab10e239b1de2ce]
!(import! &self (library lib_file))

; In the shell suite stdin is already at EOF. With a pipe, the text is echoed
; to stderr, exactly, including embedded newlines and Unicode characters.
!(bind! &input (stdin-to-string!))
!(test (stderr! &input) True)
!(test (stderr! "standard streams complete\n") True)
; This ends the entire process. It does not return a value to MeTTa.
!(exit! 0)
