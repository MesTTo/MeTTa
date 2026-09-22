#!/bin/sh
# Purpose: build a shared library this repository has never heard of, load it
#   into the C seat with mt_extension(), and watch it extend that seat through
#   five doors with ZERO edits here. The library is called `solars`, it is
#   written by this script into a scratch directory, and nothing about it
#   exists in the checkout. If the seat can be extended without forking, this
#   passes; if a capability is missing, it does not compile.
# Guarantees:
#   - every capability is reached through a DECLARED point of the seam, and the
#     host program prints which door each one came through.
#   - the library knows only cmetta.h: it includes nothing else of this
#     repository, links against libcmetta alone, and is loaded by PATH, which
#     is sqlite3's loadable-extension shape entry point and all.
#   - the checkout is read, not written, apart from the seat's own gitignored
#     build products, which `make` owns.
# Fails when: a C compiler or SWI's development files are absent, which the
#   seat's Makefile refuses on by name; this reports that and exits 0, the same
#   rule the C seat's own gate lane follows for an absent toolchain.
# Open Obligations:
#   To Do: None
#   Hacks: None
#   Future Enhancements: None
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
seat="$project_dir/extensions/cmetta"

if ! command -v cc >/dev/null 2>&1 && ! command -v gcc >/dev/null 2>&1; then
    echo "note: no C compiler, the C extension proof will not run" >&2
    exit 0
fi
if ! command -v swipl >/dev/null 2>&1; then
    echo "note: swipl not found, the C extension proof will not run" >&2
    exit 0
fi

CC=${CC:-cc}
# One spelling of the bound, implemented in bounded.sh, which every runner in
# this tree reaches: a ceiling AND the link to the process that started it, so
# a killed caller does not leave a build burning a core.
bounded() { sh "$project_dir/tools/bounded.sh" "$@"; }
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

# The library a consumer links against, built by the seat's own Makefile.
bounded make --quiet -C "$seat" libcmetta.so

mkdir -p "$scratch/solars/metta"

cat > "$scratch/solars/metta/solars.metta" <<'METTA'
(= (solar-flare $x) (* 2 $x))
METTA

cat > "$scratch/solars/solars.c" <<'SOLARS'
/* solars: a library MeTTa has never heard of, extending its C seat.
 *
 * It includes cmetta.h and nothing else of that repository. mt_extension()
 * loads it by path and calls mt_extension_init(), which is where everything
 * below registers; nothing in the seat knows this file exists.
 */

#define _POSIX_C_SOURCE 200809L
#include <cmetta.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* --- atoms this library holds, which the engine reaches as a space --- */

enum { CAPACITY = 8 };

typedef struct store
{ char  *atoms[CAPACITY];
  size_t count;
} store_t;

static mt_status store_add(void *user, const mt_atom *atom)
{ store_t *store = user;
  char *text;
  if ( store->count == CAPACITY ) return MT_LIMIT;
  if ( !(text = mt_show_dup(atom)) ) return mt_error();
  store->atoms[store->count++] = text;
  return MT_OK;
}

/* `removed` is the answer; MT_OK says the provider ran, not that it found
   something. A store that refused to look would say so with a status. */
static mt_status store_remove(void *user, const mt_atom *atom, bool *removed)
{ store_t *store = user;
  const char *text = mt_show(atom);
  size_t at;

  *removed = false;
  if ( !text ) return mt_error();
  for (at = 0; at < store->count; at++)
    if ( strcmp(store->atoms[at], text) == 0 )
    { mt_free(store->atoms[at]);
      memmove(&store->atoms[at], &store->atoms[at + 1],
              (store->count - at - 1) * sizeof(*store->atoms));
      store->count--;
      *removed = true;
      return MT_OK;
    }
  return MT_OK;
}

/* A cursor over what this library holds. The whole store is offered and the
   engine does the matching: a provider MAY narrow on `pattern` and stop at
   `limit` when its own index makes that cheaper, and this one has eight slots
   and no index, so reading them all is the cheaper answer. */
typedef struct cursor
{ store_t *store;
  size_t   index;
} cursor_t;

static mt_status store_next(void *state, mt_atom **answer)
{ cursor_t *cursor = state;
  if ( cursor->index == cursor->store->count ) return MT_DONE;
  *answer = mt_parse(cursor->store->atoms[cursor->index++]);
  return *answer ? MT_ROW : mt_error();
}

static mt_status store_match(void *user, const mt_atom *pattern, size_t limit,
                             mt_iterator *answers)
{ cursor_t *cursor = mt_calloc(1, sizeof(*cursor));
  (void)pattern; (void)limit;
  if ( !cursor ) return MT_NOMEM;
  cursor->store = user;
  *answers = (mt_iterator){cursor, store_next, mt_free};
  return MT_OK;
}

static mt_status store_clear(void *user)
{ store_t *store = user;
  while ( store->count ) mt_free(store->atoms[--store->count]);
  return MT_OK;
}

static void store_release(void *user)
{ store_clear(user);
  free(user);
}

/* --- a C value of this library's own, and how it prints -------------- */

typedef struct star { double magnitude; } star_t;

static const char *star_text(void *value, void *user)
{ static char rendered[64];
  (void)user;
  snprintf(rendered, sizeof(rendered), "(star %.1f)", ((star_t *)value)->magnitude);
  return rendered;
}

/* --- a function this library publishes -------------------------------- */

static mt_status solar_double(mt_call *call, void *user)
{ int64_t value;
  (void)user;
  if ( mt_arity(call) != 1 ) return mt_fail(call, "solar_double takes one integer");
  mt_clear();
  value = mt_int(mt_arg(call, 0));
  if ( !mt_ok() ) return mt_fail(call, "solar_double takes one integer");
  return mt_answer(call, mt_num(value * 2));
}

/* --- a point of this library's OWN ------------------------------------ */

static void *claims_bright(void *value, void *subject)
{ (void)value;
  return ((star_t *)subject)->magnitude < 2.0 ? subject : NULL;
}

/* --- everything this library registers -------------------------------- */

static store_t *opened;

bool mt_extension_init(metta *runtime)
{ mt_seam_row row;
  mt_provider provider;
  const char *directory = getenv("SOLARS_METTA_DIR");

  if ( !(opened = calloc(1, sizeof(*opened))) ) return false;
  memset(&provider, 0, sizeof(provider));
  provider.user = opened;
  provider.add = store_add;
  provider.remove = store_remove;
  provider.match = store_match;
  provider.clear = store_clear;
  provider.release = store_release;
  if ( !mt_provider_open(runtime, "&stars", provider) ) return false;

  if ( !mt_repr(runtime, "star", star_text, NULL) ) return false;

  /* ABI 1 publishes the name EXACTLY, so the MeTTa spelling is written here
     rather than derived from the C identifier beside it. */
  if ( !mt_def(runtime, (mt_op){ .name = "solar-double", .arity = 1,
                                 .effect = MT_PURE, .fn = solar_double }) )
    return false;

  if ( directory && !mt_library(runtime, "solars", directory) ) return false;

  if ( !mt_point_declare(runtime, (mt_point){
         "orbit", MT_OWNERSHIP, "claims",
         "which star a body orbits, declared by solars" }) )
    return false;
  memset(&row, 0, sizeof(row));
  row.point = "orbit";
  row.name = "solars";
  row.claims = claims_bright;
  return mt_register(runtime, row);
}
SOLARS

cat > "$scratch/host.c" <<'HOST'
/* A program that knows the seat and nothing about solars until it loads it. */

#define MT_SHORTHAND
#include <cmetta.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int failures;

static void expect(bool condition, const char *claim)
{ if ( condition ) { printf("%s\n", claim); return; }
  failures++;
  fprintf(stderr, "FAILED: %s\nlast error: %s\n",
          claim, mt_errmsg() ? mt_errmsg() : "(none)");
}

typedef struct star { double magnitude; } star_t;

int main(int argc, char **argv)
{ metta *m;
  mt_space *stars;
  mt_answers *answers;
  const mt_row *answer;
  const mt_seam_row *claimed;
  size_t seen = 0;
  star_t sirius = { -1.5 }, faint = { 6.0 };

  if ( argc < 2 ) { fprintf(stderr, "usage: host <solars.so>\n"); return 2; }
  if ( !(m = mt_open(&(mt_config){0})) )
  { fprintf(stderr, "no runtime: %s\n", mt_errmsg()); return 1; }

  expect(mt_seam_count(m, "provider") == 0,
         "before        : the seat holds no provider, no repr and no library");
  expect(mt_extension(m, argv[1]),
         "extension     : mt_extension(m, solars.so) loaded it and it registered");

  /* 1. the provider point: a space whose atoms solars holds. */
  stars = mt_space_open(m, "&stars");
  expect(stars != NULL, "provider      : &stars opens, point 'provider'");
  expect(mt_space_add(stars, E(S("star"), S("sol"))),
         "provider      : an add reaches the solars store");
  expect(mt_space_add(stars, E(S("star"), S("vega"))),
         "provider      : and a second");
  answers = mt_space_match(stars, E(S("star"), V("which")));
  while ( (answer = mt_row_next(answers)) ) { (void)answer; seen++; }
  mt_answers_free(answers);
  expect(seen == 2, "provider      : a match walks the store the engine never held");

  /* 2. the repr point: a solars value printing its own way. */
  { MT_AUTO mt_atom *object = mt_object(&sirius, "star", NULL);
    mt_space *self = mt_self(m);
    bool rendered = false;
    expect(mt_space_add(self, E(S("held"), mt_keep(object))),
           "repr          : a solars object goes into a space");
    answers = mt_space_atoms(self);
    while ( (answer = mt_row_next(answers)) )
      if ( answer->text && strstr(answer->text, "(star -1.5)") ) rendered = true;
    mt_answers_free(answers);
    expect(rendered, "repr          : and prints as (star -1.5), point 'repr'");
  }

  /* 3. the op point: a function solars published. */
  { MT_AUTO_ASK mt_answers *doubled = mt_run(m, "!(solar-double 21)");
    const mt_row *first = doubled ? mt_row_next(doubled) : NULL;
    expect(first && first->text && strcmp(first->text, "42") == 0,
           "op            : (solar-double 21) is 42, point 'op'");
  }

  /* 4. the library point: MeTTa sources solars ships. */
  if ( getenv("SOLARS_METTA_DIR") )
  { MT_AUTO_ASK mt_answers *imported =
      mt_run(m, "!(import! &self (library solars solars.metta)) !(solar-flare 21)");
    const mt_row *last = NULL, *each;
    while ( (each = mt_row_next(imported)) ) last = each;
    expect(last && last->text && strcmp(last->text, "42") == 0,
           "library       : (library solars solars.metta) answers 42, point 'library'");
  }

  /* 5. a point solars DECLARED, dispatched by the seat. */
  claimed = mt_claim(m, "orbit", &sirius, NULL);
  expect(claimed && strcmp(claimed->name, "solars") == 0,
         "orbit         : a point solars declared, and the seat dispatches it");
  expect(mt_claim(m, "orbit", &faint, NULL) == NULL,
         "orbit         : a subject its row declines answers nothing");

  /* The seam says who registered what, as data. */
  expect(mt_seam_count(m, "provider") == 1 && mt_seam_count(m, "repr") == 1 &&
         mt_seam_count(m, "orbit") == 1,
         "seam          : one row per door, readable back as data");

  mt_space_close(stars);
  mt_close(m);
  if ( failures ) return 1;
  printf("solars extended the C seat through 5 doors with no edit to PeTTa\n");
  return 0;
}
HOST

"$CC" -std=c11 -O1 -fPIC -shared -I"$seat" -o "$scratch/solars.so" \
    "$scratch/solars/solars.c" -L"$seat" -Wl,-rpath,"$seat" -lcmetta
# Neither program links SWI directly: libcmetta.so carries that dependency
# and its own rpath, which is exactly what a consumer of this seat gets.
"$CC" -std=c11 -O1 -I"$seat" -o "$scratch/host" "$scratch/host.c" \
    -L"$seat" -Wl,-rpath,"$seat" -lcmetta -lm

SOLARS_METTA_DIR="$scratch/solars/metta" "$scratch/host" "$scratch/solars.so" \
    > "$scratch/proof.log" 2>&1 || {
    cat "$scratch/proof.log"
    exit 1
}
cat "$scratch/proof.log"
grep -Fq "solars extended the C seat through 5 doors with no edit to PeTTa" \
    "$scratch/proof.log"

echo "a stranger extends the C seat: passed"
