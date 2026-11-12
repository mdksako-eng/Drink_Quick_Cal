// utils/aiVisionPrompt.js
// The instructions that turn a PHOTO into an order — one pure function, so the wording
// that decides whether the AI understands a receipt is TESTED instead of living inline in
// the route (this project's rule: pure logic in utils/, with a matching Jest test).
//
// Each rule below is doing a job, and each one was added because its absence cost
// something real:
//   * the shop's own menu is listed and the model is told to prefer those exact spellings,
//     because the app matches the reply back to the catalogue — an invented spelling
//     scores below the match threshold and the line vanishes with no explanation;
//   * a drink that is NOT on the menu is still REPORTED, with the name as written in the
//     image. The previous wording ("use the drink names exactly as written above when they
//     match") read as "drop anything else", so a shop never learned the AI had read a
//     drink it does not sell — or that it had garbled the spelling of one it does;
//   * an unreadable line must be ADMITTED, never guessed: a hallucinated drink silently
//     adds stock nobody ordered, which is worse than "one line was too faint to read";
//   * a missing quantity is 1 rather than invented;
//   * no ORDER_JSON line at all when the photo holds no order, so a picture of a wall
//     cannot produce an empty order that looks like a successful reading.
const MAX_MENU_NAMES = 60;

/** The menu as one comma-separated line, bounded so the prompt cannot grow without end. */
function menuLine(menu) {
  if (!Array.isArray(menu)) return String(menu || '').trim();
  return menu.filter(Boolean).slice(0, MAX_MENU_NAMES).join(', ');
}

/**
 * Builds the vision prompt.
 * @param {{menu?: string[]|string, context?: string}} args
 * @returns {string} a single line of instructions (the model gets one paragraph)
 */
function buildVisionPrompt({ menu = '', context = '' } = {}) {
  const names = menuLine(menu);
  const extra = String(context || '').trim();

  return [
    'You read photos of drink orders (handwritten notes, receipts, screenshots, menus).',
    names ? `This shop only sells: ${names}.` : '',
    'Extract every ordered drink and its quantity.',
    'Start with one short friendly sentence describing what you found, then a line exactly like:',
    'ORDER_JSON: [{"name":"<drink>","qty":<number>}]',
    'Spell every name as it appears in the shop list above whenever the photo matches one of them.',
    'If you can read a drink that is NOT in that list, still include it, spelled as it is written in the photo.',
    'If part of the photo is too faint, cropped or unclear to read, do not guess it: say which line was unclear and leave it out of ORDER_JSON.',
    'If a quantity is not written, use 1 rather than a number you invent.',
    'If the image contains no order, say so and do NOT include an ORDER_JSON line.',
    extra ? `Extra context from the user: ${extra}` : '',
  ].filter(Boolean).join(' ');
}

module.exports = { buildVisionPrompt, menuLine, MAX_MENU_NAMES };
