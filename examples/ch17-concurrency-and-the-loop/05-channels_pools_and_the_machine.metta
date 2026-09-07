;The rest of lib_thread's MeTTa surface: the non-blocking receive, closing a
;channel, what a pool reports about itself, destroying one, and the two
;numbers that describe the machine the program is running on.
!(import! &self (library lib_thread))

(= (inc $x) (+ $x 1))

;`try-recv` is `recv` without the wait. An empty channel answers NOTHING
;rather than blocking or erroring, so the empty tuple is "nothing was there"
;and a one-element tuple is the message.
!(test (let $c (channel) (collapse (try-recv $c))) ())
!(test (let $c (channel)
         (let $_ (send $c hello) (collapse (try-recv $c))))
       (hello))

;Which makes draining a channel a loop that terminates: take while there is
;something, stop when there is not.
!(test (let $c (channel)
         (let $_ (send $c one)
           (let $__ (send $c two)
             (let $first (try-recv $c)
               (let $second (try-recv $c)
                 ($first $second (collapse (try-recv $c))))))))
       (one two ()))

;`channel-close` closes it, and the channel is GONE rather than emptied: a
;second close, and a receive on it, each report that the channel does not
;exist. The identifier in the refusal is the channel's own number, so what
;this reads out of it is the kind rather than the number.
!(test (let $c (channel) (channel-close $c)) True)
!(test (let $c (channel)
         (let $_ (channel-close $c)
           (let $reported (catch (channel-close $c))
             (unify $reported (Error $ball $context)
                    (index-atom $ball 1) no-error))))
       metta_channel)
!(test (let $c (channel)
         (let $_ (channel-close $c)
           (let $reported (catch (try-recv $c))
             (unify $reported (Error $ball $context)
                    (car-atom $ball) no-error))))
       existence_error)

;`pool-stats` is what a bounded pool reports about itself: its size, how many
;of its workers are running, how deep the backlog is, and how many are free.
;A pool with nothing submitted has every worker free.
!(test (let $p (pool reporting-pool 2) (pool-stats reporting-pool))
       ((size 2) (running 0) (backlog 0) (free 2)))

;The four are a description of the same two numbers, so running plus free is
;the size whatever the pool is doing.
!(test (let $stats (pool-stats reporting-pool)
         (let $running (index-atom (index-atom $stats 1) 1)
           (let $free (index-atom (index-atom $stats 3) 1)
             (+ $running $free))))
       2)

;A submitted job still answers through the same handle `await` takes, and the
;pool is back to idle once it has been awaited.
!(test (let $h (submit reporting-pool (inc 9)) (await $h)) 10)
!(test (pool-stats reporting-pool) ((size 2) (running 0) (backlog 0) (free 2)))

;`pool-destroy` frees the workers. The name is available again afterwards,
;which is what makes a pool a resource rather than a global.
!(test (pool-destroy reporting-pool) True)
!(test (let $p (pool reporting-pool 1) (pool-stats reporting-pool))
       ((size 1) (running 0) (backlog 0) (free 1)))
!(test (pool-destroy reporting-pool) True)

;`cpu-count` and `thread-count` report the machine and the process. They are
;the numbers a pool size is chosen from, so they are here rather than in a
;system library.
!(test (> (cpu-count) 0) True)
!(test (> (thread-count) 0) True)

;A thread of the program's own raises the second number while it is alive,
;which is the only claim about it that does not depend on the box.
!(test (let $before (thread-count)
         (let $f (spawn (let $_ (sleep 0.2) 1))
           (let $during (thread-count)
             (let $__ (await $f) (> $during $before)))))
       True)
