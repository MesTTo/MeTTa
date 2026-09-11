; Purpose: check every datetime head, explicit zones, records and normalization.
; Guarantees: fixed dates make calendar results reproducible
; [tested: sh test.sh examples/ch08-data/08-03-the-shipped-libraries/07-datetime.metta; commit=WORKTREE].

!(import! &self (library lib_datetime))

;`now` answers the current Unix time, so a form that PRINTS it verifies
;nothing and cannot be reproduced: the same file run twice a second apart
;answers two different numbers. These three used to print a live reading,
;which is why the two-configuration parity lane reported them as a
;difference that was not one. What is checkable about a clock is that it
;runs forward from a date already past and that formatting it is stable
;within one reading; the fixed timestamps below check format-date's output
;itself.
!(test (let $ts (now) (< 1735689600 $ts)) True)
!(test (let $ts (now)
         (== (format-date $ts "%Y-%m-%d") (format-date $ts "%Y-%m-%d")))
       True)

!(let* (($ts 1766188800)
        ($dow (day-of-week $ts)))
    ($dow))
!(test (day-of-week 1766188800) Saturday)

!(let* (($ts1 1735689600)
        ($ts2 1736294400)
        ($diff (- $ts2 $ts1)))
    ($diff))
!(test (- 1736294400 1735689600) 604800)

!(let* (($ts 1735725045)
        ($time-only (format-date $ts "%H:%M:%S")))
    ($time-only))
!(test (format-date 1735689600 "%B") January)

; The original underscore spellings still return Symbols. The explicit-zone
; formatter returns a String. Offsets follow SWI: positive is west of UTC.
!(test (format_date 1735689600 "%B") January)
!(test (day_of_week 1766188800) Saturday)
!(test (format-datetime 1735689600 "%Y-%m-%d %H:%M" -3600) "2025-01-01 01:00")
!(test (parse-date "2025-01-01T00:00:00Z") 1735689600.0)
!(test (parse-date "Wed, 01 Jan 2025 00:00:00 GMT" rfc_1123) 1735689600.0)

; Date-only records mean UTC midnight. Full records preserve fractional
; seconds and the offset needed for a round trip.
!(test (date-timestamp (date 2025 1 1)) 1735689600.0)
!(test (timestamp-date 1735689600.25 -3600) (date 2025 1 1 1 0 0.25 -3600 - -))
!(test (date-timestamp (timestamp-date -0.25 UTC)) -0.25)
!(test (date-field (date 2025 1 1) year) 2025)
!(test (date-field (date 2025 1 1) date) (date 2025 1 1))
!(test (collapse (date-field (date 2025 1 1) time_zone)) ())
!(test (collapse (date-fields (date 2025 1 1)))
       ((year 2025) (month 1) (day 1) (hour 0) (minute 0) (second 0)
        (utc_offset 0) (date (date 2025 1 1)) (time (time 0 0 0))))
!(test (date-weekday (date 2025 1 1)) 3)
!(test (date-year-day (date 2024 12 31)) 366)
!(test (leap-year 2000) True)
!(test (leap-year 1900) False)
!(test (month-days 2024 2) 29)
!(test (month-days 2025 2) 28)

; Calendar addition uses the host's normalization: January 31 plus one month
; is March 3 in 2025. A duration in seconds remains ordinary + or -.
!(test (date-add 1738281600 (0 1 0 0 0 0) UTC) 1740960000.0)
!(test (date-add 1735689600 (0 0 -1 0 0 0.5) UTC) 1735603200.5)
