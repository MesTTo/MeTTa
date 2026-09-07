#!/bin/sh
# Purpose: build an npm package this repository has never heard of, install it
#   beside the Node seat, and watch it extend that seat through five doors with
#   ZERO edits here. The package is called `solars`, it is written by this
#   script into a scratch directory, and nothing about it exists in the
#   checkout. If the seat can be extended without forking, this passes; if a
#   coupling appears, it does not.
# Guarantees:
#   - every capability is reached through a DECLARED point of `metta-node/seam`,
#     and the program prints which door each one came through.
#   - discovery is the seat's own: the package carries a `metta` field in its
#     package.json, `seam.advertised()` answers its name without importing it,
#     and `await seam.discover()` loads it. A package that registers from its
#     own module body needs neither.
#   - the checkout is read, not written, apart from the seat's own gitignored
#     `dist/`, which is what a consumer of this package would install.
# Fails when: node or npm is absent, which it reports rather than passing on
#   nothing; when swipl-wasm is not installed, it says so and exits 0, the same
#   rule extensions/node/test.sh follows for a gate that must not fetch.
# Open Obligations:
#   To Do: None
#   Hacks: None
#   Future Enhancements: None
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
seat="$project_dir/extensions/node"

if ! command -v node >/dev/null 2>&1; then
    echo "note: node not found, the Node extension proof will not run" >&2
    exit 0
fi
if [ ! -d "$seat/node_modules/swipl-wasm" ]; then
    echo "note: run 'npm ci --prefix extensions/node'; the Node extension \
proof will not run without swipl-wasm" >&2
    exit 0
fi

# One spelling of the bound, implemented in bounded.sh, which every runner in
# this tree reaches: a ceiling AND the link to the process that started it, so
# a killed caller does not leave a build burning a core.
bounded() { sh "$project_dir/bounded.sh" "$@"; }
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

# What a consumer installs. The seat's own `prepare` builds this, and the
# proof needs the built form because `exports` in its package.json maps every
# subpath into it.
(cd "$seat" && bounded npm run --silent build:dist)

mkdir -p "$scratch/app/node_modules/solars"
ln -s "$seat" "$scratch/app/node_modules/metta-node"

cat > "$scratch/app/package.json" <<'JSON'
{
  "name": "app",
  "private": true,
  "type": "module",
  "dependencies": { "solars": "*", "metta-node": "*" }
}
JSON

cat > "$scratch/app/node_modules/solars/package.json" <<'JSON'
{
  "name": "solars",
  "version": "0.1.0",
  "type": "module",
  "main": "./index.js",
  "exports": { ".": "./index.js" },
  "metta": {
    "extensions": { "solars": "./index.js#register" },
    "spaces": { "solars": "./index.js#SolarSpace" },
    "libraries": { "solars": "./metta" }
  }
}
JSON

mkdir -p "$scratch/app/node_modules/solars/metta"
cat > "$scratch/app/node_modules/solars/metta/solars.metta" <<'METTA'
(= (solar-flare $x) (* 2 $x))
METTA

cat > "$scratch/app/node_modules/solars/index.js" <<'SOLARS'
// solars: a package MeTTa has never heard of, extending its Node seat.
//
// Nothing here is imported by the seat. The package.json `metta.extensions`
// group names `register`, and an app either calls it through
// `seam.discover()` or imports this module, whose body could register itself.
import * as seam from "metta-node/seam";

export class Star {
  constructor(designation) {
    this.designation = designation;
  }
}

export class SolarSpace {
  constructor() {
    this.held = [];
  }

  add(atom) {
    this.held.push(atom);
  }

  atoms() {
    return this.held;
  }
}

export function register() {
  seam.type.register("Star", {
    constructor: Star,
    toAtom: (star) => [star.designation],
    fromAtom: (designation) => new Star(designation),
  });
  seam.repr.register("Star", {
    constructor: Star,
    text: (star) => `(star "${star.designation}")`,
  });
  seam.reflector.register("solars", {
    claims: (value) => value instanceof Star,
    lower: (surface, name, target) => {
      surface.catalog.add(seam.term(name, seam.term("designation"), target.designation));
      return 1;
    },
  });
  seam.point("orbit", "ownership", {
    fields: ["claims", "period"],
    doc: "a library declaring an extension point of its own",
  });
  seam.at("orbit").register("solars", {
    claims: (body) => (body instanceof Star ? body : undefined),
    period: () => 365,
  });
}
SOLARS

cat > "$scratch/app/prove.mjs" <<'PROVE'
// Every door solars reaches, named, from a program that imports only the seat.
import assert from "node:assert/strict";

import { G, S, project } from "metta-node";
import * as seam from "metta-node/seam";

// Discovery is free: the name is advertised and nothing is loaded for it.
assert.deepEqual(seam.advertised(), ["solars"]);
assert.equal(seam.type.find("Star"), undefined);
console.log("discovery       : solars advertised, nothing imported for it");

// 1. the extensions group: one await, and every row solars declares is here.
assert.deepEqual(await seam.discover(), ["solars"]);
const { Star } = await import("solars");
console.log("extensions      : await seam.discover() -> solars, group '" + seam.GROUP + "'");

// 2. the type point: a solars class crosses, both ways.
assert.equal(String(project(new Star("sol"))), '(Star "sol")');
console.log("type            : project(new Star('sol')) -> (Star \"sol\"), point 'type'");

// 3. the repr point: a live solars value prints its own way.
assert.equal(String(G(new Star("sol"))), '(star "sol")');
console.log("repr            : String(G(new Star('sol'))) -> (star \"sol\"), point 'repr'");

// 4. the reflector point: solars decides how its objects become facts.
const claimed = seam.reflector.claim(new Star("sol"));
assert.equal(claimed?.name, "solars");
console.log("reflector       : the reflector point claims a solars.Star, point 'reflector'");

// 5. the provider and library points: what solars advertises, read as rows.
assert.equal(seam.provider.find("solars")?.fields.group, "spaces");
assert.equal(seam.library.find("solars")?.fields.group, "libraries");
console.log("provider|library: advertised rows, points 'provider' and 'library'");

// 6. a point of solars' OWN, which is `kind/2` being multifile one level out.
const orbit = seam.at("orbit");
assert.equal(orbit.kind, "ownership");
assert.equal(orbit.claim(new Star("sol"))?.name, "solars");
assert.equal(orbit.claim(42), undefined);
console.log("orbit           : a point solars DECLARED, and the seat dispatches it");

// The seam says who registered what, as data.
const mine = seam
  .rows()
  .filter((row) => row.name === "solars" || row.name === "Star")
  .map((row) => row.point)
  .sort();
assert.deepEqual(mine, ["library", "orbit", "provider", "reflector", "repr", "type"], mine);
void S;
console.log("solars extended the Node seat through 6 doors with no edit to PeTTa");
PROVE

(cd "$scratch/app" && bounded node prove.mjs) > "$scratch/proof.log" 2>&1 || {
    cat "$scratch/proof.log"
    exit 1
}
cat "$scratch/proof.log"
grep -Fq "solars extended the Node seat through 6 doors with no edit to PeTTa" \
    "$scratch/proof.log"

echo "a stranger extends the Node seat: passed"
