// tests/security_answers.test.js
// The rule behind "reset my password with my security questions".
//
// It exists because the comparison looked like a one-liner. It is not: it decides whether a
// stranger can take an account over, and whether a shop can get back into its own till.
const {
  normaliseAnswer,
  hasUsableAnswers,
  answersMatch,
} = require('../utils/securityAnswers');

describe('what counts as the same answer', () => {
  test('case and surrounding space do not matter', () => {
    expect(answersMatch('Lagos', 'lagos')).toBe(true);
    expect(answersMatch('  Lagos  ', 'lagos')).toBe(true);
    expect(answersMatch('lagos', 'LAGOS')).toBe(true);
  });

  test('inner spacing is collapsed, so a stray double space is not a wrong answer', () => {
    expect(answersMatch('my first dog', 'my  first   dog')).toBe(true);
    expect(answersMatch('My First Dog', 'my first dog')).toBe(true);
  });

  test('accented letters fold with their case', () => {
    expect(answersMatch('Yaoundé', 'yaoundé')).toBe(true);
    expect(answersMatch('YAOUNDÉ', 'yaounde')).toBe(false); // é and e are different answers
  });

  test('a genuinely different answer is refused', () => {
    expect(answersMatch('Lagos', 'Douala')).toBe(false);
    expect(answersMatch('Lagos', 'Lago')).toBe(false);
  });
});

describe('an empty answer can never match anything', () => {
  test('a blank attempt is refused even against a blank stored value', () => {
    // This is the takeover hole: '' === '' would let any caller through.
    expect(answersMatch('', '')).toBe(false);
    expect(answersMatch('   ', '')).toBe(false);
    expect(answersMatch('', '   ')).toBe(false);
  });

  test('missing values are refused rather than crashed on', () => {
    expect(answersMatch(null, null)).toBe(false);
    expect(answersMatch(undefined, 'Lagos')).toBe(false);
    expect(answersMatch('Lagos', undefined)).toBe(false);
  });
});

describe('whether an account can be reset this way at all', () => {
  test('both stored answers must be usable', () => {
    expect(hasUsableAnswers('Lagos', 'Rex')).toBe(true);
    expect(hasUsableAnswers('Lagos', '')).toBe(false);
    expect(hasUsableAnswers('', '')).toBe(false);
    expect(hasUsableAnswers(null, undefined)).toBe(false);
    expect(hasUsableAnswers('  ', 'Rex')).toBe(false);
  });
});

describe('normalising an answer', () => {
  test('is idempotent, so a comparison cannot drift', () => {
    const once = normaliseAnswer('  My  First Dog ');
    expect(normaliseAnswer(once)).toBe(once);
    expect(once).toBe('my first dog');
  });
});
