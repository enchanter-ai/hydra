# docs/assets — rendered diagrams & equations

Pre-rendered SVGs so GitHub's mobile app (which renders neither
` ```mermaid ` blocks nor `$$...$$` math) shows them correctly. The
root `README.md` and `docs/science/README.md` reference the files here
as `<img>`.

## Files

| File | Source | Regenerate |
|------|--------|-----------|
| `pipeline.svg` | `pipeline.mmd` | `npx @mermaid-js/mermaid-cli -i pipeline.mmd -o pipeline.svg -c mermaid.config.json -p puppeteer.config.json -b "#0a1628" -w 1800 && node apply-blueprint.js pipeline.svg` |
| `lifecycle.svg` | `lifecycle.mmd` | `npx @mermaid-js/mermaid-cli -i lifecycle.mmd -o lifecycle.svg -c mermaid.config.json -p puppeteer.config.json -b "#0a1628" -w 1800 && node apply-blueprint.js lifecycle.svg` |
| `state-flow.svg` | `state-flow.mmd` | `npx -y @mermaid-js/mermaid-cli -i state-flow.mmd -o state-flow.svg -c mermaid.config.json -p puppeteer.config.json -b "#0a1628" -w 1800 && node apply-blueprint.js state-flow.svg` |
| `math/*.svg` | `render-math.js` | `npm install --prefix . mathjax-full && node render-math.js` |

Run the commands from `docs/assets/` (paths are relative). The
toolchain (`node_modules/`, `package.json`, `package-lock.json`) is
gitignored; only the rendered SVGs and their sources are committed.

The `apply-blueprint.js` step overlays an engineering-blueprint grid
(navy `#0a1628` paper, `#1e3a5f` major lines / `#16304f` minor lines)
onto the rendered diagram so it reads as a CAD drawing. Matches the
look of the `wixie` repo.

`docs/science/README.md` references these same SVGs via the relative
path `../assets/math/<name>.svg` — single source of truth, both files
stay in sync.
