// Render LaTeX equations to self-contained SVGs using MathJax.
// GitHub mobile renders images but not $$...$$ — every equation in README.md
// and docs/science/README.md is pre-rendered here and referenced as <img>.
//
// Usage:
//   npm install --prefix . mathjax-full
//   node render-math.js

const fs = require("fs");
const path = require("path");

const MJ_PATH = path.join(__dirname, "node_modules", "mathjax-full");
require(path.join(MJ_PATH, "js", "util", "asyncLoad", "node.js"));

const { mathjax } = require(path.join(MJ_PATH, "js", "mathjax.js"));
const { TeX } = require(path.join(MJ_PATH, "js", "input", "tex.js"));
const { SVG } = require(path.join(MJ_PATH, "js", "output", "svg.js"));
const { liteAdaptor } = require(path.join(MJ_PATH, "js", "adaptors", "liteAdaptor.js"));
const { RegisterHTMLHandler } = require(path.join(MJ_PATH, "js", "handlers", "html.js"));
const { AllPackages } = require(path.join(MJ_PATH, "js", "input", "tex", "AllPackages.js"));

const adaptor = liteAdaptor();
RegisterHTMLHandler(adaptor);

const tex = new TeX({ packages: AllPackages });
const svg = new SVG({ fontCache: "none" });
const html = mathjax.document("", { InputJax: tex, OutputJax: svg });

const FG = "#e6edf3";
const OUT = path.join(__dirname, "math");
fs.mkdirSync(OUT, { recursive: true });

const EQUATIONS = [
  ["r1-aho",
   String.raw`T(n, m) = O(|T| + |P| + z) \qquad \text{where } z = \text{matches found}`],
  ["r2-entropy",
   String.raw`H(s) = -\sum_{c \,\in\, \mathrm{charset}(s)} p(c) \log_2 p(c)`],
  ["r2-flag",
   String.raw`\mathrm{Flag}(s) \;\iff\; H(s) > 4.5 \;\wedge\; |s| \geq 20`],
  ["r3-owasp",
   String.raw`\mathrm{Vulnerable}(f) \;\iff\; \exists\, p \in P_{\mathrm{lang}(f)} : \mathrm{match}(p, f) \;\wedge\; \neg\,\mathrm{InComment}(p, f)`],
  ["r4-class",
   String.raw`\mathrm{Class}(\mathrm{cmd}) \,\in\, \{\mathrm{SAFE},\; \mathrm{WARN},\; \mathrm{BLOCK}\}`],
  ["r4-block",
   String.raw`\mathrm{BLOCK} \;\iff\; \mathrm{cmd} \in D_{\mathrm{block}} \;\cup\; \{\mathrm{cmd} : |\mathrm{subcommands}| > 50\}`],
  ["r5-poison",
   String.raw`\mathrm{Poisoned}(c) \;\iff\; \exists\, s \in S_{\mathrm{CVE}} : \mathrm{match}(s,\, \mathrm{content}(c))`],
  ["r6-levenshtein",
   String.raw`d_{\mathrm{lev}}(a, b) = \min \begin{cases} d(a_{1..m-1},\, b) + 1 \\ d(a,\, b_{1..n-1}) + 1 \\ d(a_{1..m-1},\, b_{1..n-1}) + [a_m \neq b_n] \end{cases}`],
  ["r6-typosquat",
   String.raw`\mathrm{Typosquat}(p) \;\iff\; \exists\, t \in \mathrm{Registry} : 0 < d_{\mathrm{lev}}(p, t) \leq 2`],
  ["r7-overflow",
   String.raw`\mathrm{Block}(\mathrm{cmd}) \;\iff\; \bigl|\mathrm{split}(\mathrm{cmd},\, [\,;\;\&\&\;||\;|\,])\bigr| > 50`],
  ["r8-ema",
   String.raw`r_{\mathrm{new}} = \alpha \cdot s_{\mathrm{current}} + (1 - \alpha) \cdot r_{\mathrm{prior}} \qquad \alpha = 0.3`],
  ["r8-theta",
   String.raw`\Theta_n = \Theta_{n-1} - \mathrm{threats\_resolved}_n + \mathrm{new\_threats}_n`],
  ["r8-posture",
   String.raw`\mathrm{Posture}(t) = 1 - \dfrac{\Theta_t}{\Theta_0}`],
];

function render(name, source) {
  const node = html.convert(source, { display: true, em: 16, ex: 8, containerWidth: 1200 });
  let svgStr = adaptor.innerHTML(node);
  svgStr = svgStr.replace(/currentColor/g, FG);
  svgStr = `<?xml version="1.0" encoding="UTF-8"?>\n` + svgStr;
  fs.writeFileSync(path.join(OUT, `${name}.svg`), svgStr, "utf8");
  console.log(`  docs/assets/math/${name}.svg`);
}

console.log(`Rendering ${EQUATIONS.length} equations...`);
for (const [name, src] of EQUATIONS) {
  try { render(name, src); } catch (err) {
    console.error(`FAILED: ${name}\n  ${err.message}`);
    process.exitCode = 1;
  }
}
console.log("Done.");
