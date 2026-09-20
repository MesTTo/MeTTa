# Remote mutation recovery and resource ownership
Goal: Execute L001, L007, L008, L009, L010 and L012 and repair reproduced defects.

## 2026-09-05
Tried: `PYTHONPATH=extensions/python "$VENV/bin/python" -m pytest -c extensions/python/pyproject.toml extensions/python/tests/ch19_spaces_backed_by_anything/test_remote_mutations.py -q -p no:benchmark` discarded each mutation's real HTTP reply after completion. All three cases failed `a lost mutation reply must expose outcome='unknown'`.
Decided: L001 is real. Add an optional protocol extension negotiated through health, with a random client key, gateway instance identity, server-issued expiry and parameter fingerprint. Cache responses before delivery, including uncertain partial failures. A retry preserves the exact request. Expired requests and requests from an earlier gateway instance are refused, so eviction or restart cannot silently execute them again. Capacity is bounded and refuses admission before execution.
Rejected: automatic retries of unkeyed mutations, because an applied write can lose its response. Rechecking membership cannot count duplicate effects. A cache with eviction but no request expiry would recreate the same ambiguity.
Source: Stripe API `2026-07-29.dahlia`, https://docs.stripe.com/api/idempotent_requests, saves the first result and rejects parameter changes. AWS EC2, https://docs.aws.amazon.com/ec2/latest/devguide/ec2-api-idempotency.html, binds client tokens to parameters and an execution scope. The gateway uses the same replay principle; its explicit expiry makes its bounded in-memory retention observable.
Decided: preserve revision 3's existing operations and advertise the extension separately. A server without that advertisement still accepts ordinary requests; lost responses expose `OutcomeUnknown` whose retry refuses to send. No exactly-once claim spans gateway restart or a provider's own partial failure.

Tried: L008's initial 16 malformed-response regressions all failed. Empty
mappings, strings and truthy wrong types were accepted as atom lists or
acknowledgements. A malformed second atom could follow an already delivered
first atom.
Decided: Validate every envelope and decode its complete atom list at the
transport boundary. Keep a valid initial cursor token during rejected-response
cleanup, and preserve it in ProtocolError when stopping also fails.
Tried: Two engine-policy regressions failed with `DID NOT RAISE ProtocolError`.
Subclassing TransportFailure alone still failed: the Prolog bridge recognized
only that exact class name and converted subclass errors into data.
Decided: The Python shim supplements the bridge's fast path by classifying the
live exception object through `metta.errors.is_transport_failure`. This keeps
the original exception and recovery state while covering Python subclasses.
Source: Janus documents that `error(python_error(ErrorType, Value), _)` carries
the live exception object as Value, at
https://www.swi-prolog.org/pldoc/man?section=janus-python-errors.
Tried: A synthetic user operation wrapped its exception as EngineError. That
is the operation boundary's existing attribution policy, so it was rejected
as a test of provider mutation recovery. The replacement uses an actual
attached RemoteSpace with `add-atom`; it preserves the OutcomeUnknown object
and its retry callable. Both keep/empty query tests exercise actual malformed
remote responses through the provider seam.
Decided: Worker errors as well as worker deadlines report mutation uncertainty;
a worker can fail while reporting an already applied request. Invalid JSON
and malformed success acknowledgements also cannot prove failure.
Decided: L009 is DONE. Existing tests `test_a_failed_stop_leaves_the_remote_cursor_retryable`,
`test_closing_every_cursor_survives_one_failure`, `test_an_idle_cursor_is_released`
and `test_a_closed_remote_cursor_refuses_further_pulls` passed before changes
to the valid-cursor lifecycle. A real Gateway probe confirmed that close before
first next stops the initial token. Abandonment emits ResourceWarning and the
gateway retains ownership until expiry sweeping or close. No destructor does
network I/O.

Tried: A reentrant mutation advanced beyond its expiry, then admitted a nested
mutation after pruning. The outer completion restored its expired record
without an expiry-heap entry, permanently occupying capacity. The probe failed
`expiry during a reentrant write must not resurrect a pruned reservation`.
Decided: Completion updates its retained response only if its original
reservation object still occupies the key. Expired work cannot restore a
pruned entry or overwrite a later reservation. This is the ownership-check
principle documented for expired Redis locks at
https://redis.io/docs/latest/develop/clients/patterns/distributed-locks:
release or completion must compare the current owner before changing state.
Verification: The added expiry regression failed before the ownership check
and passed afterwards. The complete mutation/schema set passed 42 tests.
`npm run --prefix website docs:build` rendered the site successfully. Ruff
passed for the changed remote files; mypy reported no issues in remote.py.

Final verification: Rebased to `8f853f99` and repeated the original row probes
against that detached baseline. L001 failed 3 cases, L007 failed 3, L008 failed
16, L010 failed 1 and L012 failed 1 while its applied-form control passed.
L009's four existing guarantees passed. The same unchanged assertions passed
on the implementation branch.
Final verification: `HYPOTHESIS_PROFILE=ci RUSTC_WRAPPER= PYTEST_ADDOPTS=-rs
CHECK_PY="$VENV/bin/python" sh extensions/python/test.sh` passed 3,080 tests,
skipped 48 and exited 0. This is the updated 3,031-test baseline plus 49
regressions. Then `RUSTC_WRAPPER= CHECK_PY="$VENV/bin/python" sh tools/check.sh ruff
artifact-paths` passed both gates with zero artifact-path findings and exit 0.
The complete log and row assertions are in `ai-tmp/ai-remote-lifecycle.md`.
Environment: Rebuilt native artifacts after the worktree relocation, disabled
only this build's stale shared sccache wrapper, and installed the locked Node
and website dependencies. Budget and CLI interruption failures seen in earlier
full runs passed named isolated reruns and the final full run. No expectations
were weakened. The documentation site rendered successfully; all 70 evidence
commit references in changed files resolve, and the clone check found none.
