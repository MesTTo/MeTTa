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
