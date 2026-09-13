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
- `Record:` the journal thread that holds the evidence.

An entry lands with its first site and its reproduction in the same commit. A
site the ledger does not know is refused, and so is an entry nothing uses. The
journal keeps the history; this file holds only what is live.

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
Host: SWI-Prolog 10.1.13; `setup_call_cleanup/3` is `sig_atomic(Setup),
  '$call_cleanup'` (boot/init.pl:680-682).
Defect: one call port lies between Setup returning and the cleanup being
  registered. An inference limit that trips at that port unwinds with Setup's
  effects in place and no cleanup owed, and a cleanup of several goals can be
  cut between its goals the same way. A signal cannot do this, because
  `sig_atomic/1` defers it; an inference limit is not a signal.
Reproduction: tests/checks/host_workarounds/swi-cleanup-window.pl, a budget
  sweep over an asserted guard; budget 4 of 64 leaks on 10.1.13.
Workaround: state that must not outlive its scope is a trailed write,
  `b_setval/2` on entry, `nb_setval/2` on the ordinary exit and `b_getval/2`
  to read; unwinding the exception unwinds the trail, so the cleanup is the
  fast ordinary exit rather than the thing correctness rests on.
Lifted when: the cleanup is registered before the call port that follows
  Setup, or the inference check honours the atomic region.
Record: docs/journal/2026-09-07-every-intermittent-root-caused.md, the
  20,000-budget sweep; docs/journal/2026-09-10-every-host-workaround-is-commented.md.

## swi-locale-default-encoding
Host: SWI-Prolog 10.1.13; the default source encoding follows `setlocale()`.
Defect: a boot under `LC_ALL=C` reads a UTF-8 source as single bytes and
  compiles each non-ASCII character to U+FFFD. A `.qlf` written by that boot
  outlives the locale, since its mtime is newer than every source, so every
  later boot under a correct locale serves the poisoned compile; and an ASCII
  output stream does not fail on the mark, it escapes it.
Reproduction: tests/checks/host_workarounds/swi-locale-default-encoding.sh,
  which reads an atom written as U+2705 back under `LC_ALL=C`.
Workaround: the encoding flag and both standard streams are pinned to UTF-8
  before any file loads, and the artifact stamp carries the encoding beside
  the version, so a set compiled under another one is purged.
Lifted when: SWI reads source files as UTF-8 whatever the locale says.
Record: docs/journal/2026-09-07-the-gate-green-again.md, the artifact that
  outlived its locale.

## swi-qlf-extension-spec
Host: SWI-Prolog 10.1.13; `'$qlf_file'/5` in boot/init.pl decides by the
  shape of the spec.
Defect: a `load_files/2` spec that names its `.pl` extension compiles from
  source whatever `qcompile(auto)` says; only a bare stem reaches the artifact
  rule, which loads the `.qlf` when it is fresh and version-compatible and
  rewrites it when it is stale and the directory is writable.
Reproduction: tests/checks/host_workarounds/swi-qlf-extension-spec.sh, which
  loads one unit as `'one.pl'` and another as `two` and looks for the
  artifacts.
Workaround: `metta_load_source/2` strips the extension of a source the boot
  claims, so every runtime unit reaches the artifact rule.
Lifted when: the artifact rule applies to an extension-bearing spec too.
Record: docs/journal/2026-09-09-runtime-units-compile-beside-their-source.md.

## swi-qlf-failed-include-source-module
Host: SWI-Prolog 10.1.13 at fc7ef84b949378b729052c3ade79c90ce5416abb;
  boot/init.pl:$consult_file and src/pl-qlf.c:loadPredicate.
Defect: a failed nested include under qcompile(auto) leaves the source module
  changed. QLF replay then defines the next predicate in that module. A strong
  import there makes lookupProcedureToDefine return null, which loadPredicate
  dereferences, producing signal 11. The stripped library reports the nearest
  exported symbol, PL_cut_query, although the fault is in the QLF loader.
Reproduction: tests/checks/host_workarounds/swi-qlf-failed-include-source-module.sh,
  a module that imports an export into user before a failed nested include.
  The same QLF loads in the control with its optional entry disabled; replay
  with the broken entry enabled exits 139. The crash reporter can instead
  abort with exit 134 after its stack_avail___LD assertion; that result counts
  only with the original signal-11 report and the exact secondary assertion.
  No engine or Janus is loaded.
Workaround: loading_loudly/1 restores the source module on success, failure
  and exception before QLF replay continues. Nested diagnostic collection
  turns the printed include error into a refusal at the boot boundary.
Lifted when: the reproduction safely rejects or finishes replay instead of
  crashing, and the loader restores module state after a failed consult.
Record: docs/journal/2026-09-11-the-engine-and-packaging-lanes-after-the-wave.md.

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
Workaround: each reference observer registers one unnamed closure carrying
  its owning thread and unregisters only that closure at retirement.
Lifted when: add_event_hook releases the event-list mutex before returning
  from the named-handler replacement branch. Distinct observer ownership
  remains necessary after that host repair.
Record: docs/journal/2026-09-09-import-and-module-semantics.md, candidate
  admission and concurrent rollback-listener evidence.

## swi-query-frame-discarded-on-engine-destroy
Host: SWI-Prolog 10.1.13; `PL_close_query` in src/pl-wam.c closes the
  foreign frame before discarding the outer query frame, while
  `prolog_frame_attribute/3` marks inspected ancestors for `frame_finished`.
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
Workaround: inspect only through the nearest live transaction frame and
  transfer its watch to the surviving transaction when it finishes. Exclude
  the finished frame ID because failure notification can start on that frame.
Lifted when: SWI no longer delivers `frame_finished` for the frame that
  `PL_close_query` discards, or excludes its outer query frame from
  `prolog_frame_attribute/3` marking. Verify that host change before treating
  `absent` from a build without assertions as a lift signal.
Record: docs/journal/2026-09-09-the-binding-collapse.md, transfer bound watches
  before native query destruction.

## swi-file-search-cache-autoload
Host: Janus 1.5.3 on SWI-Prolog 10.1.13; janus.pl's `py_call/4` failed-query
  branch resolves its declared `maplist/2` autoload on first use.
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
Workaround: import Janus's `maplist/2` dependency once at binding boot. Do
  not put the import on a query path or preload optional library helpers.
Lifted when: Janus resolves this dependency before its first failed text
  query, or SWI's autoload resolution no longer gives that query a cache-state
  dependent inference cost. Equal warm and uncached costs answer `absent`.
Record: docs/journal/2026-09-09-the-binding-collapse.md, first-use dependency
  attribution and deterministic 226/229 controls. The separate file-search
  cache maintenance sweep belongs to its own host-workaround entry.
## swi-gc-in-frame-finished-listener-clears-a-live-slot
Host: SWI-Prolog 10.1.13, commit fc7ef84b949378b729052c3ade79c90ce5416abb;
  src/pl-wam.c:884-899, src/pl-vmi.c:1243-1263 and 2160-2207,
  src/pl-gc.c:1886-1918, 2113-2117 and 3584-3694.
Defect: debug mode exposes B_UNIFY_FV as a temporary unification frame.
  prolog_frame_attribute/3 marks a frame for frame_finished notifications
  (src/pl-trace.c:2503). The observer references it at the call port through
  prolog_frame_attribute(Frame,pc,PC). On deterministic exit the parent has
  resumed in SWI's saved registers before frameFinished calls the listeners.
  Collection there rewinds the parent's saved PC to the completed B_UNIFY_FV,
  then clears its first-write slot as uninitialised. The arithmetic goals in
  translator:translate_clause_impl/4's slot 27 disappear at saved PC 209,
  rewound to instruction 206. Debug mode with an unreferenced frame does not
  notify the listener and preserves the value.
Reproduction: tests/checks/host_workarounds/swi-gc-in-frame-finished-listener-clears-a-live-slot.pl,
  Plain SWI, a frame_finished listener that calls garbage_collect/0, and
  sample([arithmetic],Output). The unreferenced debug control prints absent;
  the referenced run's last line is present iff Output == [], absent
  otherwise. Both verdicts exit 0.
Workaround: the process-wide trace hook first tests the captured starting
  thread's identity, then disables its gc flag at every exit port before
  frame inspection or observer work. Every non-exit port, including call,
  redo, fail, unify, exception and cut ports, restores the captured original
  value. Consecutive exits retain the deferral; observation teardown restores
  the original value even after a hook throws or execution is cancelled.
  The gc flag gates implicit collection and explicit garbage_collect/0
  (src/pl-gc.c:3827, 4418 and 4561-4577); this does not merely intercept
  explicit calls. Stacks can still grow while collection is deferred.
  The window starts at the exit hook's first call port and extends through
  its own work and the finished listeners until the next port. Its excess is
  the parent's straight-line VM instructions after the listeners return:
  collection there requires an instruction's own space check, which restarts
  that instruction, or the next port, so deferring it to that port loses no
  collection opportunity. A collection already requested before the exit
  hook can still run at its first call port, before the identity test and
  flag write alike; only a host fix removes that residual boundary. The guard
  adds no exposure there. Observation covers only the starting thread. Its
  hooks inspect frames and update maps and never create threads; source code
  reaches a restoring call port before thread creation. Other threads' flags
  are never written by this hook.
Lifted when: the reproduction prints absent because collection after a
  referenced inline unification no longer reinterprets its completed
  first-write instruction as pending. Fixing the saved-PC or live-slot
  treatment also removes the pre-hook residual boundary; a timing change is
  not evidence that the host condition has been repaired.
Record: docs/journal/2026-09-10-the-observed-equation-loses-its-arithmetic.md.
## swi-file-search-cache-sweep
Host: SWI-Prolog 10.1.13; boot/init.pl:1531-1564,
  https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/boot/init.pl#L1531-L1564.
Defect: the first library load after the file-search cache expires runs
  gc_file_search_cache/1, removing other expired lookup entries. The next
  lookup pays resolution and insertion work instead of the warm-cache cost;
  wall-clock state changes measured Prolog inferences. A zero timeout bypasses
  insertion and the sweep, so it tests an uncached walk rather than this event.
Reproduction: tests/checks/host_workarounds/swi-file-search-cache-sweep.pl,
  ages cache and sweep timestamps under a positive timeout, loads a previously
  unloaded library, and compares the next lookup with two warm lookups.
Workaround: extensions/python/tools/twin_coverage.py sets
  file_search_cache_time to 9223372036854775807 before MeTTa boot, so every
  measured child and its inherited engines keep the cache live for the lane.
Lifted when: the aged load's next lookup costs the same inferences as a warm
  lookup; the reproduction then answers absent instead of the current 818
  against 680. Unequal warm controls or a reversed difference are broken.
Record: docs/journal/2026-09-07-merged-tree-reconciliations.md, the cache-age
  controls and the 2026-09-10 host-reproduction section.

## swi-first-arg-index-dead-keys
Host: SWI-Prolog 10.1.13; next_clause_primary_index in src/pl-index.c:293-346
  and the clause-collection contract in src/pl-proc.c:2248-2276,
  https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-index.c#L293-L346.
Defect: retract leaves dead ClauseRef keys in the primary index until clause
  collection. A bound lookup for the sole live tail scans the retired keys;
  the physical scan grows although Prolog reports the same inference count.
Reproduction: tests/checks/host_workarounds/swi-first-arg-index-dead-keys.pl,
  retains 20000 retired rows, measures live-tail lookups, then collects clauses
  and measures the same lookups twice. Automatic collection is held off only
  in this fresh diagnostic process so it cannot erase the inspected state.
Workaround: extensions/cmetta/bridge.pl keeps cursor owners under one static
  recorded key; the C handle carries a bound record reference, and close erases
  the owner immediately instead of retracting a dynamic cursor row.
Lifted when: retained-key lookups cost no more than four times the collected
  control, so the reproduction answers absent. Unequal inference counts or
  a fourfold spread between collected controls report a broken reproduction.
Record: docs/journal/2026-09-07-merged-tree-reconciliations.md, immediate cursor
  retirement and the 2026-09-10 host-reproduction section.

## swi-inherited-empty-predicate-retry
Host: SWI-Prolog 10.1.13; S_VIRGIN in src/pl-vmi.c:3244-3270,
  https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-vmi.c#L3244-L3270.
Defect: resolving a first inherited call retries and increments inferences
  when the provider's first-clause pointer is nonnull, even when every clause
  is retired. Clause collection clears that pointer and removes the retry,
  so identical logical state has a different first-call cost by GC schedule.
Reproduction: tests/checks/host_workarounds/swi-inherited-empty-predicate-retry.pl,
  compares inherited first/warm calls with retained and collected clauses in
  fresh plain-SWI processes, with direct provider calls controlling both arms.
Workaround: translator:runnable_head_awaits_its_definition/1 calls
  filereader:source_pending_definition/2 explicitly. The reader remains the
  same unique provider; no collection or counter adjustment enters the path.
Lifted when: inherited first-call counts agree in both states; the reproduction
  then answers absent. Currently retained reads4/3 and collected3/3, while
  direct calls read3/3 in both states. Inconsistent warm or direct controls,
  reversed costs and child failures are broken reproductions.
Record: docs/journal/2026-09-07-merged-tree-reconciliations.md, the 2026-09-11
  buffered VM trace and unchanged-body foldall controls.

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

## swi-ugraphs-append2
Host: SWI-Prolog 10.1.13; library/ugraphs.pl:top_sort/2 calls append/2 at
  line 460, while its library(lists) declaration at line 79 imports append/3.
Defect: with autoload disabled, top_sort/2 raises
  existence_error(procedure,ugraphs:append/2) even for a two-vertex DAG.
Reproduction: tests/checks/host_workarounds/swi-ugraphs-append2.pl,
  requiring the expected order after adding the missing import as a control.
Workaround: lib_graph explicitly imports append/2 into the ugraphs module.
Lifted when: top_sort/2 computes the expected order with autoload disabled
  before the reproduction supplies the import.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md.

## swi-uuid-name-encoding
Host: SWI-Prolog 10.1.13; packages-clib uuid.c:pl_uuid uses PL_get_chars with
  CVT_ATOM and passes a NUL-terminated name to OSSP uuid_make;
  https://github.com/SWI-Prolog/packages-clib/blob/2d74666697ba12af386644638b3e563390affbf6/uuid.c.
Defect: UUID names are read as Latin-1 and truncated at NUL. Non-Latin-1 names
  raise representation_error(encoding); accepted names can hash different bytes.
Reproduction: tests/checks/host_workarounds/swi-uuid-name-encoding.pl,
  comparing ASCII, accented and embedded-NUL names with UTF-8 UUID vectors.
Workaround: lib_uuid composes lib_encoding and lib_crypto over namespace bytes
  and the complete UTF-8 name, then sets the RFC version and variant bits.
Lifted when: the host produces both UTF-8/NUL vectors. Arbitrary namespace support
  still requires the byte construction unless the host also admits a UUID namespace.
Record: docs/journal/2026-09-11-a-standard-library-for-a-language.md.
