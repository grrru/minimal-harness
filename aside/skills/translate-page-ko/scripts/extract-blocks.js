(opts) => {
  const o = opts || {};
  const rootSel = o.rootSelector;
  const root =
    (rootSel && document.querySelector(rootSel)) ||
    document.querySelector('main') ||
    document.querySelector('article') ||
    document.querySelector('[role="main"]') ||
    document.querySelector('.post-content, .entry-content, .markdown-body, #content') ||
    document.body;

  const CAND = 'p, li, h1, h2, h3, h4, h5, h6, blockquote, dd, dt, figcaption, td, th, summary';
  const SKIP_ANCESTOR = 'pre, code, nav, footer, header, aside, script, style, template, [data-akt-tr]';

  // clear previous run markers
  document.querySelectorAll('[data-akt-idx]').forEach((el) => el.removeAttribute('data-akt-idx'));
  // Remove any injected translations first. Otherwise an li/td that already holds a
  // Korean child would read back as "already Korean" and get skipped on re-extraction.
  // inject-translations.js re-adds them, and the cache means nothing is lost.
  document.querySelectorAll('.akt-tr').forEach((n) => n.remove());

  const hangul = /[\uac00-\ud7a3]/;
  const out = [];
  let i = 0;

  for (const el of root.querySelectorAll(CAND)) {
    if (el.closest(SKIP_ANCESTOR)) continue;
    if (el.querySelector(CAND)) continue; // outer container, its children are handled
    const style = getComputedStyle(el);
    if (style.display === 'none' || style.visibility === 'hidden') continue;
    const text = (el.innerText || '').replace(/\s+\n/g, '\n').trim();
    if (text.length < 2) continue;
    if (!/[A-Za-z]{2}/.test(text)) continue; // no real prose
    if (hangul.test(text)) continue; // already Korean
    // mostly-code lines
    if (el.children.length === 1 && el.firstElementChild.tagName === 'CODE' && text.length < 60) continue;
    el.setAttribute('data-akt-idx', String(i));
    out.push({ i, tag: el.tagName.toLowerCase(), text });
    i++;
  }
  return { root: root.tagName.toLowerCase() + (root.id ? '#' + root.id : ''), count: out.length, blocks: out };
}
