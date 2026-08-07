---
name: "translate-page-ko"
description: "Translate an English web page into Korean in place, keeping each original paragraph and inserting the Korean translation right below it. Use when the user asks to translate the page/article/docs they are reading into Korean (한글/한국어 번역), or wants a bilingual side-by-side reading view."
---

# Translate Page to Korean (bilingual, in place)

Keep the original English page intact and insert a Korean translation block directly under each paragraph, heading, and list item. Never replace the original text.

## Workflow

1. Attach to the page the user means (`attachActiveBrowserTab()` for "this page"). Confirm URL/title.
2. Extract translatable blocks. The script marks each block with `data-akt-idx` and returns numbered text:

```js
const extractSrc = await fs.readFile('<skillDir>/scripts/extract-blocks.js', 'utf8');
const ex = await page.evaluate(extractSrc, {}); // or { rootSelector: 'article' }
console.log(ex.count, JSON.stringify(ex.blocks));
```

3. Translate the blocks yourself (no external translation API). Work in batches of 25-40 blocks so nothing gets truncated, and inject after each batch so the user sees progress.
4. Inject translations, passing `{ items: [{ i, ko }] }`:

```js
const injectSrc = await fs.readFile('<skillDir>/scripts/inject-translations.js', 'utf8');
const res = await page.evaluate(injectSrc, { items: [{ i: 0, ko: '...' }] });
console.log(JSON.stringify(res)); // { injected, missing }
```

Injection is idempotent per run: it clears previous `.akt-tr` nodes, so send all items of the page in one payload, or re-send accumulated items when injecting batch by batch. Keep a running array in the REPL and re-inject it each batch.

5. Verify with a screenshot of a translated region and report block count. If `res.missing` is non-empty, re-run extraction (page navigation/re-render clears the markers) and redo those blocks.

## Translation rules

- Context-aware, not literal. Read the whole block list first so pronouns, callbacks, and running examples stay consistent across paragraphs.
- Tone: 자연스러운 기술 문서 문체, `~합니다` / `~입니다`. Avoid translationese and word-by-word English syntax.
- Keep code identifiers, function/type names, file paths, CLI flags, math symbols, and library names in English exactly as written (`matrix.Apply`, `sigmoid`, `go run`).
- Technical terms: use the common Korean term with the English in parentheses on first mention only, e.g. `역전파(backpropagation)`, `은닉층(hidden layer)`. Reuse the Korean term afterwards. If a term is normally left in English in Korean dev writing (goroutine, slice, struct), keep it in English.
- Translate headings and list items too, each as its own block.
- Preserve numbers, units, dates, and links' visible text meaning; do not invent or drop sentences. Preserve intentional line breaks in the block text.
- Never translate code blocks, `pre`, or inline-code-only lines. The extractor already skips them.
- Skip blocks that are already Korean (extractor skips them).

## Notes

- Injected nodes carry `data-akt-tr="1"` and class `akt-tr`; a floating `번역 숨기기` / `번역 보기` toggle is added. Pass `{ items, toggle: false }` to skip the button.
- To clear everything: `page.evaluate(() => { document.querySelectorAll('.akt-tr').forEach(n => n.remove()); document.getElementById('akt-toggle')?.remove(); })`.
- Changes are DOM-only, so a reload removes them. Warn the user if they may reload.
- If a page lazy-loads content, translate the visible part, then re-extract after scrolling.
