/* Purpose: append or decode the occurrence argument of a native storage head.
 * Guarantees: metta_storage_term/4 preserves argument order and variable sharing
 *   [tested: spaces_tokens:storage_constructor_matches_specification; commit=7f00ac7932fefa6f380fc8d14ec583ea0c58eff4].
 * Owns resources: SWI reclaims term references with the foreign call frame.
 * Guarded by: no mutable state is retained between calls.
 */
#include <SWI-Prolog.h>
#include <limits.h>

/* PL_cons_functor_v copies term references into one constructed term.
 * https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-fli.c
 */
static foreign_t
storage_term(term_t name, term_t fields, term_t token, term_t head)
{
    term_t tail = PL_new_term_ref();
    if (!tail) return FALSE;
    if (PL_is_variable(head)) {
        atom_t atom;
        size_t size;
        if (!PL_get_atom_ex(name, &atom)) return FALSE;
        int kind = PL_skip_list(fields, tail, &size);
        if (kind == PL_PARTIAL_LIST) return PL_instantiation_error(fields);
        if (kind != PL_LIST) return PL_type_error("list", fields);
        if (size >= INT_MAX) return PL_representation_error("max_arity");
        term_t arguments = PL_new_term_refs((int)size + 1);
        term_t result = PL_new_term_ref();
        if (!arguments || !result || !PL_put_term(tail, fields)) return FALSE;
        for (size_t i = 0; i < size; i++)
            if (!PL_get_list(tail, arguments + i, tail)) return FALSE;
        return PL_put_term(arguments + size, token) &&
               PL_cons_functor_v(result, PL_new_functor_sz(atom, size + 1),
                                arguments) &&
               PL_unify(head, result);
    }
    atom_t atom;
    size_t size;
    term_t field = PL_new_term_ref();
    term_t argument = PL_new_term_ref();
    if (!field || !argument) return FALSE;
    if (!PL_get_name_arity_sz(head, &atom, &size) || size == 0)
        return PL_type_error("compound", head);
    if (!PL_unify_atom(name, atom) || !PL_get_arg_sz(size, head, argument) ||
        !PL_unify(token, argument) || !PL_put_term(tail, fields)) return FALSE;
    for (size_t i = 1; i < size; i++)
        if (!PL_unify_list(tail, field, tail) ||
            !PL_get_arg_sz(i, head, argument) ||
            !PL_unify(field, argument)) return FALSE;
    return PL_unify_nil(tail);
}

install_t install(void)
{
    PL_register_foreign("metta_storage_term", 4, storage_term, 0);
}
