// utils/securityHeaders.js
// The security headers this API sends — in one module, so the exact set can be TESTED.
//
// Why not a bare `app.use(helmet())`: three of helmet's defaults would break this
// service's own public pages and assets.
//   * contentSecurityPolicy — the legal and download pages
//     (drinks-calculator-backend/public/*.html) carry inline <style>/<script>, and a
//     default `default-src 'self'` blocks those, leaving the pages unstyled or broken.
//   * crossOriginEmbedderPolicy (require-corp) — blocks cross-origin subresources and
//     buys nothing for a JSON API whose clients are a mobile app and those two pages.
//   * crossOriginResourcePolicy (same-origin) — would stop another origin fetching our
//     own public assets (logo.png, the download page's APK).
//
// Everything else is kept on purpose: X-Frame-Options stops the public pages being framed
// (clickjacking), nosniff stops MIME confusion, HSTS upgrades any plaintext request, and
// no-referrer keeps a shop's URLs out of other people's logs.
const helmet = require('helmet');

/** Frozen: these options are shared, and a mutated header policy is a security bug.
 *  The nested policy is frozen too — Object.freeze() is SHALLOW, so freezing only the
 *  outer object would leave `crossOriginResourcePolicy.policy` writable. */
const CROSS_ORIGIN_RESOURCE_POLICY = Object.freeze({ policy: 'cross-origin' });
const OPTIONS = Object.freeze({
  contentSecurityPolicy: false,
  crossOriginEmbedderPolicy: false,
  crossOriginResourcePolicy: CROSS_ORIGIN_RESOURCE_POLICY,
});

/** The configured middleware, ready for `app.use(...)`. */
function securityHeaders() {
  // Copies, so a middleware layer cannot mutate the shared (frozen) options.
  return helmet({ ...OPTIONS, crossOriginResourcePolicy: { ...CROSS_ORIGIN_RESOURCE_POLICY } });
}

module.exports = { securityHeaders, OPTIONS };
