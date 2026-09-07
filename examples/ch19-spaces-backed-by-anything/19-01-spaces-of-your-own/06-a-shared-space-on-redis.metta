;A space whose atoms live in Redis, so every process attached to the same
;address and name reads and writes the same facts. lib_redis puts four
;clauses on the engine's foreign-space seam and nothing above the seam knows
;there is a network under it: `add-atom`, `remove-atom`, `match` and
;`get-atoms` are the same four operations they are everywhere.
;
;The example skips itself when there is no server at 127.0.0.1:6379, and when
;the platform has no library(redis) at all, because neither is one of the
;engine's requirements. It says so when it skips rather than passing quietly.
;A server for it is one command: docker run --rm -p 127.0.0.1:6379:6379
;redis:7.2.3-alpine

;Two things can be absent, and they are asked about separately: the provider,
;which a platform without library(redis) refuses by that capability's name,
;and the server, which refuses a connection. Each answer is recorded as an
;atom, so the guards below are a match rather than a repeated attempt.
!(add-reduct &redis-status
             (available (if-error (catch (import! &self (library lib_redis)))
                                  no yes)))
!(if (== (match &redis-status (available $v) $v) yes)
     (add-reduct &redis-status
                 (attached (if-error (catch (redis-attach &shared "127.0.0.1:6379"))
                                     no yes)))
     (add-atom &redis-status (attached no)))
!(if (== (match &redis-status (attached $v) $v) no)
     (println! "SKIPPED a-shared-space-on-redis: no Redis provider or no server at 127.0.0.1:6379")
     True)

;A write goes to Redis and a read comes back from it, through the seam.
!(if (== (match &redis-status (attached $v) $v) yes)
     (progn (add-atom &shared (city paris france))
            (add-atom &shared (city lyon france))
            (add-atom &shared (city berlin germany))
            (test (sort-atom (collapse (match &shared (city $c france) $c)))
                  (lyon paris)))
     True)

;A join mixes shared facts with native ones: the engine splits the
;conjunction per conjunct and unifies its own side, so half the query is a
;Redis read and half is a local match.
!(if (== (match &redis-status (attached $v) $v) yes)
     (progn (add-atom &local (capital france paris))
            (test (collapse (match &local (capital $country $city)
                                   (match &shared (city $city $country) $city)))
                  (paris)))
     True)

;`remove-atom` is exact and reaches the shared set, so what one process takes
;out is gone for every other one.
!(if (== (match &redis-status (attached $v) $v) yes)
     (progn (remove-atom &shared (city berlin germany))
            (test (collapse (match &shared (city $c germany) $c)) ()))
     True)

;`redis-detach` releases the binding and LEAVES the facts in Redis, which is
;the difference from clearing a space: the next attach under the same name
;finds them.
!(if (== (match &redis-status (attached $v) $v) yes)
     (progn (redis-detach &shared)
            (redis-attach &shared "127.0.0.1:6379")
            (test (sort-atom (collapse (match &shared (city $c france) $c)))
                  (lyon paris)))
     True)

;And the name is free while it is detached, so a second attach without the
;detach is refused rather than raced: one provider owns a space name at a
;time.
!(if (== (match &redis-status (attached $v) $v) yes)
     (test (let $reported (catch (redis-attach &shared "127.0.0.1:6379"))
             (unify $reported (Error $ball $context) (car-atom $ball) no-error))
           permission_error)
     True)

;Leaving the store as it was found, because a shared space outlives the
;process that wrote it.
!(if (== (match &redis-status (attached $v) $v) yes)
     (progn (remove-atom &shared (city paris france))
            (remove-atom &shared (city lyon france))
            (test (collapse (get-atoms &shared)) ())
            (redis-detach &shared))
     True)
