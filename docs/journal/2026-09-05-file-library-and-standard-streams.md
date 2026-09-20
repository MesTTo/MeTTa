# File library and standard streams
Goal: expose directory creation, file copy, queryable metadata, lexical paths, standard streams and process exit to MeTTa programs.
Constraint: retain the existing library import shape and classify each operation by the five-rank effect lattice.

## 2026-09-05
Tried: `sh tools/run.sh ai-tmp/ai-library-baseline.metta` returned each requested operation as unevaluated data, including `(exit! 17)`, and exited zero. The file library already handles text and line spaces.
Tried: a subprocess running `catch(halt(17),_,writeln(caught))` printed `caught` but still exited 17 under SWI 10.1.13. Catching the unwind does not cancel process termination.
Decided: extend `lib_file`; lexical path operations follow SWI `directory_file_path/3`, `file_directory_name/2`, `file_base_name/2` and `file_name_extension/3`. They inspect only arguments and are `pureStructural`. Directory enumeration and existence tests are deterministic state reads and are `readOnlyLookup`.
Decided: `make-dir!` creates missing parents, `delete-dir!` removes an empty directory, and `copy-file!` copies bytes to a staging file beside the destination before renaming. Copy follows the stream ownership pattern in SWI `library(filesex)` and the staged publication pattern of atomic file replacement. Staging in a directory acquired by `make_directory/1` avoids opening an attacker-created temporary filename and keeps rename on the destination filesystem. A failed copy keeps an existing destination intact; cleanup removes the staging directory.
Decided: `file-metadata!` returns a native space of `(kind file|directory)`, `(size Bytes)` for files and `(modified Seconds)` atoms. Creating that snapshot is `writesState`; the bytes are never hidden in a host object.
Decided: `stderr!` writes text and flushes `user_error`; `stdin-to-string!` consumes `user_input` to EOF; `exit!` validates an integer 0 through 255 and calls `halt/1`. These process-facing operations are `oracleIO`. Exit is deliberately process termination, including an embedding process, and is tested only in subprocesses.
Rejected: treating filesystem access as uniformly `oracleIO`, because deterministic reads, mutation and lexical construction have different observable effects. Revisit if the lattice's published meaning changes.
Rejected: copying directly into the destination, because SWI `copy_file/2` opens it before opening the source and can truncate it on an unreadable source or a partial-write failure.
Prior art: SWI `library(filesex)`, installed SWI 10.1.13 source SHA-256 `e2dbbe944a947188461df6e4c2d6b58e9a46a0fb7efae22351eb0a9d5069259b`; https://www.swi-prolog.org/pldoc/man?section=files and https://www.swi-prolog.org/pldoc/man?section=toplevel. The source was read for path semantics, recursive directory creation and nested stream cleanup. Local semantic/history searches found existing file/line-space work, but no implementation of the requested operations.
Open: verification results will be appended after implementation.

Verification: `lib_file_surface` passed 11 tests plus 18 parameterized cases. Python process tests passed 3 cases; both new shell examples passed. The tests compare lexical operations with SWI, copy binary bytes, preserve a destination after missing-source and source-close failures, remove staging on publication failure, query metadata fields, verify named permission refusals, and check subprocess stdin/stderr/exit behavior.
Tried: independent fault injection made source `close/1` throw after the initial copy implementation had renamed the destination. Moved both stream cleanup boundaries before rename; the permanent `source_close_failure_preserves_destination` regression now passes.
Tried: replacing `copy-file!/3` with an unconditional no-op exposed a vacuous exception assertion. Added `nonvar/1` assertions before matching both caught errors.
Verification: jscpd found zero clones in the changed file/CSV surface. The requested ruff, artifact-paths, llms and llms-selftest lanes passed. The nested worktree layout initially broke existing sibling-path assumptions; moving the worktree beside the main checkout restored the expected layout without changing tracked gate code.
Verification: the broad Python run found stale generated API/library reference pages, which were regenerated through `reference.py --write` and `libdoc.py --write`. After worktree relocation, stale pytest bytecode retained the old `co_filename`, making `inspect.getsource` fail with `OSError: could not get source code`; a named test reproduced alone. Removing only generated `__pycache__` directories repaired source lookup. The C binding also required a rebuild because its build deliberately embeds the checkout path. Neither repair changed runtime source.
Tried: the public missing-file exception carried its name and remedy but began with SWI's `Unknown error term`. Added native error-message clauses for the three file refusal families so the public diagnostic reads as a named error rather than an unknown Prolog term.

## 2026-09-05, process control in the parity reporter

Tried: the complete gate reported the standard-streams example as an engine
error, `unwind(halt(0))`, although the engine and Python processes both exited
zero. The reporter's catch handler printed `ANSWER-ERROR` before SWI rethrew
the process-control exception.

Decided: rethrow `unwind/1` before rendering application errors. SWI reserves
that wrapper for process and thread control; its catch recovery runs before
the runtime rethrows it. The immutable source is SWI-Prolog
`fc7ef84b949378b729052c3ade79c90ce5416abb`, `man/builtin.plx`, section
`unwind-exceptions`. Changing the example's exit or suppressing ordinary
errors would change the observation being compared.

Verified: the two `test_process_exit_is_not_an_answer_error` cases failed
with the original reporter on `ANSWER-ERROR unwind(halt(0))` and
`ANSWER-ERROR unwind(halt(7))`. After the repair, both preserve their exact
exit status and emit no error marker. Running
`sh extensions/python/test.sh tests/repository/test_example_parity.py`
passes all 20 cases with the maintained Python interpreter.
