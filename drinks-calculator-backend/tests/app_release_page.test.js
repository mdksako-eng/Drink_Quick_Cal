// tests/app_release_page.test.js
// The download page's script, RUN rather than read.
//
// WHY THIS EXISTS. public/download.html renders the version, the release notes and the
// SHA-256 from GET /api/app/release, and it is the page a shop uses to fetch the file. Reading
// it missed two real defects — a failed fetch left a disabled button pointing at "#", and CSS
// `.btn` beat the `[hidden]` rule so the hidden button was still laid out — and `node --check`
// only ever proved the syntax. So the script is executed here against a DOM stub, exactly as
// a browser would run it, and every state it can show is asserted.
//
// The rule it pins: the page NEVER INVENTS A VERSION. Nothing configured means `known: false`
// and the page says so; a wrong version would send a shop after an update that does not exist.
const fs = require('fs');
const path = require('path');

const HTML = fs.readFileSync(
  path.join(__dirname, '..', 'public', 'download.html'),
  'utf8'
);
const SCRIPT = HTML.match(/<script>([\s\S]*?)<\/script>/)[1];

const HASH = 'a'.repeat(64);
const FULL = {
  known: true,
  latestVersion: '1.2.0',
  latestBuild: 2,
  downloadUrl: 'https://example.com/app-release.apk',
  sha256: HASH,
  notes: 'Fixed the till total',
};

const NONE_EN = 'No build is published yet.';
const NONE_FR = "Aucune version n'est encore publiée.";
const ASK_EN = 'A newer build exists. Ask your supplier for the installation file.';

// The ids the script touches, with the attributes the markup really declares on them.
const MARKUP = {
  versionLine: {
    'data-en': 'Checking which build is published…',
    'data-fr': 'Vérification de la version publiée…',
  },
  downloadBtn: {
    'data-en': 'Download the APK',
    'data-fr': "Télécharger l'APK",
    'aria-disabled': 'true',
  },
  copyBtn: { 'data-en': 'Copy', 'data-fr': 'Copier' },
  notes: {},
  hash: {},
  'lang-en': {},
  'lang-fr': {},
};

function makeNode(attrs) {
  const node = {
    textContent: '',
    innerHTML: attrs['data-en'] || '',
    hidden: false,
    href: '',
    attrs: Object.assign({}, attrs),
    setAttribute(key, value) {
      node.attrs[key] = String(value);
    },
    removeAttribute(key) {
      delete node.attrs[key];
    },
    getAttribute(key) {
      return Object.prototype.hasOwnProperty.call(node.attrs, key)
        ? node.attrs[key]
        : null;
    },
  };
  return node;
}

// Runs the page's script with `payload` as the answer from /api/app/release (null = the
// request failed or answered non-200). Returns the nodes and the window it built.
async function runPage(payload, language = 'en-GB') {
  const nodes = {};
  Object.keys(MARKUP).forEach((id) => {
    nodes[id] = makeNode(MARKUP[id]);
  });

  const document = {
    documentElement: { lang: 'en' },
    getElementById: (id) => nodes[id] || null,
    querySelectorAll: (selector) => {
      const name = selector.replace(/^\[|\]$/g, '');
      if (!/^data-(en|fr)$/.test(name)) return [];
      return Object.values(nodes).filter(
        (node) => node.getAttribute(name) !== null
      );
    },
  };
  const navigator = { language, clipboard: { writeText: async () => {} } };
  const store = {};
  const localStorage = {
    getItem: (key) => (key in store ? store[key] : null),
    setItem: (key, value) => {
      store[key] = value;
    },
  };
  const window = {};
  const fetch = async () => ({
    ok: payload !== null,
    json: async () => payload,
  });

  // eslint-disable-next-line no-new-func
  new Function('document', 'navigator', 'localStorage', 'window', 'fetch', SCRIPT)(
    document,
    navigator,
    localStorage,
    window,
    fetch
  );
  await new Promise((resolve) => setTimeout(resolve, 0));

  return { nodes, window, document, store };
}
describe('the download page with nothing configured', () => {
  test('says so instead of inventing a version', async () => {
    const { nodes } = await runPage({ known: false, latestVersion: null });
    expect(nodes.versionLine.textContent).toBe(NONE_EN);
    expect(nodes.hash.textContent).toBe(NONE_EN);
    expect(nodes.copyBtn.hidden).toBe(true);
    expect(nodes.notes.hidden).toBe(true);
  });

  test('takes the download button away rather than leaving it dead', async () => {
    const { nodes } = await runPage({ known: false });
    expect(nodes.downloadBtn.hidden).toBe(true);
    expect(nodes.downloadBtn.getAttribute('aria-disabled')).toBe('true');
  });

  test('an unreachable answer reads the same as nothing configured', async () => {
    const { nodes } = await runPage(null);
    expect(nodes.versionLine.textContent).toBe(NONE_EN);
    expect(nodes.downloadBtn.hidden).toBe(true);
  });
});

describe('the download page with a published release', () => {
  test('shows the version, the build, the link, the notes and the hash', async () => {
    const { nodes } = await runPage(FULL);
    expect(nodes.versionLine.textContent).toBe(
      'Latest published build: 1.2.0 (build 2)'
    );
    expect(nodes.downloadBtn.href).toBe(FULL.downloadUrl);
    expect(nodes.downloadBtn.getAttribute('aria-disabled')).toBeNull();
    expect(nodes.downloadBtn.hidden).toBe(false);
    expect(nodes.notes.textContent).toBe(FULL.notes);
    expect(nodes.hash.textContent).toBe(HASH);
    expect(nodes.copyBtn.hidden).toBe(false);
  });

  test('a release with no hash shows no hash and no copy button', async () => {
    const { nodes } = await runPage({ ...FULL, sha256: null });
    expect(nodes.hash.textContent).toBe(NONE_EN);
    expect(nodes.copyBtn.hidden).toBe(true);
  });

  test('a release with no link asks the supplier instead of offering a button', async () => {
    const { nodes } = await runPage({ ...FULL, downloadUrl: null });
    expect(nodes.downloadBtn.textContent).toBe(ASK_EN);
    expect(nodes.downloadBtn.getAttribute('aria-disabled')).toBe('true');
  });
});

describe('the download page in French', () => {
  test('follows the browser language', async () => {
    const { nodes, document } = await runPage(FULL, 'fr-CM');
    expect(document.documentElement.lang).toBe('fr');
    expect(nodes.versionLine.textContent).toBe(
      'Dernière version publiée : 1.2.0 (build 2)'
    );

    const { nodes: none } = await runPage(null, 'fr-CM');
    expect(none.versionLine.textContent).toBe(NONE_FR);
  });

  test('switching language redraws the computed lines and is remembered', async () => {
    const { nodes, window, store } = await runPage(FULL);
    window.setLang('fr');
    expect(nodes.versionLine.textContent).toBe(
      'Dernière version publiée : 1.2.0 (build 2)'
    );
    expect(nodes.copyBtn.textContent).toBe('Copier');
    window.setLang('en');
    expect(nodes.versionLine.textContent).toBe(
      'Latest published build: 1.2.0 (build 2)'
    );
    expect(store['dqc-lang']).toBe('en');
  });
});

describe('the download page markup', () => {
  test('pairs every English string with a French one', () => {
    const en = (HTML.match(/data-en=/g) || []).length;
    const fr = (HTML.match(/data-fr=/g) || []).length;
    expect(fr).toBe(en);
    expect(en).toBeGreaterThan(10);
  });

  test('a hidden button really is hidden (the CSS trap that bit once)', () => {
    // `.btn` sets display, which beats the user agent's [hidden] rule on its own.
    expect(HTML).toMatch(/\.btn\[hidden\]\s*\{\s*display\s*:\s*none/);
  });
});
