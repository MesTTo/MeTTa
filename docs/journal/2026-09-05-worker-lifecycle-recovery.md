# Worker lifecycle recovery
Goal: Retain pool worker ownership and keep async Prolog registration on its worker.

## 2026-09-05
Tried: The L010 cancellation and delayed-detach regression failed with
`a later waiting close must join workers after close(wait=False)`. The original
closed flag prevented a later caller from joining workers still detaching.
Decided: Close admission and enqueue sentinels once, but allow every waiting
close to join. Refuse self-join explicitly. Keep the existing bounded join policy.
Tried: The L012 decorator escape regression failed with `DID NOT RAISE TypeError`.
Decided: Require the reference function, constructing and applying its Prolog
decorator in one worker request. The existing `_DECORATOR_ACROSS_THE_WORKER`
ledger already records why a synchronous decorator cannot cross that boundary;
no public signature changes. The applied form executes its actual Prolog body
and records registration on the owning worker in the regression test.
Verification: Before rebase the pool regression and existing pool tests passed
27 tests; the async regression and mirror gate passed 10 tests. On base `8f853f99`, the two new regression files and
`extensions/python/tests/repository/test_async_mirror.py` passed 11 tests
with exit 0, recorded in `ai-tmp/remote-lifecycle-rebase-workers.log`.
