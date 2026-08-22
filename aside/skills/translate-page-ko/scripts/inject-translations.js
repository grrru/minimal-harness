(payload) => {
  const items = (payload && payload.items) || [];
  const withToggle = !(payload && payload.toggle === false);
  const doCache = !(payload && payload.cache === false);

  // Cache key + hash must stay in sync with restore-translations.js
  const CACHE_VERSION = 1;
  const pageKey = () => 'akt-tr:v' + CACHE_VERSION + ':' + location.origin + location.pathname;
  const hashText = (s) => {
    let h = 0x811c9dc5;
    for (let i = 0; i < s.length; i++) {
      h ^= s.charCodeAt(i);
      h = (h + (h << 1) + (h << 4) + (h << 7) + (h << 8) + (h << 24)) >>> 0;
    }
    return h.toString(16);
  };
  const srcText = (el) => (el.innerText || '').replace(/\s+\n/g, '\n').trim();

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

  document.querySelectorAll('.akt-tr').forEach((n) => n.remove());

  const INSIDE = new Set(['LI', 'TD', 'TH', 'DD', 'DT', 'SUMMARY', 'FIGCAPTION', 'BLOCKQUOTE']);
  let done = 0;
  const missing = [];
  const entries = {};
  for (const it of items) {
    const el = document.querySelector(`[data-akt-idx="${it.i}"]`);
    if (!el) { missing.push(it.i); continue; }
    entries[hashText(srcText(el))] = it.ko;
    const div = document.createElement('div');
    div.className = 'akt-tr';
    div.setAttribute('data-akt-tr', '1');
    div.textContent = it.ko;
    if (INSIDE.has(el.tagName)) el.appendChild(div);
    else el.insertAdjacentElement('afterend', div);
    done++;
  }

  if (withToggle && !document.getElementById('akt-toggle')) {
    const b = document.createElement('button');
    b.id = 'akt-toggle';
    b.textContent = '번역 숨기기';
    b.onclick = () => {
      const hidden = document.documentElement.getAttribute('data-akt-hidden') === '1';
      document.documentElement.setAttribute('data-akt-hidden', hidden ? '0' : '1');
      b.textContent = hidden ? '번역 숨기기' : '번역 보기';
    };
    document.body.appendChild(b);
  }
  // Persist so a stray navigation / reload doesn't throw the work away.
  let cached = 0, cacheError = null;
  if (doCache) {
    try {
      localStorage.setItem(pageKey(), JSON.stringify({
        v: CACHE_VERSION, url: location.href, savedAt: Date.now(), entries
      }));
      cached = Object.keys(entries).length;
    } catch (e) {
      cacheError = String(e && e.message || e);
    }
  }

  return { injected: done, missing, cacheKey: pageKey(), cached, cacheError, entries };
}
