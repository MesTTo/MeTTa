;lib_thread's own lower rung. Every operation the two files before this one
;use is one equation over a Prolog predicate imported by name, and the
;underscore spellings are those predicates. Calling them directly is calling
;the same operation, and two of them have no MeTTa-named wrapper at all.
!(import! &self (library lib_thread))

(= (inc $x) (+ $x 1))
(= (big? $x) (> $x 2))

;The five parallel maps over a list. `par_map` preserves the input's order
;however the elements finish; the other four answer one value each.
!(test (par_map inc (1 2 3)) (2 3 4))
!(test (par_filter big? (1 2 3 4)) (3 4))
!(test (par_forall big? (3 4)) True)
!(test (par_forall big? (1 4)) False)
!(test (par_any big? (1 9)) True)
!(test (par_any big? (1 2)) False)
!(test (== (par_map inc (1 2 3)) (par-map inc (1 2 3))) True)

;`par_race` holds its argument, like the MeTTa name over it, so the branches
;are started rather than computed and handed over.
!(test (par_race ((inc 41) (inc 41))) 42)

;Futures. `thread_spawn` starts one, `thread_await` waits for it,
;`thread_settled` asks without waiting, and `thread_cancel` stops one that is
;still running.
!(test (let $f (thread_spawn (inc 41)) (thread_await $f)) 42)
!(test (let $f (thread_spawn (inc 41))
         (let $_ (thread_await $f) (thread_settled $f)))
       True)
!(test (let $f (thread_spawn (let $_ (sleep 30) 1))
         (let $running (thread_settled $f)
           (let $__ (thread_cancel $f) $running)))
       False)

;Channels. `channel_new` mints one, `channel_send` and `channel_recv` are the
;blocking pair, `channel_try_recv` is the non-blocking receive,
;`channel_size` counts what is waiting, and `channel_close` releases it.
!(test (let $c (channel_new)
         (let $_ (channel_send $c hi) (channel_recv $c)))
       hi)
!(test (let $c (channel_new)
         (let $_ (channel_send $c hi) (channel_size $c)))
       1)
!(test (let $c (channel_new) (collapse (channel_try_recv $c))) ())
!(test (let $c (channel_new)
         (let $_ (channel_send $c hi) (collapse (channel_try_recv $c))))
       (hi))
!(test (let $c (channel_new) (channel_close $c)) True)

;Pools. `pool_create` names one, `pool_submit` answers the handle
;`thread_await` takes, `pool_stats` reports it, `pool_destroy` frees it.
!(test (let $p (pool_create rung-pool 2)
         (let $h (pool_submit rung-pool (inc 9)) (thread_await $h)))
       10)
!(test (pool_stats rung-pool) ((size 2) (running 0) (backlog 0) (free 2)))
!(test (pool_destroy rung-pool) True)

;Timers are futures that start later, so the same await and cancel serve
;them: `timer_after` fires once and `timer_every` repeats until cancelled.
!(test (collapse (thread_await (timer_after 0.05 (inc 41)))) (42))
!(test (let $t (timer_every 0.05 (inc 41))
         (let $_ (sleep 0.2)
           (let $__ (thread_cancel $t) stopped)))
       stopped)

;`with_lock` holds a named lock while evaluating, and keeps EVERY answer
;where SWI's own with_mutex is once/1.
!(test (collapse (with_lock rung-lock (superpose (1 2 3)))) (1 2 3))

;The Linda pair over a space. `space_await` waits for a matching atom and
;LEAVES it; `space_take` waits and removes exactly one.
!(add-atom &rung-jobs (job 7))
!(test (space_await &rung-jobs (job $n)) (job 7))
!(test (space_await &rung-jobs (job $n)) (job 7))
!(test (space_take &rung-jobs (job $n)) (job 7))
!(test (collapse (get-atoms &rung-jobs)) ())

;`space_await_where` and `space_take_where` are the same two with match's
;where-guard, evaluated once a candidate binds the pattern's variables. They
;have NO hyphenated spelling above them, and the reason is in the argument
;list: a guard and a seconds deadline would both sit third and nothing could
;tell (peek-atom &s (job $x) 5) apart.
!(add-atom &rung-work (job 2))
!(add-atom &rung-work (job 9))
!(test (space_await_where &rung-work (job $n) (> $n 5)) (job 9))
!(test (space_take_where &rung-work (job $n) (> $n 5)) (job 9))
!(test (collapse (get-atoms &rung-work)) ((job 2)))

;A guard that rejects everything waits out its deadline and answers nothing,
;and the candidates it rejected are still there for whoever does want them.
!(test (collapse (space_take_where &rung-work (job $n) (> $n 100) 0.05)) ())
!(test (collapse (get-atoms &rung-work)) ((job 2)))

;The two machine numbers, and the MeTTa names over them.
!(test (> (cpu_count) 0) True)
!(test (> (thread_count) 0) True)
!(test (== (cpu_count) (cpu-count)) True)
!(test (== (thread_count) (thread-count)) True)
