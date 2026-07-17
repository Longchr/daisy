import fs from "node:fs";
import path from "node:path";

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname.replace(/^\/(?:[A-Za-z]:)/, m => m.slice(1))), "..");

function walk(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
    const full = path.join(directory, entry.name);
    if (entry.name === ".git" || entry.name === "build" || entry.name === "DerivedData") return [];
    return entry.isDirectory() ? walk(full) : entry.name.endsWith(".swift") ? [full] : [];
  });
}

function validate(source, file) {
  const stack = [];
  const pairs = { ")": "(", "]": "[", "}": "{" };
  let state = "normal";
  let blockDepth = 0;
  let line = 1;

  for (let i = 0; i < source.length; i += 1) {
    const ch = source[i];
    const next = source[i + 1];
    const triple = source.slice(i, i + 3);
    if (ch === "\n") line += 1;

    if (state === "lineComment") {
      if (ch === "\n") state = "normal";
      continue;
    }
    if (state === "blockComment") {
      if (ch === "/" && next === "*") { blockDepth += 1; i += 1; }
      else if (ch === "*" && next === "/") {
        blockDepth -= 1;
        i += 1;
        if (blockDepth === 0) state = "normal";
      }
      continue;
    }
    if (state === "string") {
      if (ch === "\\") { i += 1; continue; }
      if (ch === "\"") state = "normal";
      continue;
    }
    if (state === "multilineString") {
      if (triple === "\"\"\"") { state = "normal"; i += 2; }
      continue;
    }

    if (ch === "/" && next === "/") { state = "lineComment"; i += 1; continue; }
    if (ch === "/" && next === "*") { state = "blockComment"; blockDepth = 1; i += 1; continue; }
    if (triple === "\"\"\"") { state = "multilineString"; i += 2; continue; }
    if (ch === "\"") { state = "string"; continue; }

    if ("([{ ".includes(ch) && ch !== " ") stack.push({ ch, line });
    if (")] }".includes(ch) && ch !== " ") {
      const expected = pairs[ch];
      const top = stack.pop();
      if (!top || top.ch !== expected) throw new Error(`${file}:${line}: unmatched ${ch}`);
    }
  }

  if (state === "blockComment" || state === "string" || state === "multilineString") {
    throw new Error(`${file}:${line}: unterminated ${state}`);
  }
  if (stack.length) {
    const top = stack.at(-1);
    throw new Error(`${file}:${top.line}: unclosed ${top.ch}`);
  }
}

const files = walk(root);
let mainCount = 0;
for (const file of files) {
  const source = fs.readFileSync(file, "utf8");
  validate(source, path.relative(root, file));
  mainCount += (source.match(/@main\b/g) ?? []).length;
  if (source.includes("\t")) throw new Error(`${path.relative(root, file)} contains a tab`);
}

if (mainCount !== 1) throw new Error(`Expected exactly one @main declaration, found ${mainCount}`);
console.log(`Swift structural sanity passed for ${files.length} files.`);
