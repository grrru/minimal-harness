(payload) => {
  // Restore a cached translation onto the current page.
  // payload: { entries?: {hash: ko}, rootSelector?, toggle?, save? }
  // If `entries` is omitted, read from localStorage for this page.
  const o = payload || {};

  // ---- 1. cache key + storage helpers (must match inject-translations.js) ----
  const CACHE_VERSION = 1;
  const pageKey = () => 'akt-tr:v' + CACHE_VERSION + ':' + location.origin + location.pathname;
  const hashText = (s) => {
    // FNV-1a 32bit, hex. Stable across runs and cheap.
    let h = 0x811c9dc5;
    for (let i = 0; i < s.length; i++) {
      h ^= s.charCodeAt(i);
      h = (h + (h << 1) + (h << 4) + (h << 7) + (h << 8) + (h << 24)) >>> 0;
    }
    return h.toString(16);
  };

  let entries = o.entries;
  let source = 'payload';
  if (!entries) {
    try {
      const raw = localStorage.getItem(pageKey());
      if (raw) {
        const parsed = JSON.parse(raw);
        entries = parsed && parsed.entries;
        source = 'localStorage';
      }
    } catch (e) { /* storage blocked */ }
  }
  if (!entries || !Object.keys(entries).length) {
    return { ok: false, reason: 'no-cache', key: pageKey(), source: null, restored: 0 };
  }

  // ---- 2. re-extract blocks (same rules as extract-blocks.js) ----
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
  const hangul = /[\uac00-\ud7a3]/;

  document.querySelectorAll('[data-akt-idx]').forEach((el) => el.removeAttribute('data-akt-idx'));
  // Strip existing translations before reading innerText (see extract-blocks.js note).
  document.querySelectorAll('.akt-tr').forEach((n) => n.remove());

  const blocks = [];
  let i = 0;
  for (const el of root.querySelectorAll(CAND)) {
    if (el.closest(SKIP_ANCESTOR)) continue;
    if (el.querySelector(CAND)) continue;
    const style = getComputedStyle(el);
    if (style.display === 'none' || style.visibility === 'hidden') continue;
    const text = (el.innerText || '').replace(/\s+\n/g, '\n').trim();
    if (text.length < 2) continue;
    if (!/[A-Za-z]{2}/.test(text)) continue;
    if (hangul.test(text)) continue;
    if (el.children.length === 1 && el.firstElementChild.tagName === 'CODE' && text.length < 60) continue;
    el.setAttribute('data-akt-idx', String(i));
    blocks.push({ i, el, text });
    i++;
  }

  // ---- 3. style ----
  if (!document.getElementById('akt-style')) {
    const st = document.createElement('style');
    st.id = 'akt-style';
    st.textContent = `
      .akt-tr{margin:.5em 0 1.1em;padding:.15em 0 .15em .8em;
        border-left:3px solid rgba(74,144,226,.55);
        color:#2f4f6f;background:rgba(74,144,226,.06);
        font-size:.97em;line-height:1.65;white-space:pre-wrap;font-weight:400;font-style:normal;}
      li>.akt-tr,td>.akt-tr,th>.akt-tr,dd>.akt-tr,dt>.akt-tr{margin:.35em 0 .2em;}
      html[data-akt-hidden="1"] .akt-tr{display:none;}
      #akt-toggle{position:fixed;right:16px;bottom:16px;z-index:2147483000;
        padding:8px 14px;border-radius:999px;border:0;cursor:pointer;
        font:600 13px/1 system-ui,-apple-system,sans-serif;
        background:#2f6fd0;color:#fff;box-shadow:0 2px 10px rgba(0,0,0,.25);}
    `;
    document.head.appendChild(st);
  }

  // ---- 4. inject by text hash ----
  const INSIDE = new Set(['LI', 'TD', 'TH', 'DD', 'DT', 'SUMMARY', 'FIGCAPTION', 'BLOCKQUOTE']);
  let restored = 0;
  const untranslated = [];
  for (const b of blocks) {
    const ko = entries[hashText(b.text)];
    if (!ko) { untranslated.push({ i: b.i, text: b.text }); continue; }
    const div = document.createElement('div');
    div.className = 'akt-tr';
    div.setAttribute('data-akt-tr', '1');
    div.textContent = ko;
    if (INSIDE.has(b.el.tagName)) b.el.appendChild(div);
    else b.el.insertAdjacentElement('afterend', div);
    restored++;
  }

  // ---- 5. toggle button ----
  if (!(o.toggle === false) && !document.getElementById('akt-toggle')) {
    const btn = document.createElement('button');
    btn.id = 'akt-toggle';
    btn.textContent = '번역 숨기기';
    btn.onclick = () => {
      const hidden = document.documentElement.getAttribute('data-akt-hidden') === '1';
      document.documentElement.setAttribute('data-akt-hidden', hidden ? '0' : '1');
      btn.textContent = hidden ? '번역 숨기기' : '번역 보기';
    };
    document.body.appendChild(btn);
  }

  // ---- 6. optionally persist entries passed in from a file cache ----
  if (o.save !== false && source === 'payload') {
    try {
      localStorage.setItem(pageKey(), JSON.stringify({
        v: CACHE_VERSION, url: location.href, savedAt: Date.now(), entries
      }));
    } catch (e) { /* quota or blocked */ }
  }

  return {
    ok: true,
    source,
    key: pageKey(),
    blocks: blocks.length,
    restored,
    cached: Object.keys(entries).length,
    untranslated
  };
}
