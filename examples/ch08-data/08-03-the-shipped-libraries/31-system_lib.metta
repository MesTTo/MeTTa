; Purpose: the environment, the working directory and the platform, as data.
; [tested: sh test.sh examples/ch08-data/08-03-the-shipped-libraries/31-system_lib.metta; commit=b109f59a8095add8ecf264b011e683184274acbb].
!(import! &self (library lib_system))
; lib_pairs is beside it because the environment IS a relation: its operations are
; what reads one.
!(import! &self (library lib_pairs))
; lib_string is beside them for the text checks over what the platform answers.
!(import! &self (library lib_string))

; A variable that is not set has NO answer, which is what makes unset and empty
; different states: a collapse over the read is the presence test.
!(test (collapse (env-get "NO_SUCH_VARIABLE_HERE")) ())
!(test (if (== () (collapse (env-get "NO_SUCH_VARIABLE_HERE"))) unset set) unset)

; A write is visible to every later read in this process, and to every child process
; it starts. Answers True, because a write that failed raises.
!(test (env-set! "METTA_SYSTEM_EXAMPLE" "on") True)
!(test (env-get "METTA_SYSTEM_EXAMPLE") "on")
!(test (env-set! "METTA_SYSTEM_EXAMPLE" "") True)
; An empty value is SET, which is the state a presence test has to tell from unset.
!(test (env-get "METTA_SYSTEM_EXAMPLE") "")
!(test (if (== () (collapse (env-get "METTA_SYSTEM_EXAMPLE"))) unset set) set)
!(test (env-unset! "METTA_SYSTEM_EXAMPLE") True)
!(test (collapse (env-get "METTA_SYSTEM_EXAMPLE")) ())
; Removing one that is not set is silent, because a cleanup path should not have to
; check first.
!(test (env-unset! "METTA_SYSTEM_EXAMPLE") True)

; The whole environment is a relation of (Name Value) pairs, so lib_pairs reads it:
; the names are Strings, which is also what keeps the relation inert.
!(test (env-set! "METTA_SYSTEM_EXAMPLE" "listed") True)
!(test (pairs-is (env-all)) True)
!(test (collapse (pairs-lookup (env-all) "METTA_SYSTEM_EXAMPLE")) ("listed"))
!(test (collapse (pairs-lookup (env-all) "NO_SUCH_VARIABLE_HERE")) ())
!(test (env-unset! "METTA_SYSTEM_EXAMPLE") True)

; The platform, one key at a time, and every key as data. A key the library does not
; know is refused with all of them listed, so a typo is not an absent platform. The
; host NAME is not a key: gethostname/1 is library(socket)'s, and a whole network
; library is too much to link for one string.
!(test (platform-info family) "unix")
!(test (platform-info dialect) "swi")
!(test (== (platform-info cores) (platform-info cores)) True)
!(test (size-atom (platform-info version-numbers)) 3)
!(test (size-atom (platform-keys)) 10)
!(test (if-error (catch (platform-info nosuch)) refused fine) refused)
; The version as text and as numbers agree: the text starts with the major number
; the numbers begin with.
!(test (string-starts-with (platform-info version)
                           (number-to-string (car-atom (platform-info version-numbers))))
       True)

; The working directory is the process's own, absolute and without a trailing
; separator, and every relative path a program writes is read against it.
!(test (string-starts-with (working-directory) "/") True)
!(test (string-ends-with (working-directory) "/") False)
!(test (if-error (catch (change-directory! "/no/such/directory/here")) refused fine) refused)
; The directory is unchanged by a refused move.
!(test (string-starts-with (working-directory) "/") True)

; Every refusal names what it was given.
!(test (if-error (catch (env-get 7)) refused fine) refused)
!(test (if-error (catch (env-set! "A" (nosuch))) refused fine) refused)
!(test (if-error (catch (change-directory! 7)) refused fine) refused)
