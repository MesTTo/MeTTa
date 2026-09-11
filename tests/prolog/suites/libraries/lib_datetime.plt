% Purpose: check calendar round trips, normalization and native refusals.
% Guarantees: the public face covers each head in the shipped datetime example
% [tested: sh test.sh examples/ch08-data/08-03-the-shipped-libraries/07-datetime.metta; commit=WORKTREE].

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- initialization(consult('../../lib/lib_datetime/lib_datetime.pl')).

:- begin_tests(lib_datetime).

test(record_round_trips_for_negative_fractional_and_future_timestamps) :-
    forall((member(Stamp, [-2208988800, -0.25, 0, 1735689600.25, 4102444800]),
            member(Zone, ['UTC', -39600, 19800])),
           ('timestamp-date'(Stamp, Zone, Parts),
            'date-timestamp'(Parts, Back), assertion(Back =:= Stamp))).

test(calendar_lengths_agree_with_next_month) :-
    forall((between(1996, 2028, Year), between(1, 12, Month)),
           ('month-days'(Year, Month, Days),
            Next is Month + 1,
            'date-timestamp'([date, Year, Month, 1], Start),
            'date-timestamp'([date, Year, Next, 1], End),
            assertion(End - Start =:= Days * 86400))).

test(formatting_keeps_legacy_symbol_and_explicit_zone_string) :-
    format_date(0, '%Y', '1970'),
    'format-date'(0, '%Y', '1970'),
    'format-datetime'(0, '%H:%M', 3600, "23:00"),
    'format-datetime'(0, '%H:%M', "UTC", "00:00").

test(parsing_refuses_unread_text, [error(domain_error(date_text, "not a date"))]) :-
    'parse-date'("not a date", _).

test(parsing_refuses_trailing_text, [error(domain_error(date_text, _))]) :-
    'parse-date'("2025-01-01T00:00:00Z garbage", _).

test(parsing_refuses_unsupported_format, [error(type_error(_, alien))]) :-
    'parse-date'("2025-01-01", alien, _).

test(date_record_shape_is_checked, [error(type_error(date_record, [date, 2025]))]) :-
    'date-timestamp'([date, 2025], _).

test(date_record_fields_are_checked, [error(type_error(integer, x))]) :-
    'date-timestamp'([date, 2025, x, 1], _).

test(month_range_is_checked, [error(type_error(_, 13))]) :-
    'month-days'(2025, 13, _).

test(calendar_delta_shape_is_checked, [error(type_error(calendar_delta, [1]))]) :-
    'date-add'(0, [1], 'UTC', _).

test(calendar_delta_fields_are_checked, [error(type_error(integer, 0.5))]) :-
    'date-add'(0, [0.5, 0, 0, 0, 0, 0], 'UTC', _).

test(unknown_fields_fail, [fail]) :- 'date-field'([date, 2025, 1, 1], missing, _).

test(unknown_zones_raise, [error(domain_error(timezone, 'Australia/Sydney'))]) :-
    'timestamp-date'(0, 'Australia/Sydney', _).

test(normalized_weekday_and_year_day) :-
    'date-weekday'([date, 2025, 1, 32], 6),
    'date-year-day'([date, 2025, 1, 32], 32).

test(calendar_add_recomputes_the_local_offset) :-
    % The explicit offset is whatever this host uses at each resulting date.
    % Comparing to an independent native conversion covers both DST and UTC hosts.
    'parse-date'("2025-10-04T12:00:00Z", Stamp),
    stamp_date_time(Stamp, date(Y,M,D,H,Min,S,_,_,_), local),
    Next is D + 1,
    date_time_stamp(date(Y,M,Next,H,Min,S,_,_,_), Expected),
    'date-add'(Stamp, [0,0,1,0,0,0], local, Actual),
    assertion(Actual =:= Expected).

:- end_tests(lib_datetime).
