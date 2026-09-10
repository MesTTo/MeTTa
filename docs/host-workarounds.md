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
