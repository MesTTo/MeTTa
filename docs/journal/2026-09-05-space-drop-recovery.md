# Space teardown recovery
Goal: Keep Python ownership until engine teardown succeeds and retain failed cleanup.

## 2026-09-05
Tried: The three initial L007 regressions failed. Injecting engine clear/drop
failure lost subscriptions; injecting foreign unregistration failure closed
backing still registered in the engine. The assertion messages are
`failed engine teardown must not discard the space's subscriptions` and
`failed unregistration must not close the registered backing`.
Decided: Detach the engine provider route while retaining its Python registry
entry. Restore that route if engine teardown fails. Release the engine before
canceling subscriptions, unregistering Python ownership or closing backing.
Keep an explicit completed-engine phase so later cleanup retries do not repeat
teardown. Pool an anonymous name only after all Python cleanup succeeds.
Rejected: unconditional backing close in finally, because it destroys the
resource needed to retry failed engine unregistration. Also rejected returning
the name from the engine release itself, because Python cleanup may still fail.
Tried: The additional journal-close failure test exercises cleanup retry, a
reserved anonymous name and preserved external journal data. It checks that
retry issues no second engine teardown. Before rebase the initial regressions
and existing space/lifecycle tests passed 147 tests; final verification records
the rebased run in `ai-tmp/remote-lifecycle-L007-rebased-green.log`.
