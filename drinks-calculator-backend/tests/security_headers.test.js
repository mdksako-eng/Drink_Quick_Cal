// tests/security_headers.test.js
// The security headers are a CONFIGURATION, and a configuration is exactly the kind of
// thing that silently stops being true (someone "simplifies" it to helmet(), the CSP comes
// back and the legal pages break — or worse, a header that protects them is dropped).
//
// No database and no credentials: a throwaway express app wears the real middleware and
// the assertions are made on the real response.
const express = require('express');
const request = require('supertest');
const { securityHeaders, OPTIONS } = require('../utils/securityHeaders');

function appWithHeaders() {
  const app = express();
  app.use(securityHeaders());
  app.get('/x', (_req, res) => res.json({ ok: true }));
  return app;
}

describe('security headers', () => {
  test('framing from another site is refused (clickjacking) and MIME sniffing is off', async () => {
    const res = await request(appWithHeaders()).get('/x');
    // helmet's default, kept deliberately: SAMEORIGIN blocks the attack that matters —
    // another site framing our pages — while still letting our own pages frame each
    // other. DENY would forbid that too, for no security gain here. This assertion exists
    // so the behaviour is pinned rather than assumed.
    expect(res.headers['x-frame-options']).toBe('SAMEORIGIN');
    expect(res.headers['x-content-type-options']).toBe('nosniff');
  });

  test('transport and referrer policies are set', async () => {
    const res = await request(appWithHeaders()).get('/x');
    expect(res.headers['strict-transport-security']).toMatch(/max-age=\d+/);
    expect(res.headers['referrer-policy']).toBeTruthy();
  });

  test('our own public assets stay fetchable from another origin', async () => {
    // The download page hands out an APK and the legal pages show the logo; a same-origin
    // resource policy would block a mirror or a web build from using them.
    const res = await request(appWithHeaders()).get('/x');
    expect(res.headers['cross-origin-resource-policy']).toBe('cross-origin');
  });

  test('the CSP stays OFF so the public pages keep their inline styles', async () => {
    const res = await request(appWithHeaders()).get('/x');
    expect(res.headers['content-security-policy']).toBeUndefined();
  });

  test('COEP stays OFF so cross-origin subresources are not blocked', async () => {
    const res = await request(appWithHeaders()).get('/x');
    expect(res.headers['cross-origin-embedder-policy']).toBeUndefined();
  });

  test('the response is still a normal JSON response (headers must not break the API)', async () => {
    const res = await request(appWithHeaders()).get('/x');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ ok: true });
  });

  test('the shared options cannot be mutated at runtime', () => {
    expect(Object.isFrozen(OPTIONS)).toBe(true);
    expect(Object.isFrozen(OPTIONS.crossOriginResourcePolicy)).toBe(true);
  });
});
