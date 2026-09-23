<!-- Purpose: the ledger of host defects this engine works around, one entry per defect, keyed so a site comment can name it and the host-workarounds lane can hold the two in step. -->
# Host workarounds

The engine runs on hosts it does not own: SWI-Prolog, Janus, the C toolchain
and the operating system. When a host does something the engine has to work
around, the workaround is recorded twice and checked in both directions:

- at the site, a comment line in the file's own comment syntax of the shape
  `Workaround: <key> - <what this site does instead>`, followed by whatever
  explanation the site needs, where `<key>` is a heading in this file;
- here, one entry per defect under `## <key>`, with the fields below.

`tests/checks/check_host_workarounds.py`, the `host-workarounds` gate lane,
refuses a site whose key has no entry, an entry no site carries, an entry
missing a field, and a malformed site line. It then RUNS every entry's
reproduction on the host this tree runs on and reads the last line it prints:
`present` means the defect is still there and the workaround still earns its
keep; `absent` means the host no longer has it, and the lane fails naming
every site to lift, which is the signal to remove the workaround and the
entry together. Anything else is a broken reproduction and fails too. A
reproduction is a `.pl` file run as `swipl -q -f none -s FILE -g main -t halt`
or a `.sh` file run as `sh FILE`, under `bounded.sh`, with
`HOST_WORKAROUND_SCRATCH` naming a fresh directory of its own and `SWIPL`
naming the interpreter.

The fields, one per line, continuation lines indented:

- `Host:` the host and version the defect was measured on, with the source
  location that shows it.
- `Defect:` what the host does, stated as a mechanism.
- `Reproduction:` the tracked file whose last output line answers `present`
  or `absent`.
- `Workaround:` the shape every site uses, when there is one; each site
  states its own.
- `Lifted when:` the host change that makes the reproduction answer `absent`.
- `Patch:` the tracked patch the host this tree runs on is built with, when
  the defect is fixed in the host rather than worked around in the tree.
- `Record:` the journal thread that holds the evidence.

An entry lands with its first site and its reproduction in the same commit. A
site the ledger does not know is refused, and so is an entry nothing uses. The
journal keeps the history; this file holds only what is live.

An entry with `Patch:` is the dual state. Its host is built from the patched
source, so it needs no site, its reproduction must answer `absent`, and
`present` means this environment's host was built without the patch: the lane
fails naming the patch to rebuild with. The reproduction still describes the
defect as shipped, so a fresh environment learns what its host must carry.

## janus-callback-exception-leak
Host: janus-swi 1.5.3 (janus/janus.c `check_error`, the same code at upstream
  packages-swipy master b0356a162, 2026-07-28, and in swipl-devel V10.1.14's
  packages/swipy) on SWI-Prolog 10.1.13 and 10.1.14.
Defect: when a Python callback raises, `check_error` fetches the exception's
  type, value and traceback with `PyErr_Fetch` to build the
  `python_error(Class, Obj)` ball, and returns without releasing the three
  references it owns. The blobs the ball carries release theirs at atom GC;
  these never do, so every exception a callback raised stays alive for the
  process with its traceback, every frame below the callback and every local
  those frames hold. In this engine that kept a dropped space's handle, its
  lease cell and the transaction frames of each rolled-back body.
Reproduction: tests/checks/host_workarounds/janus-callback-exception-leak.sh,
  one Python child raising three exceptions inside `py_call/2`, then atom GC,
  a Prolog-to-Python call to drain the deferred releases and a Python
  collection; `present` when an instance survives.
Patch: tests/checks/host_workarounds/packages/swipy/janus-callback-exception-leak.patch,
  applied to swipl-devel's packages/swipy at the tag the seat runs (V10.1.14),
  built there against the patched SWI-Prolog (`rm -rf build; SWIPL=<its swipl>
  uv build --wheel --no-build-isolation`, a stale `build/` keeps a `_swipl`
  linked to another libswipl) and installed into the seat's interpreter with
  `uv pip install --reinstall --no-deps`; it releases the fetched references on
  every exit of `check_error`. The interpreter's `swipl` and its janus must
  resolve to that one build, or the janus reproduction answers for a host the
  engine does not run on.
Lifted when: janus-swi releases what `PyErr_Fetch` handed `check_error`; the
  entry and the patch go together once the installed janus carries that.
Record: docs/journal/2026-09-16-reclamation-counts.md, the retention bisection
  from the reclamation counts to the hidden reference and the patched build.

## swi-bound-clause-reference-ignores-snapshot
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped, this tree running on 10.1.14 built with the patch below; at fc7ef84b949378b729052c3ade79c90ce5416abb;
  src/pl-dbref.c:PL_get_clref and src/pl-comp.c:clause.
Defect: bound-reference clause/3 rejects the global CL_ERASED flag even when
  enumeration in the caller's older transaction still admits that occurrence.
  A second read can therefore lose the source or owner that the first read saw.
Reproduction: tests/checks/host_workarounds/swi-bound-clause-reference-ignores-snapshot.pl,
  an old transaction enumerates its original fact after an independently joined
  eraser, then compares bound-reference reading with retained-term decompilation.
Patch: tests/checks/host_workarounds/swi-bound-clause-reference-ignores-snapshot.patch,
  against swipl-devel V10.1.14 src/pl-comp.c: clause/3 with a bound reference
  admits an erased clause that is still visible at the caller's generation
  (`current_generation()` of its predicate), the view enumeration takes, so
  a second read returns the occurrence the first read saw. The reproduction
  answers absent and SWI's core, db, transaction and tabling groups pass.
Lifted when: SWI-Prolog as shipped reads a bound reference at the caller's
  generation, so the reproduction prints absent; the patch and the entry go
  together then.
Record: docs/journal/2026-09-15-native-owned-records.md.

## swi-cached-undefined-supervisor
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped; src/pl-proc.c:trapUndefined,
  src/pl-supervisor.c:createUndefSupervisor and src/pl-vmi.c:S_UNDEF. This
  tree runs on 10.1.14 built with the patch below.
Defect: an unsuccessful undefined-predicate hook installs an S_UNDEF
  supervisor. A later compiled call can reuse it and throw directly, bypassing
  a hook whose deferred source has become available since the first call.
Reproduction: tests/checks/host_workarounds/swi-cached-undefined-supervisor.pl,
  a failed call followed by an available loader and an explicitly qualified
  compiled caller. A fresh predicate verifies that the same loader works.
Patch: tests/checks/host_workarounds/swi-cached-undefined-supervisor.patch,
  against swipl-devel V10.1.14 src/pl-vmi.c on top of
  swi-erased-definition-bypasses-loader.patch: S_UNDEF's error case consults
  the loader once more (`trapUndefined()`) before raising, when autoloading is
  on and the system has booted, and continues into the definition it yields;
  a loader that defines nothing still raises, and the `unknown` flag's fail
  and warning cases keep their cached answer. The reproduction answers absent
  and SWI's core, db, transaction, tabling, save, files, compile, attvar and
  engines groups pass on the build.
Lifted when: SWI-Prolog as shipped consults the loader from a cached undefined
  call, so the reproduction prints absent; the patch and the entry go together
  then.
Record: docs/journal/2026-09-17-host-patches.md;
  docs/journal/2026-09-15-deferred-definitions-rearm-undefined-calls.md.
## swi-empty-indexed-snapshot
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped; src/pl-index.c,
  first_clause_guarded. This tree runs on 10.1.14 built with the patch below.
Defect: a call or an unbound clause/3 on a dynamic predicate whose current
  clause count is zero returns no clause before the caller's transaction
  generation is applied, so an older transaction loses the rows it should
  still see once the last current clause is erased, while nth_clause/3 and
  '$clause'/4 still admit them.
Reproduction: tests/checks/host_workarounds/swi-empty-indexed-snapshot.pl,
  an old transaction reads one and sixteen facts after an independently joined
  thread erases every current clause of the predicate.
Patch: tests/checks/host_workarounds/swi-empty-indexed-snapshot.patch, against
  swipl-devel V10.1.14 src/pl-index.c: when the current count is zero and the
  caller runs inside a transaction, `first_clause_guarded()` walks the
  clause list with the generation check (`next_clause_unindexed()`) instead
  of answering nothing; outside a transaction the empty answer stands, which
  undo/1's erase at the call port relies on (SWI's `undo:undo_or` and
  `undo:clauses` tests read the erase through it). SWI's core_lang,
  transaction, db and tabling groups pass on the build.
Lifted when: SWI-Prolog as shipped routes the empty-current list through the
  visibility-aware reader for a transaction, so the reproduction prints
  absent; the patch and the entry go together then.
Record: docs/journal/2026-09-17-host-patches.md, the walk and the inert
  clause it retires; docs/journal/2026-09-15-native-owned-records.md.
## swi-erased-definition-bypasses-loader
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped; src/pl-vmi.c:S_VIRGIN,
  src/pl-wam.c:getProcDefinedDefinition, src/pl-proc.c:resetProcedure and
  src/pl-supervisor.c:undefSupervisor. This tree runs on 10.1.14 built with
  the patch below.
Defect: abolish can leave erased clauses linked to a definition. S_VIRGIN
  treats the nonnull first-clause pointer as a definition and skips the loader;
  supervisor creation then sees zero live clauses and installs S_UNDEF.
  Repeating abolish resets the supervisor but retains the same condition.
Reproduction: tests/checks/host_workarounds/swi-erased-definition-bypasses-loader.pl,
  a compiled call after abolish while an earlier call retains its logical
  update view, and a tabled predicate declared ahead of its clause called
  under the debugger, the patch's own hazard. A fresh predicate verifies the
  same loader independently.
Patch: tests/checks/host_workarounds/swi-erased-definition-bypasses-loader.patch,
  against swipl-devel V10.1.14 src/pl-wam.c and src/pl-vmi.c: one test,
  `undefinedForCall()`, says a call must resolve its definition first when the
  predicate is not declared and either has no definition or is a clause
  predicate with no live clause, whatever erased clauses it still links; the
  count is read from a clause list only, never from a foreign, thread-local
  or closure definition, since a closure (pl-wrap.c) copies the wrapped
  definition and carries the count it had when it was wrapped, 0 for a
  table/1 or wrap_predicate/4 ahead of the clauses, and the debugger's and
  the alerted call port resolve closures too; the VM's call sites and
  `getProcDefinedDefinition()` use it in place of the raw first-clause
  pointer, so the loader (exception/3, autoload) is consulted for a reset
  predicate and a loader that defines nothing still ends in the undefined
  supervisor. The reproduction answers absent on both samples; SWI's core,
  db, transaction, tabling, save, files and compile groups pass on the build.
Lifted when: SWI-Prolog as shipped consults the loader for a reset predicate
  despite retained erased clauses, so the reproduction prints absent; the
  patch and the entry go together then.
Record: docs/journal/2026-09-17-host-patches.md;
  docs/journal/2026-09-15-copied-specializations-materialize-before-calls.md.
## swi-optparse-missing-value

Host: SWI-Prolog 10.1.13, library/optparse.pl:parse_options/4 at
  fc7ef84b949378b729052c3ade79c90ce5416abb.
Defect: a synthetic final empty argument makes an absent value indistinguishable
  from an explicitly supplied empty token.
Reproduction: tests/checks/host_workarounds/swi-optparse-missing-value.pl
Workaround: the private parser keeps absence distinct and refuses missing values.
Lifted when: a missing value raises after the explicit-empty control passes.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md, CLI declarations.

## swi-optparse-separator

Host: SWI-Prolog 10.1.13, library/optparse.pl:parse_args_/3 at
  fc7ef84b949378b729052c3ade79c90ce5416abb.
Defect: the double dash becomes an operand while later options still parse.
Reproduction: tests/checks/host_workarounds/swi-optparse-separator.pl
Workaround: consume the terminator and retain every following token as an operand.
Lifted when: the native parser consumes the terminator and leaves later flags literal.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md, CLI declarations.

## swi-optparse-negation

Host: SWI-Prolog 10.1.13, library/optparse.pl:parse_args_/3 at
  fc7ef84b949378b729052c3ade79c90ce5416abb.
Defect: one negated Boolean produces two false occurrences under keepall.
Reproduction: tests/checks/host_workarounds/swi-optparse-negation.pl
Workaround: recognize and consume a negated Boolean once.
Lifted when: one negated token yields one false occurrence after the explicit control passes.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md, CLI declarations.

## swi-optparse-name-grammar

Host: SWI-Prolog 10.1.13, library/optparse.pl:name_long//1 and name_char/1 at
  fc7ef84b949378b729052c3ade79c90ce5416abb.
Defect: the restrictive name grammar ignores declared digit or punctuation names
  and accepts unknown dashed tokens as operands.
Reproduction: tests/checks/host_workarounds/swi-optparse-name-grammar.pl
Workaround: match literal declared dashed names and refuse unrecognized options.
Lifted when: count2 and 9? declarations parse and the unknown --bad? token raises.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md, CLI declarations.

## swi-optparse-flag-namespace

Host: SWI-Prolog 10.1.13, library/optparse.pl:invalidate_opts_spec/2 at
  fc7ef84b949378b729052c3ade79c90ce5416abb.
Defect: uniqueness validation compares short and long names without their dash
  prefixes, rejecting separate options named -x and --x.
Reproduction: tests/checks/host_workarounds/swi-optparse-flag-namespace.pl
Workaround: validate full dashed names in the adapter and private provider.
Lifted when: distinct -x and --x declarations both parse after the disjoint control passes.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md, CLI declarations.

## swi-optparse-schema-ambiguity

Host: SWI-Prolog 10.1.13, library/optparse.pl:invalidate_opts_spec/2 at
  fc7ef84b949378b729052c3ade79c90ce5416abb.
Defect: the O1 \\= O2 guard excludes identical rows from duplicate-name detection.
Reproduction: tests/checks/host_workarounds/swi-optparse-schema-ambiguity.pl
Workaround: index each declaration, field and full flag name in call-local associations.
Lifted when: identical repeated declarations raise after the single-row control passes.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md, CLI declarations.

## swi-optparse-value-report

Host: SWI-Prolog 10.1.13, library/optparse.pl:parse_val/4 at
  fc7ef84b949378b729052c3ade79c90ce5416abb.
Defect: conversion failure prints the option name to stdout but omits it from
  the exception, so a caller cannot reliably display or retain its context.
Reproduction: tests/checks/host_workarounds/swi-optparse-value-report.pl
Workaround: include the token, declared type and original cause in the exception.
Lifted when: conversion failure prints nothing and its exception identifies count.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md, CLI declarations.

## swi-absolute-path-nul

Host: SWI-Prolog 10.1.13, absolute_file_name/3 at
  fc7ef84b949378b729052c3ade79c90ce5416abb.
Defect: canonicalization truncates an input String at NUL, producing a valid
  pathname for a different file or directory instead of preserving or refusing it.
Reproduction: tests/checks/host_workarounds/swi-absolute-path-nul.pl
Workaround: reject NUL before canonicalizing a database directory.
Lifted when: canonicalization refuses NUL or retains the complete input path.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md, Database pathname validation.

## swi-utf8-journal-repair

Host: SWI-Prolog 10.1.13, src/os/pl-stream.c:Sgetcode at
  fc7ef84b949378b729052c3ade79c90ce5416abb.
Defect: the UTF-8 reader accepts overlong sequences; other invalid sequences
  warn and substitute a character instead of refusing the input term.
Reproduction: tests/checks/host_workarounds/swi-utf8-journal-repair.pl
Workaround: validate original byte lines using csv_codec:utf8_text/2 before
  opening the journal with the host text reader. The existing codec checks
  canonical encoding and Unicode scalar values.
Lifted when: the overlong NUL raises after the canonical NUL control passes.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md, Database journal boundaries.

## swi-persistency-write-memory

Host: SWI-Prolog 10.1.13, library/persistency.pl:db_assert_sync/1 at
  fc7ef84b949378b729052c3ade79c90ce5416abb.
Defect: db_assert_sync asserts the in-memory row before opening or writing its
  journal. An append error leaves that row visible in the attachment.
Reproduction: tests/checks/host_workarounds/swi-persistency-write-memory.pl
Workaround: update and sync failures end the owning database engine and its
  attachment, so later queries refuse instead of exposing partially changed memory.
Lifted when: the failed append leaves no row after the normal reopen control passes.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md, Database ownership.

## swi-persistency-replay

Host: SWI-Prolog 10.1.13, library/persistency.pl:load_db/3 at
  fc7ef84b949378b729052c3ade79c90ce5416abb.
Defect: unsupported journal records print illegal_term and replay continues
  with later records, returning a partially interpreted store as a valid attachment.
Reproduction: tests/checks/host_workarounds/swi-persistency-replay.pl
Workaround: validate the entire journal before attachment; reject unknown or
  malformed records with the journal path and an explicit repair instruction.
Lifted when: native attachment raises for the unknown record after its valid control passes.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md, Database ownership.

## swi-persistency-detach

Host: SWI-Prolog 10.1.13, library/persistency.pl:db_sync/2 detach at
  fc7ef84b949378b729052c3ade79c90ce5416abb.
Defect: detach retracts db_stream before close; a close exception skips removal
  of db_file and db_option registrations. A second detach drains those records.
Reproduction: tests/checks/host_workarounds/swi-persistency-detach.pl
Workaround: retry detach only after its close fails, then propagate the close
  error alongside any earlier operation or subsequent cleanup error.
Lifted when: failed close leaves no attachment registration after a normal detach control passes.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md, Database ownership.

## swi-persistency-stream-owner

Host: SWI-Prolog 10.1.13, library/persistency.pl:persistent/2 and db_open_file/3 at
  fc7ef84b949378b729052c3ade79c90ce5416abb.
Defect: native journal opening precedes db_stream registration. An interruption
  between them leaves a stream that db_detach cannot discover or close.
Reproduction: tests/checks/host_workarounds/swi-persistency-stream-owner.pl
Workaround: after native detach, the exclusive store owner closes remaining
  streams naming its journal and retains their errors beside the operation outcome.
Lifted when: interruption after native open leaves no journal stream after detach.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md, Database cancellation ownership.

## swi-relative-compound-source
Host: SWI-Prolog 10.1.13; boot/init.pl:$register_resolved_source_path/2 at
  https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/boot/init.pl#L2571-L2580.
Defect: every compound file specification enters the global resolved-source
  cache keyed by specification and dialect, including relative /(support,native).
  A later importing directory therefore reuses the first directory's file.
Reproduction: tests/checks/host_workarounds/swi-relative-compound-source.pl,
  whose quoted atom control loads both providers while the compound path loads
  only the first, using two independent directories for each form.
Workaround: use quoted pathname atoms for relative native-provider imports.
Lifted when: both forms load both directory-local providers and the reproduction
  answers absent.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md,
  native source isolation and CMake evidence.

## libarchive-zip-unicode-crc

Host: libarchive 3.8.5, archive_read_support_format_zip.c:process_extra at
  dd897a78c662a2c7a003e7ec158cea7909557bee.
Defect: a Unicode path extra field's CRC is compared with the already-converted
  pathname. CP437-to-UTF8 conversion changes those bytes and invalidates a valid
  field, so the reader silently returns the legacy name instead.
Reproduction: tests/checks/host_workarounds/libarchive-zip-unicode-crc.sh
Workaround: a private provider build saves the original filename CRC before
  conversion and uses it for the extra-field check. Payload checks remain enabled.
Lifted when: explicit CP437 conversion retains the valid Unicode extra-field name
  after the default reader and ordinary CP437/UTF8 controls pass.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md.

## libarchive-zip-default-charset

Host: libarchive 3.8.5, archive_read_support_format_zip.c:zip_read_local_file_header
  at dd897a78c662a2c7a003e7ec158cea7909557bee.
Defect: unflagged CP437 names use the ambient locale by default. Under UTF8,
  the valid ZIP name caf\x82 has no wide representation despite ARCHIVE_OK.
Reproduction: tests/checks/host_workarounds/libarchive-zip-default-charset.sh
Workaround: set the ZIP hdrcharset option to CP437. The native UTF8 flag and
  Unicode extra-field handling still take precedence.
Lifted when: the default reader returns café after explicit CP437 and UTF8 controls pass.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md.

## swi-archive-null-pathname

Host: SWI-Prolog 10.1.13, packages-archive archive_next_header at
  13a3f4af8f8219e10faf4895ce9fb189bc6aaefd.
Defect: archive_entry_pathname_w may return NULL after ARCHIVE_OK. Passing it
  to PL_unify_wchars with length -1 calls wcslen(NULL) and crashes the process.
Reproduction: tests/checks/host_workarounds/swi-archive-null-pathname.sh
Workaround: a private copy of the binding raises representation_error(archive_pathname)
  before attempting the wide-string conversion.
Lifted when: the native reader decodes or explicitly refuses the legacy name
  after its Unicode control, instead of terminating with SIGSEGV.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md.

## libarchive-utf8-locale

Host: SWI-Prolog 10.1.13, packages-archive archive_next_header at
  13a3f4af8f8219e10faf4895ce9fb189bc6aaefd, using libarchive 3.8.5.
Defect: reading a Unicode pathname converts through the current C character
  locale and raises archive_error(84, ...) under C, even for explicitly UTF8 ZIP/TAR.
Reproduction: tests/checks/host_workarounds/libarchive-utf8-locale.pl
Workaround: enter a thread-local UTF8 character locale for the complete archive
  operation and restore the caller's locale after its streams and archives close.
Lifted when: the same Unicode name reads under C after its UTF8 control passes.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md.

## libarchive-gzip-trailer

Host: SWI-Prolog 10.1.13 library(archive); libarchive consume_trailer at
  c719b9b1f56621d92063a85361cc8d114f5575a9.
Defect: the gzip filter consumes CRC and length fields without checking them;
  its optional header CRC is also unchecked.
Reproduction: tests/checks/host_workarounds/libarchive-gzip-trailer.pl
Workaround: decode each gzip layer through zopen and read it completely before
  the archive operation can publish results. Other filters retain native decoding.
Lifted when: the valid member reads correctly and the corrupt CRC raises.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md.

## swi-archive-input-exception

Host: SWI-Prolog 10.1.13, packages-archive libarchive_close_cb at
  13a3f4af8f8219e10faf4895ce9fb189bc6aaefd.
Defect: closing an archive whose parent decoder raised ignores the failure of
  PL_release_stream, returning with an exception pending and losing its original
  read error. The runtime prints a foreign-predicate protocol violation.
Reproduction: tests/checks/host_workarounds/swi-archive-input-exception.pl
Workaround: close and validate a decoded intermediate file before opening the
  next archive reader; remove each consumed intermediate during the traversal.
Lifted when: corrupt input raises and archive_close leaves no exception pending.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md.

## swi-tcp-ipv6-peer

Host: SWI-Prolog10.1.13, packages-clib socket.c:pl_accept at
  a69cf00dcf0dd2e3ac1aa9565fbebf4aa4ceb5da.
Defect: native accept uses sockaddr_in and IPv4 address formatting for an IPv6
  connection, returning ip(0,0,0,0) for the IPv6 loopback peer.
Reproduction: tests/checks/host_workarounds/swi-tcp-ipv6-peer.pl
Workaround: query the connected descriptor with getpeername, sockaddr_storage
  and getnameinfo to retain its family and actual source port.
Lifted when: native accept returns the complete IPv6 loopback address.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md.

## swi-udp-ipv6-address

Host: SWI-Prolog10.1.13, packages-clib socket.c:unify_address at
  a69cf00dcf0dd2e3ac1aa9565fbebf4aa4ceb5da.
Defect: udp_receive passes its IPv6 sockaddr to an address formatter that handles
  only AF_INET and aborts the process in its default branch.
Reproduction: tests/checks/host_workarounds/swi-udp-ipv6-address.pl
Workaround: receive complete datagrams with the OS API and format either address
  family through getnameinfo, retaining the sender's actual port.
Lifted when: the native IPv6 packet and sender endpoint pass in the isolated child.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md.

## swi-uri-empty-query

Host: SWI-Prolog10.1.13, packages-clib uri.c:add_query_and_fragment,
  upstream a69cf00dcf0dd2e3ac1aa9565fbebf4aa4ceb5da.
Defect: native composition adds the query delimiter only for a nonempty query,
  collapsing a present-empty component into an absent one.
Reproduction: tests/checks/host_workarounds/swi-uri-empty-query.pl
Workaround: compose all defined components using RFC3986 section5.3.
Lifted when: the native builder retains the question mark for an empty query.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md.

## swi-uri-empty-base-path

Host: SWI-Prolog10.1.13, packages-clib uri.c:resolve_guarded,
  upstream a69cf00dcf0dd2e3ac1aa9565fbebf4aa4ceb5da.
Defect: the authority-with-empty-path branch creates a merged buffer but does
  not assign its range to the target path, so resolving g against http://a loses g.
Reproduction: tests/checks/host_workarounds/swi-uri-empty-base-path.pl
Workaround: RFC3986 section5.2.3 prepends slash and retains the merged path.
Lifted when: resolving g against http://a returns http://a/g.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md.

## swi-uri-urn-resolution

Host: SWI-Prolog10.1.13, packages-clib uri.c:resolve_guarded/ranges_in_charbuf,
  upstream a69cf00dcf0dd2e3ac1aa9565fbebf4aa4ceb5da.
Defect: native absolute URN parsing stores nid/nss, while resolution emits only
  the generic path slot; an absolute URN becomes urn:.
Reproduction: tests/checks/host_workarounds/swi-uri-urn-resolution.pl
Workaround: carry the entire opaque path through generic RFC3986 resolution.
Lifted when: resolving an absolute URN retains its namespace content.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md.

## swi-uri-normalization-data

Host: SWI-Prolog10.1.13, packages-clib uri.c:normalize_in_charbuf,
  upstream a69cf00dcf0dd2e3ac1aa9565fbebf4aa4ceb5da.
Defect: unconditional lowercasing includes case-sensitive userinfo and URN
  content; liberal percent decoding rewrites arbitrary octets through Unicode.
Reproduction: tests/checks/host_workarounds/swi-uri-normalization-data.pl
Workaround: normalize unreserved bytes and scheme/host case only, retaining
  userinfo case and every other encoded octet.
Lifted when: all identifying-case and octet fixtures retain their data.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md.

## swi-http-stop-ack

Host: SWI-Prolog10.1.13, packages-http thread_httpd.pl:http_stop_server/2,
  upstream8e6b758778aed1986f81a4a7a8efeb475faa35aa.
Defect: the timeout-and-connect shutdown branch joins the accept thread but
  leaves its untagged http_stopped acknowledgement in the caller mailbox. A
  later stop can consume it and join a listener it has not woken.
Reproduction: tests/checks/host_workarounds/swi-http-stop-ack.pl
Workaround: run each native stop in a fresh thread, joining it in cleanup so
  its mailbox and leftover acknowledgement die with that operation.
Lifted when: the forced timeout branch leaves no http_stopped message after
  native stop returns, so the reproduction prints absent.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md,
  2026-09-12 HTTP design and verification.

## swi-http-partial-startup

Host: SWI-Prolog10.1.13, packages-http thread_httpd.pl:http_server/2,
  create_workers/1 and create_server/3, upstream8e6b758778aed1986f81a4a7a8efeb475faa35aa.
Defect: workers and their message queue are created before the accept thread;
  an exception creating that thread leaves those resources alive.
Reproduction: tests/checks/host_workarounds/swi-http-partial-startup.pl
Workaround: own the bound listener before starting, and release its fresh worker
  queue and socket if native startup fails. Successful servers use native stop.
Lifted when: the injected accept-thread alias collision leaves no worker or
  message queue, so the reproduction prints absent.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md,
  2026-09-12 HTTP design and verification.

## swi-cleanup-window
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped; `setup_call_cleanup/3` is
  `sig_atomic(Setup), '$call_cleanup'` (boot/init.pl:680-682). This tree
  runs on 10.1.14 built with the patch below.
Defect: `raiseInferenceLimitException()` (src/pl-prims.c) raises inside
  `sig_atomic/1`'s critical region, so an inference limit that trips at the
  call port of Setup's own goal is delivered when the region ends, between
  Setup's effects and the cleanup's registration in `I_CALLCLEANUP`, and no
  cleanup is owed; a cleanup of several goals can be cut between its goals
  the same way. A signal cannot do this, because `sig_atomic/1` defers it;
  the inference check did not.
Reproduction: tests/checks/host_workarounds/swi-cleanup-window.pl, a budget
  sweep over an asserted guard; budget 4 of 64 leaks on 10.1.13 and 10.1.14
  as shipped, none with the patch.
Patch: tests/checks/host_workarounds/swi-cleanup-window.patch, against
  swipl-devel V10.1.14 src/pl-prims.c: `raiseInferenceLimitException()`
  returns without raising while `LD->critical` is set, so the limit is
  honoured the way a signal is, at the first call port after the region. A
  region is one indivisible step to the limit: a limited goal whose last step
  is a region completes with `!`, as one whose last step is a long foreign
  call already does, and a cleanup handler, which `callCleanupHandler()` runs
  between `startCritical()` and `endCritical()`, is never cut between its
  goals. SWI's own suite passes on the build (87 of 88, `pldoc:man_links`
  needs the documentation the build omits; `tests/core_lang/test_inflimit.pl`
  among the passes).
Lifted when: SWI-Prolog as shipped registers the cleanup before the call port
  that follows Setup, or its inference check honours the atomic region as the
  patch makes it; the patch and the entry go together then. The Workaround
  field goes with the last lifted site.
Record: docs/journal/2026-09-17-host-patches.md, the budget sweep and the
  traced run that placed the exception inside `asserta/2`;
  docs/journal/2026-09-07-every-intermittent-root-caused.md, the
  20,000-budget sweep; docs/journal/2026-09-10-every-host-workaround-is-commented.md.
  docs/journal/2026-09-11-source-owned-publication.md records the scoped
  publication differential and its inference-budget sweep.

## swi-transaction-enumerator-repeats-parent
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped; `src/pl-transaction.c:current_transaction/1`.
  This tree runs on 10.1.14 built with the patch below.
Defect: a successful redo retains the same parent stack pointer, so enumerating
  two nested transactions returns the parent indefinitely.
Reproduction: tests/checks/host_workarounds/swi-transaction-enumerator-repeats-parent.pl,
  which asks for at most three answers from exactly two nested transactions.
Patch: tests/checks/host_workarounds/swi-transaction-enumerator-repeats-parent.patch,
  against swipl-devel V10.1.14 src/pl-transaction.c: the redo case takes the
  entry's id and advances to its parent before answering, so the saved redo
  pointer is the next ancestor and the last one answers deterministically;
  three nested transactions enumerate exactly three ids, and SWI's
  transaction group passes on the build.
Lifted when: SWI-Prolog as shipped advances the parent pointer on redo, so the
  reproduction prints absent; the patch and the entry go together then.
Record: docs/journal/2026-09-17-host-patches.md; docs/journal/2026-09-11-classes-on-metta.md,
  transaction existence does not enumerate ancestors;
  docs/journal/2026-09-05-function-free-materialization.md.
## swi-ugraphs-implicit-append
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped, this tree running on 10.1.14 built with the patch below;, library/ugraphs.pl:460 (`top_sort/2`); the same
  line at swipl-devel V10.1.14.
Defect: the library declares its lists dependency as `append/3` alone and
  `top_sort/2` calls `append/2`, which only the library index supplies. With
  autoload off (run.sh `NO_AUTOLOAD=1`, the engine's `no-autoload` gate) the
  first `top_sort/2`, which the engine's release plan
  (`metta_space_release_plan/2`) calls, raises
  `existence_error(procedure, ugraphs:append/2)`.
Reproduction: tests/checks/host_workarounds/swi-ugraphs-implicit-append.pl,
  `top_sort/2` with autoload off; `present` when it raises the existence
  error.
Patch: tests/checks/host_workarounds/swi-ugraphs-implicit-append.patch, against
  swipl-devel V10.1.14 library/ugraphs.pl: the lists dependency declares
  `append/2` beside `append/3`, so `top_sort/2` resolves it with autoload off.
  The reproduction answers absent.
Lifted when: ugraphs.pl as shipped declares `append/2`; the reproduction then answers
  `absent` and the patch and the entry go together.
Record: docs/journal/2026-09-16-exec-modules-never-autoload.md.

## swi-wrapper-roundtrip-merges-closures
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped, this tree running on 10.1.14 built with the patch below;; `library/prolog_wrap.pl:body_closure/3` at
  fc7ef84b949378b729052c3ade79c90ce5416abb.
Defect: `current_predicate_wrapper/4` replaces every native closure in a
  wrapper body with the same variable. Reinstalling its documented round-trip
  result makes other retained definitions call the wrapper's own definition.
Reproduction: tests/checks/host_workarounds/swi-wrapper-roundtrip-merges-closures.pl,
  an own/other union becomes own/own after the public round trip.
Patch: tests/checks/host_workarounds/swi-wrapper-roundtrip-merges-closures.patch,
  against swipl-devel V10.1.14 library/prolog_wrap.pl: `body_closure//`
  replaces only a closure over the wrapped predicate itself, identified
  through `'$closure_predicate'/2` against the predicate's implementation
  module and name/arity, so closures over other predicates keep their
  identity on the round trip. The reproduction answers absent and SWI's
  library group passes.
Lifted when: the public round trip as shipped preserves distinct closure identities
  and the reproduction prints absent; the patch and the entry go together
  then.
Record: docs/journal/2026-09-11-classes-on-metta.md, binding ownership spans the
  native transition and its closure reconstruction follow-up.

## swi-locale-default-encoding
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped, where the default source
  encoding follows `setlocale()`; this tree runs on 10.1.14 built with the
  patch below.
Defect: a boot under `LC_ALL=C` reads a UTF-8 source as single bytes and
  compiles each non-ASCII character to U+FFFD. A `.qlf` written by that boot
  outlives the locale, since its mtime is newer than every source, so every
  later boot under a correct locale serves the poisoned compile; and an ASCII
  output stream does not fail on the mark, it escapes it.
Reproduction: tests/checks/host_workarounds/swi-locale-default-encoding.sh,
  which reads an atom written as U+2705 back under `LC_ALL=C`.
Patch: tests/checks/host_workarounds/swi-locale-default-encoding.patch, against
  swipl-devel V10.1.14 src/os/pl-ctype.c: `init_locale()` reads and writes
  UTF-8 when the C library's LC_CTYPE is the C or POSIX locale, as Python's
  UTF-8 mode does for the same case, so a UTF-8 source compiles the same
  under every locale; the `encoding` flag reads `utf8` under `LC_ALL=C`.
  The reproduction answers absent and SWI's core, files, charset and library
  groups pass.
Lifted when: SWI-Prolog as shipped reads UTF-8 under the C locale; the reproduction
  then answers absent and the patch and the entry go together.
Record: docs/journal/2026-09-07-the-gate-green-again.md, the artifact that
  outlived its locale.

## swi-qlf-extension-spec
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped, this tree running on 10.1.14 built with the patch below;; `'$qlf_file'/5` in boot/init.pl decides by the
  shape of the spec.
Defect: a `load_files/2` spec that names its `.pl` extension compiles from
  source whatever `qcompile(auto)` says; only a bare stem reaches the artifact
  rule, which loads the `.qlf` when it is fresh and version-compatible and
  rewrites it when it is stale and the directory is writable.
Reproduction: tests/checks/host_workarounds/swi-qlf-extension-spec.sh, which
  loads one unit as `'one.pl'` and another as `two` and looks for the
  artifacts.
Patch: tests/checks/host_workarounds/swi-qlf-extension-spec.patch, against
  swipl-devel V10.1.14 boot/init.pl: `'$qlf_file'/5` keeps loading a
  spec that names its Prolog extension from source when only the process-wide
  `qcompile` flag is on, which keeps that flag from writing an artifact beside
  every file a program names by path, and lets the spec reach the artifact
  rule like a stem when the call carries its own `qcompile` option. A first
  shape that let the flag reach it too wrote artifacts beside the engine's
  backends and the binding's shim during the umbrella boot. The reproduction
  answers absent and SWI's core, files, save and compile groups pass.
Lifted when: the artifact rule as shipped applies to an extension-bearing spec too; the
  reproduction then prints absent and the patch and the entry go together.
Record: docs/journal/2026-09-09-runtime-units-compile-beside-their-source.md.

## swi-qlf-failed-include-source-module
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped; boot/init.pl:$consult_file and
  src/pl-qlf.c:loadPredicate. This tree runs on 10.1.14 built with the patch
  below.
Defect: a failed nested include under qcompile(auto) leaves the source module
  changed, because `'$consult_file'/5` restores it only on success. QLF replay
  then defines the next predicate in that module. A strong import there makes
  lookupProcedureToDefine return null, which loadPredicate dereferences,
  producing signal 11, or an assertion in whatever the corrupted state reaches
  first on a build with assertions.
Reproduction: tests/checks/host_workarounds/swi-qlf-failed-include-source-module.sh,
  a module that imports an export into user before a failed nested include.
  The same QLF loads in the control with its optional entry disabled; replay
  with the broken entry enabled exits 139, or 134 with the crash reporter's
  `stack_avail___LD` assertion, on the host as shipped. No engine or Janus is
  loaded.
Patch: tests/checks/host_workarounds/swi-qlf-failed-include-source-module.patch,
  against swipl-devel V10.1.14: `'$consult_file'/5` restores the source module
  in a cleanup, on failure and exception as on success, and `loadPredicate()`
  returns the pending permission error instead of dereferencing a null
  procedure. Replay of the reproduction's QLF finishes (`safe-replay`) three
  runs out of three, and SWI's core, save, files and compile groups pass on
  the build.
Lifted when: SWI-Prolog as shipped restores the source module after a failed
  consult and refuses a null procedure in the QLF loader, so the reproduction
  prints absent; the patch and the entry go together then.
Record: docs/journal/2026-09-17-host-patches.md; docs/journal/2026-09-11-the-engine-and-packaging-lanes-after-the-wave.md.

## swi-named-listener-replacement-lock
Host: SWI-Prolog 10.1.13, src/pl-event.c:add_event_hook at
  fc7ef84b949378b729052c3ade79c90ce5416abb, lines 145-159.
Defect: src/pl-event.c:add_event_hook returns at line 155 after replacing
  a named event handler, before UNLOCK_LIST at line 159 releases its
  recursive list mutex. Its owning thread can continue, but another thread
  blocks while registering, invoking or removing a handler on that channel.
Reproduction: tests/checks/host_workarounds/swi-named-listener-replacement-lock.sh,
  a completed single-registration control followed by a replacement whose
  worker announces its arrival before trying to unregister the handler.
Workaround: every listener is registered once, unnamed, through
  engine/host_listeners.pl, so the replacement branch is never entered.
Lifted when: add_event_hook releases the event-list mutex before returning
  from the named-handler replacement branch. The once-only door stays after
  that host repair, because a listener is process-wide by design.
Record: docs/journal/2026-09-09-import-and-module-semantics.md, candidate
  admission and concurrent rollback-listener evidence;
  docs/journal/2026-09-13-one-door-for-host-listeners.md.

## swi-event-list-lock-spans-listener-callbacks
Host: SWI-Prolog 10.1.13, src/pl-event.c at
  fc7ef84b949378b729052c3ade79c90ce5416abb: call_event_list holds the
  channel's recursive list lock across every callback it delivers (lines
  415-470) and link_event takes the same lock to register (lines 99-110).
Defect: a callback runs with its channel's event-list lock held, so a callback
  that waits for a mutex some other thread holds while that thread registers
  on the same channel never returns, and neither does the registration: two
  threads in futex_do_wait and a process that reports nothing. Four hangs in
  this tree were that cycle, each through a different engine mutex.
Reproduction: tests/checks/host_workarounds/swi-event-list-lock-spans-listener-callbacks.sh,
  a control whose worker registers after releasing the mutex, then the same
  registration made while holding the mutex the callback waits for.
Workaround: every registration goes through engine/host_listeners.pl, which
  holds no mutex while it registers, so no mutex is ever ordered before a
  channel's event-list lock; tests/prolog/lock_order.pl records that lock as
  one more mutex and the plunit lane fails on any cycle through it.
Lifted when: call_event_list copies the callback list and releases the lock
  before calling into Prolog, at which point the reproduction's worker joins.
  The door stays: registering once, unnamed, is the shape the entry above
  still needs.
Record: docs/journal/2026-09-13-one-door-for-host-listeners.md.

## swi-query-frame-discarded-on-engine-destroy
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped; `PL_close_query` in
  src/pl-wam.c closes the foreign frame before discarding the outer query
  frame, while `prolog_frame_attribute/3` marks inspected ancestors for
  `frame_finished`. This tree runs on 10.1.14 built with the patch below.
Defect: destroying a yielded engine delivers the event for that discarded
  outer frame. Opening the listener's query aborts on the host's assertion
  `PL_open_query: Assertion failed: (void*)fli_context > (void*)environment_frame`,
  exit 134 in the plain-host reproduction. The same path under the engine
  exits 139 when the crash reporter itself segfaults. A build without
  assertions reads a discarded frame instead; exit 0 there is not proof
  that the defect has gone.
Reproduction: tests/checks/host_workarounds/swi-query-frame-discarded-on-engine-destroy.sh,
  a frozen unsafe ancestor walk inside a plain-SWI transaction, followed by
  an engine yield and destruction. It loads no repository engine predicates.
  Exit 139, or 134 with the exact assertion above, answers `present`; exit 0
  answers `absent`; every other result is a broken reproduction.
Patch: tests/checks/host_workarounds/swi-query-frame-discarded-on-engine-destroy.patch,
  against swipl-devel V10.1.14 src/pl-wam.c: `discard_query()` makes the
  query frame the environment before it notifies, since every frame above it
  is discarded and a yielded engine's environment lies in that region, and
  `frameFinished()` runs the listener inside a foreign frame of its own above
  the finished frame, as the cleanup handler already does. The reproduction
  answers absent three runs of three, and SWI's core, engines, debug, GC,
  signals, db and transaction groups pass on the build.
Lifted when: SWI-Prolog as shipped delivers `frame_finished` for a discarded
  query frame from a sane environment and foreign frame, so the reproduction
  prints absent; the patch and the entry go together then.
Record: docs/journal/2026-09-17-host-patches.md; docs/journal/2026-09-09-the-binding-collapse.md,
  transfer bound watches before native query destruction.
## swi-thread-join-detach-window
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped, and upstream master at
  73a6750 (fetched 2026-09-18); `detach_engine` in src/pl-thread.c zeroes
  the detached engine's `PL_thread_info_t.tid` and `PL_set_engine` detaches
  the CALLING thread's own engine for the duration of `engine_create/3` and
  `engine_destroy/1`, while `thread_join/2` reads `info->tid` once, with no
  `has_tid` test, and hands it to `pthread_timedjoin_np`. This tree runs on
  10.1.14 built with the patch below.
Defect: joining a thread that is inside `engine_create/3` or
  `engine_destroy/1`, which any worker evaluating MeTTa can be since a merged
  match opens one engine per space, calls `pthread_timedjoin_np(0, ...)` and
  glibc dereferences a null `struct pthread`: SIGSEGV in
  `__pthread_clockjoin_ex`, exit 139. Until 2026-09-18 lib_thread polled the
  joinee's status with a sleep backoff before every join
  (docs/journal/2026-09-06-materialization-segv.md), about ten inferences a
  wakeup, which was part of every threaded twin's spread.
Reproduction: tests/checks/host_workarounds/swi-thread-join-detach-window.sh,
  the destroy mode of tests/prolog/probes/engine_join_window.pl frozen: a
  worker parked inside `engine_destroy/1` by a message queue and joined from
  the main thread with plain `thread_join/2`. Exit 139 answers `present`;
  exit 0, the join returning `true` after a detached sleeper releases the
  worker, answers `absent`; every other result is a broken reproduction.
Patch: tests/checks/host_workarounds/swi-thread-join-detach-window.patch,
  against swipl-devel V10.1.14 src/pl-thread.c: `detach_engine` clears the
  thread id only of an interactor (`is_engine`), which has no OS thread while
  detached; a real thread keeps running on the same pthread while its own
  engine is detached, so its identity survives and `thread_join/2` always
  joins the right thread. `has_tid` is cleared as before, so the alert and
  signal paths that test it are unchanged.
Lifted when: SWI-Prolog as shipped joins a thread inside its engine-switch
  window, so the reproduction prints absent; the patch and the entry go
  together then, and lib_thread's join door stays a plain `thread_join/2`.
Record: docs/journal/2026-09-18-schedule-independent-counters.md;
  docs/journal/2026-09-06-materialization-segv.md, closed at the joiner;
  docs/journal/2026-09-06-swi-defects-to-report-upstream.md, item 1.
## swi-file-search-cache-autoload
Host: janus-swi 1.5.3, the same janus.pl in swipl-devel V10.1.14's
  packages/swipy, on SWI-Prolog 10.1.13 and 10.1.14 as shipped; the venv's
  janus wheel is built from that tree with the patch below.
Defect: the first failed text query walks the file search path when the
  dependency's cached path has expired. The same query therefore pays a
  different inference cost according to earlier wall-clock state, despite
  performing the same program work. `file_search_cache_time=0` disables the
  cache before either the hit or sweep clauses; it reproduces the uncached
  walk, not a cache-expiry sweep.
Reproduction: tests/checks/host_workarounds/swi-file-search-cache-autoload.sh,
  four fresh Python Janus processes with no engine loaded. The first failed
  text query costs 1,281 with the primed default cache and 1,507 with the cache
  disabled at zero; explicitly importing `maplist/2` gives 8 in both arms.
  The native count surrounds the query, and each child restores the default
  flag value 10. This is the zero-setting uncached-walk control.
Patch: tests/checks/host_workarounds/packages/swipy/swi-file-search-cache-autoload.patch, against
  swipl-devel V10.1.14 packages/swipy janus/janus.pl: the library imports its
  lists, apply, error, dicts and option dependencies when it loads instead of
  declaring them for lazy autoloading, so the failed-query branch of
  `py_call/4` resolves nothing at its first use. The reproduction answers
  absent.
Lifted when: janus.pl as shipped imports its failure-path dependencies eagerly; the
  reproduction then answers absent and the patch and the entry go together.
Record: docs/journal/2026-09-09-the-binding-collapse.md, first-use dependency
  attribution and deterministic 226/229 controls. The separate file-search
  cache maintenance sweep belongs to its own host-workaround entry.
## swi-gc-in-frame-finished-listener-clears-a-live-slot
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped, this tree running on 10.1.14
  built with the patch below; src/pl-gc.c setStartOfVMI() and
  clearUninitialisedVarsFrame(), src/pl-vmi.c B_UNIFY_FF, B_UNIFY_FV,
  B_UNIFY_FC, B_ARG_CF, A_ADD_FC and exit_continue, src/pl-wam.c
  frameFinished(), at V10.1.14.
Defect: the collector reads a saved PC at the end of an instruction as that
  instruction in progress and starts its walk there, so the instruction's
  first-var operand counts as unwritten and is cleared. That is right for an
  instruction that requested stack space after reading its operands. It is
  wrong after a call from inside the instruction returns to the same PC:
  under the debugger, B_UNIFY_FF, B_UNIFY_FV, B_UNIFY_VF and B_UNIFY_FC call
  =/2, B_ARG_CF and B_ARG_VF call arg/3 and A_ADD_FC calls is/2, each after
  writing its first var, and the deterministic exit of that callee resumes
  the caller in the VM registers before frameFinished() runs the
  frame_finished listeners (exit_continue). prolog_frame_attribute/3 marks
  the callee's frame for those notifications when the debugger references
  it at the call port. Collection in the listener then clears the completed
  slot: the arithmetic goals in translator:translate_clause_impl/4's slot 27
  disappeared at saved PC 209, and every sample of the reproduction answers
  a fresh variable.
Reproduction: tests/checks/host_workarounds/swi-gc-in-frame-finished-listener-clears-a-live-slot.pl,
  plain SWI, a frame_finished listener that calls garbage_collect/0, a trace
  hook that references every call-port frame, and one sample per
  instruction. The unreferenced control must keep every value; `present`
  iff a referenced sample answers something other than its expected value.
Patch: tests/checks/host_workarounds/swi-gc-in-frame-finished-listener-clears-a-live-slot.patch,
  against swipl-devel V10.1.14 src/pl-gc.c and src/pl-vmi.c: a saved PC
  exactly at the end of one of those seven instructions is a return address,
  so setStartOfVMI() starts the walk after it, as the walk of a parent frame
  starts at its return address. The rule holds because none of the seven
  requests space once its operands are read with the first var unwritten:
  B_UNIFY_FC reserves its cell before reading its operands as B_UNIFY_FV and
  B_UNIFY_FF do, and A_ADD_FC reserves the debugger's cells before its
  operands and makes its result slot a variable before the two inline
  requests that need one. The reproduction answers absent for all seven
  samples and SWI's basic, core, db, attvar, debug, GC, compile, tabling,
  transaction and engines groups pass.
Lifted when: the collector as shipped starts after a completed first-var
  instruction whose call returned to its end; the reproduction then answers
  absent and the patch and the entry go together.
Record: docs/journal/2026-09-10-the-observed-equation-loses-its-arithmetic.md
  and docs/journal/2026-09-17-host-patches.md.

## swi-file-search-cache-sweep
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped; boot/init.pl's file-search
  cache. This tree runs on 10.1.14 built with the patch below.
Defect: the first library load after the file-search cache expires runs
  gc_file_search_cache/1, removing other expired lookup entries. The next
  lookup pays resolution and insertion work instead of the warm-cache cost;
  wall-clock state changes measured Prolog inferences. A zero timeout bypasses
  insertion and the sweep, so it tests an uncached walk rather than this event.
Reproduction: tests/checks/host_workarounds/swi-file-search-cache-sweep.pl,
  ages cache and sweep timestamps under a positive timeout, loads a previously
  unloaded library, and compares the next lookup with two warm lookups.
Patch: tests/checks/host_workarounds/swi-file-search-cache-sweep.patch, against
  swipl-devel V10.1.14 boot/init.pl: a cached path stays a hit while its file
  still satisfies the conditions, whatever its age, and the sweep removes
  only entries that are old and whose file is gone; the flag disables the
  cache at 0 and otherwise paces the sweep. The key carries the expanded
  search path, so a changed path is a new key; a file that appears earlier in
  an unchanged path is seen after the cache is cleared or the process
  restarts, as Python's import cache does for a directory it has already
  listed. The reproduction answers absent and SWI's core, files, library,
  load and save groups pass.
Lifted when: an aged lookup as shipped costs what a warm one costs; the reproduction
  then answers absent and the patch and the entry go together.
Record: docs/journal/2026-09-07-merged-tree-reconciliations.md, the cache-age
  controls and the 2026-09-10 host-reproduction section.

## swi-inherited-empty-predicate-retry
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped; S_VIRGIN in src/pl-vmi.c.
  This tree runs on 10.1.14 built with the patch below.
Defect: resolving a first inherited call retries and increments inferences
  when the provider's first-clause pointer is nonnull, even when every clause
  is retired. Clause collection clears that pointer and removes the retry,
  so identical logical state has a different first-call cost by GC schedule.
Reproduction: tests/checks/host_workarounds/swi-inherited-empty-predicate-retry.pl,
  compares inherited first/warm calls with retained and collected clauses in
  fresh plain-SWI processes, with direct provider calls controlling both arms.
Patch: tests/checks/host_workarounds/swi-erased-definition-bypasses-loader.patch,
  the same change: S_VIRGIN decides whether a call must resolve its definition
  by `undefinedForCall()`, a clause predicate's live clause count rather than
  its first-clause pointer, so a provider whose clauses are all retired reads
  the same whether or not clause collection has run; inherited first-call
  counts agree in both states and the reproduction answers absent.
Lifted when: SWI-Prolog as shipped reads the live count there, so the
  reproduction prints absent; the patch and the entry go together then.
Record: docs/journal/2026-09-17-host-patches.md;
  docs/journal/2026-09-07-merged-tree-reconciliations.md, the 2026-09-11
  buffered VM trace and unchanged-body foldall controls.
## swi-concurrent-import-removal-resets-provider
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped, this tree running on 10.1.14 built with the patch below; at fc7ef84b949378b729052c3ade79c90ce5416abb;
  src/pl-proc.c:388-416, 1510-1544 and 2871-2935.
Defect: abolishProcedure replaces an imported Procedure's Definition with an
  empty child definition, then resetProcedure reads the Procedure again.
  Concurrent autoImport can install the provider between those operations.
  The reset then clears the provider's clause count and meta declaration
  while its original clauses remain. The two operations use different locks.
Reproduction: tests/checks/host_workarounds/swi-concurrent-import-removal-resets-provider.pl,
  a compiled child call racing with one million imported abolish operations.
  It loads no engine. The original provider clause survives but its metadata
  disappears; the last line is present.
Patch: tests/checks/host_workarounds/swi-concurrent-import-removal-resets-provider.patch,
  against swipl-devel V10.1.14 src/pl-proc.c: `abolishProcedure()` resets the
  definition it captured and locked, the empty child before publishing it
  and the local definition in the other branches, never `proc->definition`
  read again after a concurrent `autoImport()` may have relinked the
  provider. The reproduction, a million abolishes against a million reads,
  keeps the provider's clause and meta declaration and answers absent; SWI's
  core, db, library and engines groups pass.
Lifted when: SWI-Prolog as shipped resets only the captured definition, so the
  reproduction prints absent; the patch and the entry go together then.
Record: docs/journal/2026-09-11-classes-on-metta.md, import repair retains an
  unchanged provider.

## swi-nested-retract-loses-outer-assert
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped, and upstream master at
  2026-09-16; src/pl-transaction.c, merge_clause_tables. This tree runs on
  10.1.14 built with the patch below.
Defect: committing a nested erase of a clause asserted by its outer transaction
  overwrites the outer GEN_ASSERTA or GEN_ASSERTZ entry with GEN_NESTED_RETRACT.
  Outer rollback restores the erased generation instead of discarding the
  assertion. The clause is invisible outside a transaction but reappears when
  a later transaction advances past its creation generation.
Reproduction: tests/checks/host_workarounds/swi-nested-retract-loses-outer-assert.pl,
  an outer assert, committed inner erase, failed outer transaction, then 100
  unrelated assertions in a later transaction. No engine is loaded.
Patch: tests/checks/host_workarounds/swi-nested-retract-loses-outer-assert.patch,
  against swipl-devel V10.1.14 src/pl-transaction.c: when the nested table
  brings a nested retract of a clause the outer table holds as asserted,
  `merge_clause_tables()` keeps the outer assert marker and completes the
  retract bookkeeping the nested retract deferred (`retract_clause()`), so the
  clause is an in-transaction assertion that was retracted, which the outer
  commit discards and the outer rollback does not revive; the nested commit
  merges its clause table before its predicate table, because that bookkeeping
  records the predicate as modified in the nested table and the predicate
  merge carries it to the parent (merging predicates first destroyed the
  table the bookkeeping then wrote to, a crash). Verified by the
  reproduction and eight scenarios (asserta and retract/1, a grandchild
  erase, a child assert with a grandchild erase under an outer commit, a
  rolled-back nested erase, a pre-existing row, clause GC afterwards); SWI's
  own suite passes on the build (87 of 88, `pldoc:man_links` needs the
  documentation the build omits; tests/transaction among the passes).
Lifted when: SWI-Prolog as shipped merges a nested retract without losing the
  outer assertion, so the reproduction prints absent; the patch and the entry
  go together then.
Record: docs/journal/2026-09-17-host-patches.md, the merge fix and the
  ownership journal it retires; docs/journal/2026-09-11-classes-on-metta.md,
  repository ownership after nested rollback.

## swi-autoload-cut-installs-the-undefined-supervisor
Host: SWI-Prolog 10.1.13; trapUndefined and autoLoader in src/pl-proc.c:2962-3047,
  the undefined supervisor in src/pl-supervisor.c:235-240 and 433-443,
  raiseInferenceLimitException in src/pl-prims.c:5676-5718,
  https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-proc.c#L2962-L3047.
Defect: the trap for an undefined predicate runs `'$undefined_procedure'/4` as
  a query and reads its answer, fail, error or retry. A query that raised has
  no answer, so the trap installs the undefined supervisor on the definition
  and lets the ball go on. Every later compiled call that is not the last call
  of its clause runs that supervisor and never traps again, so the predicate
  answers "Unknown procedure" for the rest of the process although its library
  is loaded; a last call, a meta-call, an explicit import or a defining assert
  resolve it, which is why the symptom hides in library code. An inference
  limit, an alarm or an interrupt landing inside a first-use resolution is
  enough, and the resolution's absolute_file_name/3 walk is hundreds of
  inferences wide. When the ball is the inference limit and the trip landed
  after the definition arrived, the trap continues into the resolved
  predicate with the ball pending and the first foreign call drops it, so the
  bound is lost instead.
Reproduction: tests/checks/host_workarounds/swi-autoload-cut-installs-the-undefined-supervisor.pl,
  a budget sweep over fresh modules whose clause calls sum_list/2 before
  another goal, each bounded on its first call; every budget from 1 to 64
  leaves the predicate undefined on 10.1.13.
Workaround: engine/metta/limits.pl wraps `'$undefined_procedure'/4`: the
  resolution runs under a catch, a cut resolution is run again once the limit
  has disarmed, the second attempt's answer is returned, and the ball is
  re-raised through thread_signal/2 from the next call port. A cut on the
  query's own entry ports, which precede the catch, is repaired from
  prolog:prolog_exception_hook/5 by asking for the resolution again from the
  thread's next safe point; only the inference limit's ball is repaired there,
  because reading the frame the ball surfaces at marks it and a time limit or
  interrupt can surface at an engine's outer query frame
  (swi-query-frame-discarded-on-engine-destroy).
Patch: tests/checks/host_workarounds/swi-cached-undefined-supervisor.patch,
  the supervisor this trap installs is the cached S_UNDEF supervisor that
  patch makes consult the loader once more before raising, so a resolution a
  bound cut is retried by the next compiled call; the reproduction answers
  absent on the build that carries it (the host-workarounds lane,
  2026-09-18, on the tree that merged the trunk). The wrapper in
  engine/metta/limits.pl stays until the trunk's sites are lifted together.
Lifted when: trapUndefined leaves the definition untouched when the
  resolution query raised, so the next call traps and resolves again, and the
  pending ball is raised instead of the resolved predicate being entered.
Record: docs/journal/2026-09-07-every-intermittent-root-caused.md, the
  2026-09-11 section; docs/journal/2026-09-11-the-end-of-wave-battery.md.

## swi-findall-bag-push-window
Host: SWI-Prolog 10.1.13; cleanup_bag/2 in boot/bags.pl:104-106, findnsols2/5
  in boot/bags.pl:147-152, the bag stack in src/pl-bag.c:157-190 and 366-385,
  https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/boot/bags.pl#L94-L112.
Defect: findall/4 pushes its bag with `'$new_findall_bag'` and registers
  `'$destroy_findall_bag'` one call port later, and findnsols2/5 does the same
  through setup_call_cleanup/3. An inference limit that trips on that port
  unwinds with the bag on the thread's bag stack and no cleanup owed
  (swi-cleanup-window is the same host rule seen from the engine's own state).
  Every later answer of the enclosing findall is then added to the stale bag,
  and the enclosing findall collects its own bag, which is short. The
  cleanup's own entry port is a second window of the same shape.
Reproduction: tests/checks/host_workarounds/swi-findall-bag-push-window.pl,
  a findall over two hundred budgets each bounding a goal that runs a nested
  findall; 13 of 200 are collected on 10.1.13, and a thrown ball through the
  same nesting collects 200.
Patch: tests/checks/host_workarounds/swi-cleanup-window.patch, whose
  deferred inference check is exactly the "honours the atomic region" below:
  the bag is pushed in a Setup, so the window between the push and the
  cleanup's registration is the cleanup window. The reproduction answers
  absent on the build that carries it and present on stock 10.1.13
  [measured 2026-09-20].
Lifted when: the inference-limit check honours the atomic region, or
  cleanup_bag/2 and findnsols2/5 register their cleanup before the push and
  the push records itself. MET by the patch above, and engine/metta/limits.pl's
  wrappers were LIFTED on 2026-09-20. They wrapped `'$bags':cleanup_bag/2` and
  `'$bags':findnsols2/5` from the first `call_with_inference_limit/3` of the
  process on, and on the patched host they had stopped being redundant and
  become wrong: with them installed, a nested `call_with_inference_limit`
  inside a live evaluation emptied the ENCLOSING collection, which is the same
  short-answer-set symptom this entry describes, produced by the cure rather
  than the defect. Budgets from 100 to 20,000,000 behaved alike, so no budget
  was being spent; it was the replacement bag discipline meeting the patched
  host's deferral [measured 2026-09-20:
  `!(test (grammar-parse (alt (integer) (lit "x")) "7") 7)` answers `()` under
  METTA_VERIFY_SPECIALIZATIONS with the wrappers and `7` without them, and it
  is what held the spec-differential lane red over two examples]. Lifting also
  returns findall to the host's own cost, the one inference per findall this
  entry used to charge.
Record: docs/journal/2026-09-11-the-end-of-wave-battery.md, the section on the
  final gate's reds; docs/journal/2026-09-07-every-intermittent-root-caused.md.

## swi-profile-report-divides-by-zero-samples
Host: SWI-Prolog 10.1.13; profile/2 in library/prolog_profile.pl:107-118, its
  report in the same file at 146-168 and time_data/7 at 204-210, the primitive
  in src/pl-prof.c:942-970,
  https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/library/prolog_profile.pl#L104-L210.
Defect: profile/2 is `call_cleanup('$profile'(Goal, How, Ports, Rate),
  show_profile(Options))`, and the report divides each predicate's ticks by
  the total tick count, and the net time by it again. A goal that finishes
  inside one sampling period (5 ms by default) leaves the total at zero, so
  the report raises `evaluation_error(zero_divisor)` as the CLEANUP of a goal
  that already answered, and the ball unwinds the goal's bindings on its way
  out: the answer is gone before any catcher can read it. `top(0)`, which asks
  for no rows at all, does not avoid the division. The report also consults
  `prolog:show_profile_hook/1` first, which SWI autoloads from xpce whenever
  DISPLAY is set.
Reproduction: tests/checks/host_workarounds/swi-profile-report-divides-by-zero-samples.pl,
  `profile(X is 1 + 1, [top(0)])` with the report's output swallowed; on
  10.1.13 it raises with samples=0 and X unbound at the catcher.
Workaround: extensions/python/metta/_binding/profiling.pl calls the primitive
  profile/2 itself calls, `'$profile'(Goal, cputime, Ports, Rate)` with the
  flags profile/2 reads for its defaults, and never the report; the rows come
  from profile_data/1, whose own division is guarded and answers an empty
  profile when nothing was sampled.
Lifted when: profile/2's report treats a zero tick count as an empty profile,
  or the division moves behind the `top(0)` option.
Record: docs/journal/2026-09-11-the-end-of-wave-battery.md, the 2026-09-12
  section on the publication merge.

## swi-string-nul-membership
Host: SWI-Prolog 10.1.13 at fc7ef84b949378b729052c3ade79c90ce5416abb;
  src/pl-string.c:split_string uses text_chr for separator and padding membership.
Defect: NUL-terminated membership lookup counts the terminator as a member even
  of an empty set. Splitting the codes [97,0,98] with comma returns ["a","b"],
  losing NUL. Line and wrapping utilities that use this splitter inherit the defect.
Reproduction: tests/checks/host_workarounds/swi-string-nul-membership.pl,
  compares a normal split control with the embedded-NUL input.
Workaround: the String provider scans complete codepoint sets and explicit input
  bounds. Line and layout adapters use that corrected boundary. UUID validation
  requires exact reserialization of the separators after the host split.
Lifted when: the host splitter preserves NUL unless explicitly listed in the
  separator or padding set. The private KMP search and exact edit-distance
  provider remain necessary for their independent operations and complexity.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md.

## swi-isub-nul-lengths
Host: SWI-Prolog 10.1.13, packages-nlp dd69ae95342d7a0429a0f8bcc7deab2bd514570e;
  pl-isub.c:get_chars uses wcscpy/wcsdup and isub.c:isub_score_inplace uses wcslen.
Defect: ISub compares only the prefix before NUL. Codes [97,0,98] against "a"
  score 1 at threshold zero, instead of the complete-input score 0.55.
Reproduction: tests/checks/host_workarounds/swi-isub-nul-lengths.pl,
  checks the identity control and the complete-input score.
Workaround: the String provider owns codepoint vectors and passes explicit
  lengths through its licensed ISub adaptation.
Lifted when: the host ISub boundary and core preserve complete strings and the
  reproduction returns the complete-input score. Re-evaluate the adapter's
  scalar, length and cancellation contracts before replacing it with the host.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md.

## swi-isub-variable-options
Host: SWI-Prolog 10.1.13, packages-nlp dd69ae95342d7a0429a0f8bcc7deab2bd514570e;
  isub.pl:user:goal_expansion/2 calls isub_options/3 on variable options.
Defect: normalize_int/2 binds a variable Bool to true while compiling its caller.
  A predicate intended to accept either Bool is compiled for true only. A wholly
  variable options list instead raises from option/3 during compilation.
Reproduction: tests/checks/host_workarounds/swi-isub-variable-options.pl,
  compares compiled options with the public predicate called at runtime.
Workaround: the String differential oracle uses call/5 so all option combinations
  reach the public host predicate at runtime.
Lifted when: compilation preserves option variables and both Bool branches agree
  with the runtime control. Restore the direct oracle call after that proof.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md.

## swi-rational-subnormal-rounding
Host: SWI-Prolog 10.1.13, fc7ef84b949378b729052c3ade79c90ce5416abb;
  src/pl-gmp.c:mpq_to_double rounds a significand before ldexp.
Defect: converting ((1<<54)+1) rdiv (1<<1129) returns zero although its exact
  value is above half the smallest subnormal and must round to 2^-1074.
Reproduction: tests/checks/host_workarounds/swi-rational-subnormal-rounding.pl,
  compares normal and exact subnormal controls with the above-midpoint value.
Workaround: Vector rounds integer quotient/remainder at the final binary64
  quantum and converts only an already representable dyadic with float/1.
  Math converts scalar numbers through Vector's multiplication by a floating unit.
Lifted when: the host's rational conversion rounds subnormals once and the
  reproduction returns absent. Preserve Vector's explicit IEEE overflow and
  signed-underflow policy when replacing the conversion.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md.

## swi-libbf-powm-unreduced
Host: SWI-Prolog 10.1.14 built without GMP (`-DUSE_GMP=OFF`), which is how
  tools/wasm-host builds the WebAssembly host; `mpz_powm()` in
  src/libbf/bf_gmp.c:306, the LibBF emulation of GMP's, unchanged on
  swipl-devel master in September 2026. A build linking GMP, as the native
  host does, never compiles it.
Defect: the emulation sets its result to 1 and reduces it by the modulus only
  inside the loop over the exponent's bits, so an exponent of 0 returns 1
  unreduced: `powm(42, 0, 1)` is 1 where GMP answers `1 mod 1`, 0. lib_math's
  `(math-power-mod 42 0 1)` answered 1 on the WebAssembly host and 0 natively.
Reproduction: tests/checks/host_workarounds/swi-libbf-powm-unreduced.sh,
  `powm(42, 0, 1)` beside two controls, asked of the WebAssembly host the tree
  vendors (`extensions/node/_host`, or `WASM_HOST_DIR`), since a GMP build
  answers `absent` whatever it carries; `present` when it is 1.
Patch: tests/checks/host_workarounds/swi-libbf-powm-unreduced.patch, against
  swipl-devel V10.1.14 src/libbf/bf_gmp.c: the initial 1 is reduced by the
  modulus before the loop, so every result lies in [0, mod) as GMP's does.
Lifted when: SWI-Prolog's LibBF `mpz_powm()` reduces its initial value; the
  patch and the entry go together then.
Record: docs/journal/2026-09-24-wasm-library-halves.md.

## swi-infinite-division-zero-sign
Host: SWI-Prolog 10.1.13, fc7ef84b949378b729052c3ade79c90ce5416abb;
  src/pl-arith.c:ar_divide computes X/inf as 0.0*sign_f(X)*sign_f(Y).
Defect: sign_f loses a negative-zero numerator's sign, reversing the expected
  sign of -0.0 divided by either infinity. Finite division controls are correct.
Reproduction: tests/checks/host_workarounds/swi-infinite-division-zero-sign.pl,
  checks both finite controls and all four zero/infinity sign combinations.
Workaround: Vector's class/sign proxies divide by multiplying the exact signed
  reciprocal. Proxies contain only units, zeros, infinities and NaNs.
Lifted when: the host preserves the numerator's zero sign and the reproduction
  returns absent; restore direct division inside the proxy arithmetic boundary.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md.

## swi-uuid-nonhex-hyphens
Host: SWI-Prolog 10.1.13; library/ext/clib/uuid.pl:is_uuid/1 calls
  hex_or_minus/1 at every position, including hexadecimal digit positions.
Defect: is_uuid/1 accepts 36 hyphens as a UUID, although 32 positions must be hex.
Reproduction: tests/checks/host_workarounds/swi-uuid-nonhex-hyphens.pl,
  with a valid UUID and a nonhex control before the all-hyphen probe.
Workaround: lib_uuid validates all five group lengths and their hexadecimal digits.
Lifted when: the host accepts the valid control and rejects both malformed inputs.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md.

## swi-uuid-name-encoding
Host: SWI-Prolog 10.1.13; packages-clib uuid.c:pl_uuid uses PL_get_chars with
  CVT_ATOM and passes a NUL-terminated name to OSSP uuid_make;
  https://github.com/SWI-Prolog/packages-clib/blob/2d74666697ba12af386644638b3e563390affbf6/uuid.c.
Defect: UUID names are read as Latin-1 and truncated at NUL. Non-Latin-1 names
  raise representation_error(encoding); accepted names can hash different bytes.
Reproduction: tests/checks/host_workarounds/swi-uuid-name-encoding.pl,
  comparing ASCII, accented and embedded-NUL names with UTF-8 UUID vectors.
Workaround: lib_uuid's MeTTa name recipe composes lib_encoding and lib_crypto over namespace bytes
  and the complete UTF-8 name, then sets the RFC version and variant bits.
Lifted when: the host produces both UTF-8/NUL vectors. Arbitrary namespace support
  still requires the byte construction unless the host also admits a UUID namespace.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md.
