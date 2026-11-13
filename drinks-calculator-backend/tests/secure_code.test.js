// tests/secure_code.test.js
//
// The codes that authorise a password reset, a company join, an email verification and a new-device
// login. They are the only thing standing between "ask for it" and "have it", so the tests are
// about the two properties that matter: the value cannot be predicted, and it cannot be traced back
// to the account it belongs to.
const fs = require('fs');
const path = require('path');
const { generateCode, newRequestToken } = require('../utils/secureCode');

const read = (rel) => fs.readFileSync(path.join(__dirname, '..', rel), 'utf8');

describe('generateCode', () => {
  test('six digits by default, zero-padded', () => {
    for (let i = 0; i < 50; i += 1) {
      expect(generateCode()).toMatch(/^\d{6}$/);
    }
  });

  test('honours the requested length', () => {
    expect(generateCode(4)).toMatch(/^\d{4}$/);
    expect(generateCode(8)).toMatch(/^\d{8}$/);
  });

  test('is not a fixed value or a fixed prefix', () => {
    const codes = Array.from({ length: 200 }, () => generateCode());
    const unique = new Set(codes);
    // 200 draws from 1,000,000 values: collisions are possible but a constant or a counter-like
    // generator would show far fewer than this.
    expect(unique.size).toBeGreaterThan(190);
    // A generator that only ever varied its last digits would be trivially predictable.
    const prefixes = new Set(codes.map((c) => c.slice(0, 3)));
    expect(prefixes.size).toBeGreaterThan(150);
  });

  test('covers the low end of the range, so it is not offset', () => {
    // 100..999999 is a common bug (Math.floor(100000 + random()*900000)); a code may legitimately
    // start with zeros, and 2000 draws should reach the low band.
    const codes = Array.from({ length: 2000 }, () => generateCode());
    expect(codes.some((c) => Number(c) < 100000)).toBe(true);
  });
});

describe('newRequestToken', () => {
  test('is URL-safe and long enough to be unguessable', () => {
    const token = newRequestToken();
    expect(token).toMatch(/^[A-Za-z0-9_-]+$/);
    expect(token.length).toBeGreaterThanOrEqual(40); // 32 bytes base64url
  });

  test('never repeats', () => {
    const tokens = new Set(Array.from({ length: 500 }, () => newRequestToken()));
    expect(tokens.size).toBe(500);
  });

  test('carries no user id and no timestamp', () => {
    // The format it replaced ('request_<id>_<epoch ms>') leaked both, which is what made it
    // brute-forceable: the id is guessable and the timestamp narrows the search to 15 minutes.
    const token = newRequestToken();
    expect(token).not.toContain('request_');
    expect(token).not.toMatch(/\d{13}/); // an epoch-millis run
  });
});

describe('no security code is generated with Math.random any more', () => {
  test('server.js does not use Math.random at all', () => {
    // Every code in server.js is an authorising code (reset, join, verify, login-request token),
    // so there is no legitimate use left. If a new one appears, this is the reminder to use
    // utils/secureCode.js instead.
    const source = read('server.js');
    expect(source).not.toContain('Math.random');
  });

  test('utils/secureCode.js uses the CSPRNG', () => {
    const source = read('utils/secureCode.js');
    expect(source).toContain("require('crypto')");
    expect(source).toContain('crypto.randomInt');
    expect(source).toContain('crypto.randomBytes');
    expect(source).not.toContain('Math.random');
  });
});
