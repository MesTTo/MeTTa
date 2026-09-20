/* Purpose: backtrackable lookup and binding of atom keys to original terms.
 * Assumes: indexes come from metta_c_atom_index_new/1 and remain in this
 * process; their routing bits describe live interned atom identifiers.
 * Guarantees: lookup retains variable identity, insertion rolls back, and
 * the C and Prolog owners agree [tested: atom_index; commit=dfd348d37d4cbe3d42d877bd6dcf415b54f82179].
 * Owns resources: the index owns ordinary Prolog terms, including each key
 * atom. Call-local term references are released by the foreign frame. No
 * C heap state survives a call; Prolog GC and the trail own every mutation.
 * Guarded by: each index belongs to its calling Prolog engine, like setarg/3.
 * Decides: branch bits strictly decrease, bounding each walk by the width
 * of atom_t [source: engine/atom_index.c:branch; commit=dfd348d37d4cbe3d42d877bd6dcf415b54f82179].
 */

#include <SWI-Prolog.h>
#include <limits.h>
#include <stdint.h>

static functor_t F_index, F_leaf, F_branch;
static predicate_t P_setarg;

/* Big-endian Patricia branching, as in containers-0.8 Data.IntMap.Internal:
 * https://hackage-content.haskell.org/package/containers-0.8/docs/src/Data.IntMap.Internal.html
 * Interned atom IDs supply fixed-width distinct keys; leaves retain the
 * atoms themselves, so atom collection cannot reuse an indexed identity.
 */
enum { KEY_BITS = sizeof(atom_t) * CHAR_BIT };
_Static_assert(sizeof(atom_t) <= sizeof(uintptr_t), "atom identifiers must fit uintptr_t");

static int
root(term_t index, term_t node)
{ if ( !PL_is_functor(index, F_index) )
    return PL_type_error("atom_index", index);
  return PL_get_arg(1, index, node);
}

/* A decreasing bit also refuses corrupt cyclic routing without a scan of
 * values, which may themselves contain cyclic terms or attributed variables.
 */
static int
branch(term_t node, unsigned previous, unsigned *bit)
{ term_t field = PL_new_term_ref();
  int value;

  if ( !PL_get_arg(1, node, field) || !PL_get_integer(field, &value) ||
       value < 0 || (unsigned)value >= previous )
    return PL_domain_error("atom_index_branch", node);
  *bit = (unsigned)value;
  return TRUE;
}

static int
leaf(term_t node, atom_t *key, term_t value)
{ term_t field = PL_new_term_ref();

  if ( !PL_is_functor(node, F_leaf) || !PL_get_arg(1, node, field) ||
       !PL_get_atom(field, key) )
    return PL_domain_error("atom_index_leaf", node);
  return PL_get_arg(2, node, value);
}

static unsigned
side(atom_t key, unsigned bit)
{ return 2 + (((uintptr_t)key >> bit) & 1);
}

static int
descend(term_t index, atom_t key, term_t node)
{ unsigned previous = KEY_BITS, bit;

  if ( !root(index, node) )
    return FALSE;
  while ( PL_is_functor(node, F_branch) )
  { if ( !branch(node, previous, &bit) ||
         !PL_get_arg(side(key, bit), node, node) )
      return FALSE;
    previous = bit;
  }
  return TRUE;
}

static foreign_t
index_new(term_t index)
{ return PL_unify_term(index, PL_FUNCTOR, F_index, PL_LIST, 0);
}

static foreign_t
index_get(term_t index, term_t name, term_t value)
{ atom_t key, found;
  term_t node = PL_new_term_ref(), stored = PL_new_term_ref();

  if ( !PL_get_atom_ex(name, &key) || !descend(index, key, node) ||
       PL_get_nil(node) || !leaf(node, &found, stored) )
    return FALSE;
  return found == key && PL_unify(value, stored);
}

/* Publish one branch through SWI's trailed update, preserving all term
 * references. Successful bindings survive this foreign call; backtracking
 * over it restores the slot, as the atom_index differential suite checks.
 */
static int
publish(term_t parent, unsigned position, term_t node)
{ term_t args = PL_new_term_refs(3);

  return PL_put_integer(args, position) && PL_put_term(args+1, parent) &&
         PL_put_term(args+2, node) &&
         PL_call_predicate(NULL, PL_Q_NODEBUG|PL_Q_PASS_EXCEPTION, P_setarg, args);
}

static foreign_t
index_bind(term_t index, term_t name, term_t value, term_t is_new)
{ atom_t key, found;
  term_t node = PL_new_term_ref(), stored = PL_new_term_ref();
  term_t addition = PL_new_term_ref(), parent = PL_new_term_ref();
  unsigned position = 1, previous = KEY_BITS, bit, differing = 0;
  uintptr_t difference;

  if ( !PL_get_atom_ex(name, &key) || !descend(index, key, node) )
    return FALSE;
  if ( !PL_get_nil(node) )
  { if ( !leaf(node, &found, stored) )
      return FALSE;
    if ( found == key )
      return PL_unify_bool(is_new, FALSE) && PL_unify(value, stored);
    difference = (uintptr_t)key ^ (uintptr_t)found;
    while ( difference >>= 1 )
      differing++;
  } else
    found = key;

  if ( !PL_unify_bool(is_new, TRUE) ||
       !PL_cons_functor(addition, F_leaf, name, value) ||
       !PL_put_term(parent, index) || !root(index, node) )
    return FALSE;
  if ( found != key )
  { while ( PL_is_functor(node, F_branch) )
    { if ( !branch(node, previous, &bit) )
        return FALSE;
      if ( bit <= differing )
        break;
      position = side(key, bit);
      if ( !PL_put_term(parent, node) || !PL_get_arg(position, node, node) )
        return FALSE;
      previous = bit;
    }
    term_t split = PL_new_term_ref(), number = PL_new_term_ref();
    if ( !PL_put_integer(number, differing) ||
         !(side(key, differing) == 2
           ? PL_cons_functor(split, F_branch, number, addition, node)
           : PL_cons_functor(split, F_branch, number, node, addition)) ||
         !PL_put_term(addition, split) )
      return FALSE;
  }
  return publish(parent, position, addition);
}

install_t
install(void)
{ F_index = PL_new_functor(PL_new_atom("$metta_atom_index"), 1);
  F_leaf = PL_new_functor(PL_new_atom("$metta_atom_leaf"), 2);
  F_branch = PL_new_functor(PL_new_atom("$metta_atom_branch"), 3);
  P_setarg = PL_predicate("setarg", 3, "system");
  PL_register_foreign_in_module("atom_index", "metta_c_atom_index_new", 1, index_new, 0);
  PL_register_foreign_in_module("atom_index", "metta_c_atom_index_get", 3, index_get, 0);
  PL_register_foreign_in_module("atom_index", "metta_c_atom_index_bind", 4, index_bind, 0);
}
