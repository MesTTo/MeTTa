/*
 * Purpose: the site's theme, which is VitePress's default plus the one
 *   component the `::: run` container renders.
 * Guarantees: `MettaRun` is registered globally, which is what the container's
 *   emitted `<MettaRun ...>` needs to resolve in every page
 *   [tested: npm run docs:build; commit=WORKTREE].
 */
import DefaultTheme from "vitepress/theme";

import MettaRun from "./MettaRun.vue";

export default {
  extends: DefaultTheme,
  enhanceApp({ app }) {
    app.component("MettaRun", MettaRun);
  },
};
