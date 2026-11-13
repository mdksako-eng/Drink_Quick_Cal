// utils/secureCode.js
// Everything that AUTHORISES something must come from the CSPRNG: a password reset code, a company
// join code, an email verification code, and the token a device waits on while a manager approves
// its login.
//
// They were all built with the language PRNG. V8's is xorshift128+, whose internal state can be
// recovered from a handful of observed outputs — so a code you were shown says something about the
// next one. For a 6-digit code that is the difference between guessing one of a million values and
// guessing the next value.
//
// `crypto.randomInt` is uniform (no modulo bias) and cannot be predicted from previous codes.
const crypto = require('crypto');

/// A numeric code, `digits` long, zero-padded, uniformly distributed and crypto-strong.
function generateCode(digits = 6) {
  const max = 10 ** digits;
  return String(crypto.randomInt(0, max)).padStart(digits, '0');
}

/// A URL-safe bearer token for a one-shot handshake. 32 bytes = 256 bits of entropy.
///
/// The value it replaced was `'request_' + user.id + '_' + Date.now()`: it named the user, carried
/// a timestamp anyone can narrow down to a 15-minute window, and could be brute-forced against an
/// endpoint that hands back a session token.
function newRequestToken() {
  return crypto.randomBytes(32).toString('base64url');
}

module.exports = { generateCode, newRequestToken };
