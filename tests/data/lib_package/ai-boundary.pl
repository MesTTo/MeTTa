% Purpose: report package lifecycle observations through the public load doors.
% Assumes: run in a provisioned battery; source fixtures and
%   generated artifacts belong to that battery's ai-tmp directory.
% Guarantees: each observation reports the result, including named refusals.
%   [tested: lib_package; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f].
% Owns resources: fixture streams close on every exit. Each probe runs in this
%   diagnostic process; its claims and native spaces disappear on process exit.

:- module(lib_package_boundary, [main/0]).
:- ensure_loaded('../../../engine/qlf_boot.pl').
:- use_module('../../../engine/metta.pl').
:- use_module(library(filesex)).

:- prolog_load_context(directory, Here),
   directory_file_path(Here, '../../../ai-tmp/lib-package-boundary', Scratch),
   assertz(scratch(Scratch)).

fixture(Name, Text, Path) :-
    scratch(Scratch), make_directory_path(Scratch),
    directory_file_path(Scratch, Name, Relative),
    absolute_file_name(Relative, Path),
    setup_call_cleanup(open(Path, write, Out, [encoding(utf8)]),
                       format(Out, '~s', [Text]), close(Out)).

observe(Name, Goal) :-
    catch((call(Goal) -> Outcome = succeeded ; Outcome = failed),
          Error, Outcome = raised(Error)),
    format('~q.~n', [observation(Name, Outcome)]).

answers(Name, Expression) :-
    catch(findall(Answer, eval(Expression, Answer), Answers),
          Error, Answers = raised(Error)),
    format('~q.~n', [answers(Name, Answers)]).

main :-
    filereader:metta_host_set_silent(true),
    spaces:ensure_native_storage_module('&lib-package-observed', _),
    metta_engine:metta_register_loader_claims,
    filereader:process_loader_string(
        "(= (perform (lib-package-probe $artifact $heads)) (let $_ (add-atom &lib-package-observed (seen $artifact)) receipt-value))\n\c
         (= (release (lib-package-probe $artifact $heads) $handle) (add-atom &lib-package-observed (released $artifact)))",
        _, '&metta'),
    fixture('receipt.metta',
        "(= (package backing) (lib-package-probe artifact ()))\n", Receipt),
    observe(backing_import, 'import!'('&self', Receipt, _)),
    observe(backing_performed,
        metta_host_stored('&lib-package-observed', [seen, artifact])),
    observe(backing_receipt_retained,
        metta_host_stored('&self',
            [performed, ['lib-package-probe', artifact, []], 'receipt-value'])),
    fixture('boot.metta',
        "(= (package boot) (lib-package-probe boot-artifact ()))\n", Boot),
    observe(boot_import, 'import!'('&self', Boot, _)),
    observe(boot_performed,
        metta_host_stored('&lib-package-observed', [seen, 'boot-artifact'])),
    observe(boot_receipt_retained,
        metta_host_stored('&self',
            [performed, ['lib-package-probe', 'boot-artifact', []], 'receipt-value'])),
    observe(boot_unimport, metta_unimport('&self', Boot)),
    observe(boot_released,
        metta_host_stored('&lib-package-observed', [released, 'boot-artifact'])),
    fixture('unclaimed.metta',
        "(= (package backing) (lib-package-unclaimed missing (lib-package-head)))\n",
        Unclaimed),
    observe(uncovered_unclaimed_import, 'import!'('&self', Unclaimed, _)),
    fixture('version.metta', "(= (package version) (+ 1 2))\n", Version),
    observe(computed_version_import, 'import!'('&self', Version, _)),
    fixture('dependency.metta', "(= (lib-package-dependency) ready)\n", _),
    fixture('relative.metta',
        "(= (package requires) \"dependency.metta\")\n", Relative),
    observe(relative_requirement_import, 'import!'('&self', Relative, _)),
    answers(perform_claims, ['get-property', perform, claims]),
    fixture('native.pl',
        "lib_package_boundary_double(Input, Result) :- Result is 2 * Input.\n",
        Artifact),
    atom_string(Artifact, ArtifactString),
    format(string(Backing),
        '(= (package backing) (prolog ~q (lib_package_boundary_double)))~n',
        [ArtifactString]),
    fixture('native.metta', Backing, Native),
    metta_engine:metta_reference_home(Native, Home),
    observe(native_home_import, metta_engine:importer_helper(Home, Native)),
    observe(backing_registered_in_home,
        metta_engine:metta_reference_prolog_head(Home,
            lib_package_boundary_double, 2)),
    answers(native_before_unimport, [evalc, [lib_package_boundary_double, 21], Home]),
    observe(native_unimport, metta_unimport(Home, Native)),
    answers(native_after_unimport, [evalc, [lib_package_boundary_double, 21], Home]).
