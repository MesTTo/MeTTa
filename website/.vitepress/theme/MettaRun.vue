<script setup>
/*
 * Purpose: a Run button over a `metta` fence, and the answer groups under it.
 * Assumes: the `::: run` container gave it the fence's own bytes, percent
 *   encoded, and an example path the corpus runner runs
 *   [source: website/.vitepress/runnable.mjs:runContainer; commit=a8b50dae12518adb626bf2594258eeaaf4a7f76d].
 * Guarantees:
 *   - what runs is the fence's text, character for character, which is the
 *     text of the example file the gate runs
 *     [tested: test_every_run_fence_runs_the_corpus_file_it_names; commit=a8b50dae12518adb626bf2594258eeaaf4a7f76d]
 *   - the engine is the page's, booted once by the first fence a reader runs
 *     [tested: npm run test:browser --prefix extensions/node,
 *     "runs a fence in a mounted component and prints its answer";
 *     commit=a8b50dae12518adb626bf2594258eeaaf4a7f76d]
 *   - a refusal is shown with the code it was raised under -- the seat's for a
 *     door this build has not got, the engine's for a capability, a source or
 *     an inference bound -- and the reset control is offered beside it, because
 *     a refusal can leave a question about the engine that only a fresh one
 *     settles
 *     [tested: npm run test:browser --prefix extensions/node,
 *     "names a worker it cannot start rather than waiting on it";
 *     commit=a8b50dae12518adb626bf2594258eeaaf4a7f76d]
 *   - a reset while a run is going clears the fence rather than showing the
 *     refusal the reset itself produced
 *     [tested: npm run test:browser --prefix extensions/node,
 *     "clears a fence reset while its run was still going"; commit=a8b50dae12518adb626bf2594258eeaaf4a7f76d]
 * Decides: the answer groups are printed as text rather than re-highlighted.
 *   They are the engine's own rendering of an atom, and running them through
 *   the MeTTa grammar would colour an answer as though it were source.
 */
import { computed, ref } from "vue";

import { bootCost, reset, run } from "./engine.js";

const props = defineProps({
  /** The example this fence runs, as a repository-relative path. */
  example: { type: String, required: true },
  /** The fence's own text, percent encoded by the container. */
  source: { type: String, required: true },
  /**
   * The inference budget this fence runs under.
   *
   * Required rather than defaulted, because the container always writes it --
   * from its own `DEFAULT_INFERENCES` or from the fence's `inferences=` -- and
   * a default here would be a second place the number lives.
   */
  inferences: { type: String, required: true },
});

/** idle before the first run, then what the engine is doing or has said. */
const state = ref("idle");
/** One list of answer texts per `!` directive, in the program's own order. */
const groups = ref([]);
/** Whatever the engine wrote to stderr while running. */
const noise = ref([]);
/** The refusal, when the last run was refused. */
const refusal = ref(undefined);
/** What the last run cost. */
const ms = ref(undefined);
/** Which press this is, so an answer to a press the reader has since reset
 *  cannot arrive over the cleared state. */
let asked = 0;

const program = computed(() => decodeURIComponent(props.source));
const busy = computed(() => state.value === "booting" || state.value === "running");
const said = computed(() =>
  groups.value.map((texts, at) => `${String(at + 1)}. ${texts.join("\n   ")}`).join("\n"));

const WORDS = {
  idle: "",
  booting: "booting the engine, about 8 MB, once for the whole page",
  running: "running",
  answered: "",
  refused: "",
};

async function go() {
  const mine = (asked += 1);
  groups.value = [];
  noise.value = [];
  refusal.value = undefined;
  const answer = await run(program.value, Number(props.inferences), (doing) => {
    state.value = doing;
  });
  // Reset while a run is in flight settles that run with a refusal, and showing
  // it would put a refusal under a fence the reader has just cleared.
  if (mine !== asked) return;
  ms.value = answer.ms;
  noise.value = answer.stderr ?? [];
  if (answer.error === undefined) {
    groups.value = answer.groups;
    state.value = "answered";
  } else {
    refusal.value = answer.error;
    state.value = "refused";
  }
}

/** Drop the engine. The next run boots a new one. */
function clear() {
  asked += 1;
  reset();
  state.value = "idle";
  groups.value = [];
  noise.value = [];
  refusal.value = undefined;
  ms.value = undefined;
}
</script>

<template>
  <div class="metta-run" :data-example="example">
    <slot />
    <div class="metta-run-bar">
      <button class="metta-run-go" type="button" :disabled="busy" @click="go">
        {{ state === "idle" ? "Run" : "Run again" }}
      </button>
      <button
        v-if="state !== 'idle'"
        class="metta-run-clear"
        type="button"
        :disabled="state === 'booting'"
        @click="clear"
      >
        Reset
      </button>
      <span class="metta-run-state" role="status">
        {{ WORDS[state] }}
        <template v-if="ms">
          {{ Math.round(ms) }} ms<template v-if="bootCost()">, after a {{ Math.round(bootCost()) }} ms boot</template>
        </template>
      </span>
    </div>
    <pre v-if="state === 'answered'" class="metta-run-answers">{{ said || "no ! directive to answer" }}</pre>
    <pre v-if="state === 'refused'" class="metta-run-refusal">{{ refusal.code }}: {{ refusal.message }}</pre>
    <pre v-if="noise.length > 0" class="metta-run-noise">{{ noise.join("\n") }}</pre>
  </div>
</template>

<style scoped>
.metta-run-bar {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin: -1rem 0 1rem;
}
.metta-run-bar button {
  border: 1px solid var(--vp-c-divider);
  border-radius: 4px;
  padding: 0.2rem 0.9rem;
  font-size: 0.85rem;
  background: var(--vp-c-bg-soft);
}
.metta-run-bar button:disabled {
  opacity: 0.5;
}
.metta-run-state {
  font-size: 0.8rem;
  color: var(--vp-c-text-2);
}
.metta-run-answers,
.metta-run-refusal,
.metta-run-noise {
  margin: 0 0 1rem;
  padding: 0.75rem 1rem;
  border-radius: 6px;
  font-size: 0.85rem;
  white-space: pre-wrap;
  background: var(--vp-c-bg-soft);
}
.metta-run-refusal {
  border-left: 3px solid var(--vp-c-danger-1);
}
.metta-run-noise {
  border-left: 3px solid var(--vp-c-warning-1);
}
</style>
