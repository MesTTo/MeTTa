/* Purpose: the Empty prune's two questions in C, over a list the engine has
 *   just collected: does any element carry the atom Empty, and what does the
 *   list look like without those elements. Registered into module spaces as
 *   metta_c_has_empty/1, metta_c_drop_empty/2, metta_c_has_empty_answer/1 and
 *   metta_c_drop_empty_answer/2 by engine/spaces/bounded_matching.pl when
 *   this file's compiled empty_prune.so sits beside the engine. The four
 *   Prolog walks in that file stay the specification and answer identically.
 *
 *   The cost this removes is a COMPLEXITY CLASS, not a constant. memberchk/2
 *   is C and retires 4 inferences whatever the list length; an identity walk
 *   written in Prolog retires one per cell by construction, because a cell is
 *   a call. So replacing the unsound memberchk pre-filter with the identity
 *   walk it had been guarding took the prune from O(1) inferences to O(n) on
 *   the shape that dominates -- a long list with no Empty in it -- and
 *   engine/bench.pl's match-skew row, which collapses 20 lists of 5,000
 *   ground answers, went from 207,982 inferences to 307,962: exactly the
 *   20 x 4,999 the walk adds. A foreign predicate asks the same question
 *   without unifying and without retiring an inference per cell, so the row
 *   comes back and the crash the pre-filter caused cannot return
 *   [measured 2026-09-05: swipl -g "metta_bench:bench_run('match-skew')" -t
 *   halt engine/bench.pl, 307,962 before and 207,982 after, three identical
 *   samples each way; commit=d6ae0469e495f47b8483b7d6f185ecd9d5472046].
 *
 * Assumes:
 *   - the lists arrive from findall/3 at all four call sites
 *     (engine/translator/runtime.pl collapse_runtime/2,
 *     engine/translator/lowering.pl, engine/translator/special_forms.pl
 *     twice), so a proper list is the only shape the engine can produce
 *     here. The other shapes are still classified rather than assumed away.
 *   - an element may be ANYTHING, an attributed variable included. Nothing
 *     here unifies against one: PL_get_atom answers false for a variable
 *     without touching it, and the kept cells are built by PL_cons_list,
 *     which links the caller's own term into a fresh cell rather than
 *     binding anything to it. That is a structural guarantee rather than a
 *     behavioural one, and it is the whole reason this file exists in the
 *     shape it does: the defect it replaces was a C list scan that DID
 *     unify, and clpfd's attribute_unify_hook raised
 *     type_error(integer, 'Empty') out of the runnable path
 *     [tested: empty_prune_c_differential:a_residual_constraint_answers_through_both_arms].
 *
 * Guarantees:
 *   - each predicate answers exactly what its Prolog twin answers, over the
 *     empty list, a list with no Empty, Empty first, in the middle and last,
 *     an all-Empty list, an attributed variable beside an Empty and beside
 *     none, an unbound variable as an element and as the whole list, the
 *     '$metta_answer'-wrapped shape, an improper list, and a 10,000-element
 *     all-ground list
 *     [tested: empty_prune_c_differential:the_c_scan_and_the_prolog_walk_agree_shape_for_shape,
 *     empty_prune_c_differential:the_two_prune_doors_agree_shape_for_shape].
 *   - no input element is ever unified against, so no attribute_unify_hook
 *     can fire and no coroutine can wake. The only unifications are against
 *     variables this file created and against the caller's own output
 *     argument, which is what the Prolog twin's `Kept = [X|Kept1]` does
 *     [tested: empty_prune_c_differential:a_residual_constraint_answers_through_both_arms].
 *   - the scan TERMINATES on every input, cyclic lists included, because
 *     PL_skip_list classifies with Brent's algorithm before any cell is read
 *     and hands back the number of proper cells, which bounds every loop
 *     [tested: empty_prune_c_differential:a_cyclic_list_refuses_identically_through_both_arms].
 *
 * Fails when:
 *   - the tail is neither [] nor a list cell (an improper list such as
 *     [a|foo]). has_* scans the proper cells and answers false if no Empty
 *     is among them; drop_* fails outright. Both are what the Prolog walks
 *     do: the walk finds an Empty before it reaches the bad tail or fails
 *     when it gets there, and drop can never reach the [] its first clause
 *     needs.
 *   - a '$metta_answer' walk meets a cell that is not '$metta_answer'/2. The
 *     Prolog clause head simply does not unify, so the goal fails, and so
 *     does this.
 *   - the artefact is absent or METTA_C_EMPTY_PRUNE=off, in which case
 *     bounded_matching.pl never calls here.
 *
 * Refuses:
 *   - a PARTIAL list (an unbound tail) with error(instantiation_error, _),
 *     and a CYCLIC list with error(type_error(list, List), _). Neither is
 *     "what the Prolog walk does": the walk unifies the open tail with
 *     [X|Xs] and recurses forever, growing the global stack on the partial
 *     shape and spinning on the cyclic one. The door in bounded_matching.pl
 *     classifies with '$skip_list'/3 before its Prolog branch so both arms
 *     refuse the same way, and the terms are built here to library(error)'s
 *     exact shapes rather than through PL_instantiation_error(), which would
 *     fill in context(spaces:metta_c_has_empty/1, _) where the Prolog arm
 *     leaves the context unbound
 *     [source: /usr/lib/swi-prolog/library/error.pl type_error/2 and
 *     instantiation_error/1, both throw(error(Formal, _)); swipl-devel
 *     src/pl-error.c PL_error() fills context() from environment_frame].
 *
 * Owns resources: a fixed number of term references per call, and three atom
 *   plus three functor handles taken once at install. No heap allocation, so
 *   there is nothing to free on any exit path.
 *
 * Open Obligations:
 *   To Do: None
 *   Hacks: None
 *   Future Enhancements: None
 */

#include <SWI-Prolog.h>
#include <stddef.h>

static atom_t    ATOM_Empty;
static atom_t    ATOM_instantiation_error;
static atom_t    ATOM_list;
static functor_t FUNCTOR_error2;
static functor_t FUNCTOR_type_error2;
static functor_t FUNCTOR_metta_answer2;

/* The two shapes the four predicates come in. The wrapped one looks inside
 * '$metta_answer'(Value, Names) at its first argument, which is where the
 * runnable collector puts the answer. */
#define SCAN_BARE    0
#define SCAN_WRAPPED 1

/* `X == 'Empty'` and nothing more. PL_get_atom answers false for a compound,
 * a number, a plain variable and an attributed variable alike, and reads
 * rather than binds, so the identity question cannot wake a coroutine. */
static int
is_empty_atom(term_t t)
{ atom_t a;

  return PL_get_atom(t, &a) && a == ATOM_Empty;
}

/* library(error)'s instantiation_error/1 body, built by hand so that the C
 * arm and the Prolog arm throw the same term. */
static int
refuse_partial_list(void)
{ term_t formal = PL_new_term_ref();

  if ( PL_unify_term(formal,
                     PL_FUNCTOR, FUNCTOR_error2,
                       PL_ATOM, ATOM_instantiation_error,
                       PL_VARIABLE) )
    PL_raise_exception(formal);

  return FALSE;
}

/* library(error)'s type_error/2 body, with the list itself as the culprit.
 * The culprit is LINKED rather than copied, so a cyclic list costs nothing to
 * report; SWI's writer factors the cycle when the message is printed. */
static int
refuse_cyclic_list(term_t list)
{ term_t formal = PL_new_term_ref();

  if ( PL_unify_term(formal,
                     PL_FUNCTOR, FUNCTOR_error2,
                       PL_FUNCTOR, FUNCTOR_type_error2,
                         PL_ATOM, ATOM_list,
                         PL_TERM, list,
                       PL_VARIABLE) )
    PL_raise_exception(formal);

  return FALSE;
}

/* Classify once, before a single cell is read, and answer how many proper
 * cells there are to read. PL_skip_list walks the spine with Brent's
 * algorithm, so it terminates on a cyclic list where a plain PL_get_list loop
 * would not, and the length it returns then BOUNDS every loop below by
 * construction. library(error)'s own not_a_list/2 draws the same three-way
 * distinction from '$skip_list'/3
 * [source: /usr/lib/swi-prolog/library/error.pl not_a_list/2].
 *
 * A second pass over the spine is what this costs, and it is the price of
 * terminating; json_codec.c's array length check takes the same one. Against
 * the O(n) INFERENCES it replaces, both passes together are one inference.
 *
 * FALSE means an exception has already been raised. */
static int
classify(term_t list, size_t *len)
{ switch ( PL_skip_list(list, 0, len) )
  { case PL_PARTIAL_LIST:
      return refuse_partial_list();
    case PL_CYCLIC_TERM:
      return refuse_cyclic_list(list);
    default:                       /* PL_LIST, or an improper bound tail */
      return TRUE;
  }
}

/* metta_member_empty_/1 and metta_member_empty_answer_/1.
 *
 * An improper tail needs no test of its own: skip_list counted the proper
 * cells, and reaching the end of them without an Empty is exactly the point
 * at which the Prolog walk's [X|Xs] head stops unifying and the goal fails. */
static foreign_t
has_empty(term_t list, int shape)
{ size_t len;

  if ( !classify(list, &len) )
    return FALSE;

  term_t head = PL_new_term_ref();
  term_t tail = PL_copy_term_ref(list);
  term_t slot = PL_new_term_ref();

  for ( size_t i = 0; i < len; i++ )
  { if ( !PL_get_list(tail, head, tail) )
      return FALSE;
    if ( shape == SCAN_WRAPPED )
    { if ( !PL_is_functor(head, FUNCTOR_metta_answer2) )
        return FALSE;              /* the clause head does not unify */
      if ( !_PL_get_arg(1, head, slot) )
        return FALSE;
      if ( is_empty_atom(slot) )
        return TRUE;
    } else if ( is_empty_atom(head) )
      return TRUE;
  }

  return FALSE;
}

/* metta_drop_empty_/2 and metta_drop_empty_answers_/2.
 *
 * The answer is built as a difference list whose open tail this function owns.
 * PL_cons_list LINKS the caller's element into a fresh cell rather than
 * unifying anything with it, and the only PL_unify calls close a hole this
 * file created one iteration earlier. That is one global-stack word per kept
 * element more than the Prolog twin's `Kept = [X|Kept1]` costs, and it buys
 * the property that no input element is ever a unification argument.
 *
 * The wrapped shape SHARES the '$metta_answer'(Value, Names) cell where the
 * Prolog twin rebuilds it around the same two arguments. The results are ==,
 * and nothing can observe the difference: the twin's own rebuild means no
 * caller could ever have relied on the wrapper's identity. */
static foreign_t
drop_empty(term_t list, term_t kept, int shape)
{ size_t len;

  if ( !classify(list, &len) )
    return FALSE;

  term_t head = PL_new_term_ref();
  term_t tail = PL_copy_term_ref(list);
  term_t slot = PL_new_term_ref();
  term_t out  = PL_new_term_ref();
  term_t hole = PL_new_term_ref();
  term_t cell = PL_new_term_ref();
  term_t rest = PL_new_term_ref();

  if ( !PL_put_variable(out) || !PL_put_term(hole, out) )
    return FALSE;

  for ( size_t i = 0; i < len; i++ )
  { if ( !PL_get_list(tail, head, tail) )
      return FALSE;
    if ( shape == SCAN_WRAPPED )
    { if ( !PL_is_functor(head, FUNCTOR_metta_answer2) )
        return FALSE;              /* neither clause head unifies */
      if ( !_PL_get_arg(1, head, slot) )
        return FALSE;
      if ( is_empty_atom(slot) )
        continue;
    } else if ( is_empty_atom(head) )
      continue;

    if ( !PL_put_variable(rest) ||
         !PL_cons_list(cell, head, rest) ||
         !PL_unify(hole, cell) ||
         !PL_put_term(hole, rest) )
      return FALSE;
  }

  /* Only a list that ENDS reaches metta_drop_empty_([], []); an improper tail
   * leaves the Prolog twin with no clause to take, and it fails. */
  if ( !PL_get_nil(tail) )
    return FALSE;

  return PL_unify_nil(hole) && PL_unify(kept, out);
}

static foreign_t
c_has_empty(term_t list)
{ return has_empty(list, SCAN_BARE);
}

static foreign_t
c_drop_empty(term_t list, term_t kept)
{ return drop_empty(list, kept, SCAN_BARE);
}

static foreign_t
c_has_empty_answer(term_t list)
{ return has_empty(list, SCAN_WRAPPED);
}

static foreign_t
c_drop_empty_answer(term_t list, term_t kept)
{ return drop_empty(list, kept, SCAN_WRAPPED);
}

install_t
install_empty_prune(void)
{ ATOM_Empty               = PL_new_atom("Empty");
  ATOM_instantiation_error = PL_new_atom("instantiation_error");
  ATOM_list                = PL_new_atom("list");
  FUNCTOR_error2           = PL_new_functor(PL_new_atom("error"), 2);
  FUNCTOR_type_error2      = PL_new_functor(PL_new_atom("type_error"), 2);
  FUNCTOR_metta_answer2    = PL_new_functor(PL_new_atom("$metta_answer"), 2);

  PL_register_foreign("metta_c_has_empty",         1, c_has_empty,         0);
  PL_register_foreign("metta_c_drop_empty",        2, c_drop_empty,        0);
  PL_register_foreign("metta_c_has_empty_answer",  1, c_has_empty_answer,  0);
  PL_register_foreign("metta_c_drop_empty_answer", 2, c_drop_empty_answer, 0);
}
