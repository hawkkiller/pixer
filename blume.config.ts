import { defineConfig } from "blume";

export default defineConfig({
  title: "Pixer",
  description: "Fast, cross-platform image manipulation for Dart.",
  github: {
    owner: "hawkkiller",
    repo: "pixer",
  },
  ai: {
    llmsTxt: true,
  },
  deployment: {
    output: "static",
    site: "https://hawkkiller.github.io",
    base: "/pixer",
  },
});
