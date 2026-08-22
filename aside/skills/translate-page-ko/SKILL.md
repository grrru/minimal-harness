---
name: "translate-page-ko"
description: "Translate an English web page into Korean in place, keeping each original paragraph and inserting the Korean translation right below it. Use when the user asks to translate the page/article/docs they are reading into Korean (한글/한국어 번역), or wants a bilingual side-by-side reading view."
---

# Translate Page to Korean (bilingual, in place)

Keep the original English page intact and insert a Korean translation block directly under each paragraph, heading, and list item. Never replace the original text.

Translations are cached, so a stray navigation or reload never costs a re-translation. **Always try restore first** (step 0) before spending tokens on translating.

## Workflow

0. **Try the cache first.** Cheap, and skips everything below on a hit:

```js
const restoreSrc = await fs.readFile('<skillDir>/scripts/restore-translations.js', 'utf8');
const r = await page.evaluate(restoreSrc, {});
console.log(JSON.stringify({ ok: r.ok, source: r.source, restored: r.restored, blocks: r.blocks }));
```

   - `ok: true` → done. Report `restored`/`blocks` and stop.
   - `ok: false, reason: 'no-cache'` → continue to step 1.
   - If localStorage was cleared but a file cache exists, pass it in: `page.evaluate(restoreSrc, { entries })` (it re-saves to localStorage automatically).

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

`inject-translations.js` returns `{ injected, missing, cacheKey, cached, cacheError, entries }`. It writes `entries` (a `{ textHash: korean }` map) to `localStorage` on every call, so the newest batch is always persisted.

5. Save a file-level cache too, so the work survives a cleared localStorage or a different browser profile:

```js
await fs.mkdir('<skillDir>/cache', { recursive: true });
await fs.writeFile('<skillDir>/cache/<slug>.json',
  JSON.stringify({ v: 1, url: page.url(), savedAt: Date.now(), entries: res.entries }));
```

6. Verify with a screenshot of a translated region and report block count. If `res.missing` is non-empty, re-run extraction (page navigation/re-render clears the markers) and redo those blocks.

## Caching

- **Key**: `akt-tr:v1:<origin><pathname>` in `localStorage` (query string and hash are ignored, so `?utm_source=...` still hits).
- **Entries are keyed by an FNV-1a hash of the source text, not by block index.** Index-based caching breaks whenever the DOM shifts; text hashing survives re-renders, ads loading, and minor edits. Identical repeated sentences collapse into one entry, which is correct.
- `restore-translations.js` re-extracts, looks each block up by text hash, and injects on a hit. Blocks with no entry are returned in `untranslated` so you can translate just the new ones and re-inject.
- Cannot auto-run on page load (a fresh navigation destroys all page JS; that would need a browser extension). What the cache buys is that restore is instant and free instead of a full re-translation.
- `hashText` and `pageKey` are duplicated in `inject-translations.js` and `restore-translations.js`. **They must stay identical** or the cache silently misses.
- To wipe the cache for a page: `page.evaluate(() => localStorage.removeItem('akt-tr:v1:' + location.origin + location.pathname))`.
- Pass `{ cache: false }` to `inject-translations.js` to skip persisting.

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
- Changes are DOM-only, so a reload removes them from the page — but the cache means restore is one call away. Tell the user they can just ask to restore.
- **Extraction removes existing `.akt-tr` nodes before reading text.** Translations for `li`/`td`/`dd` are appended *inside* the element, so leaving them in place makes `innerText` read as already-Korean and those blocks get skipped. Injection re-adds them, so the round trip is lossless.
- If a page lazy-loads content, translate the visible part, then re-extract after scrolling.
