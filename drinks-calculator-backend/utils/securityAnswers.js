// utils/securityAnswers.js
//
// Comparing what a shop typed for its two security questions at registration with what is
// typed at reset time.
//
// WHY IT IS NOT A PLAIN !==. The answer was typed once, months ago, on one phone keyboard
// and is typed again today on another: " Lagos " and "lagos" are the same answer to a human
// and have to be to us, or the account is locked out by a space.
//
// WHAT MUST NEVER MATCH is an account whose stored answers are empty — a row created before
// this feature existed, or one where a failed insert wrote ''. An empty answer would then
// answer its own question and anyone who knows a username and email could take the account.
// So an empty stored answer refuses the reset outright, and an empty attempt never matches.
//
// Pure, so the rule is testable without a server (tests/security_answers.test.js).

/// Trimmed, lower-cased, inner whitespace collapsed. '' for anything unusable.
function normaliseAnswer(value) {
  if (value === null || value === undefined) return '';
  return String(value).trim().toLowerCase().replace(/\s+/g, ' ');
}

/// Can this account be reset with security answers at all?
function hasUsableAnswers(storedAnswer1, storedAnswer2) {
  return (
    normaliseAnswer(storedAnswer1) !== '' &&
    normaliseAnswer(storedAnswer2) !== ''
  );
}

/// True only when both sides are non-empty and equal once normalised.
function answersMatch(storedAnswer, providedAnswer) {
  const stored = normaliseAnswer(storedAnswer);
  const provided = normaliseAnswer(providedAnswer);
  if (stored === '' || provided === '') return false;
  return stored === provided;
}

module.exports = { normaliseAnswer, hasUsableAnswers, answersMatch };
