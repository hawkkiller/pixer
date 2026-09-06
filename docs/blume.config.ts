import { defineConfig } from "blume";

export default defineConfig({
  title: "Pixer",
  description: "Fast, cross-platform image manipulation for Dart.",
  content: {
    root: "content",
  },
  github: {
    owner: "hawkkiller",
    repo: "pixer",
    dir: "docs",
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
