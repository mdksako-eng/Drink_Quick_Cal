// tests/ai_vision_prompt.test.js
// The wording that decides whether a photo of a handwritten order is understood.
//
// It is a prompt, so the test cannot assert accuracy — but it CAN pin the rules whose
// absence cost something real: dropped off-menu drinks, invented names, invented
// quantities, and an ORDER_JSON block for a photo with no order.
const {
  buildVisionPrompt,
  menuLine,
  MAX_MENU_NAMES,
} = require('../utils/aiVisionPrompt');

const MENU = ['Beer', 'Mutzig', 'Coca'];

describe('menuLine', () => {
  test('joins the catalogue for the prompt', () => {
    expect(menuLine(MENU)).toBe('Beer, Mutzig, Coca');
  });

  test('caps the list so the prompt cannot grow without end', () => {
    const many = Array.from({ length: MAX_MENU_NAMES + 25 }, (_, i) => `D${i}`);
    expect(menuLine(many).split(', ')).toHaveLength(MAX_MENU_NAMES);
  });

  test('an empty or missing menu is an empty line, never the word undefined', () => {
    expect(menuLine([])).toBe('');
    expect(menuLine(null)).toBe('');
    expect(menuLine(undefined)).toBe('');
    expect(menuLine('Beer')).toBe('Beer');
  });

  test('drops empty entries a caller may have left in the array', () => {
    expect(menuLine(['Beer', '', null, 'Coca'])).toBe('Beer, Coca');
  });
});

describe('buildVisionPrompt', () => {
  test('names the shop menu and asks for the machine-readable block', () => {
    const prompt = buildVisionPrompt({ menu: MENU });
    expect(prompt).toContain('This shop only sells: Beer, Mutzig, Coca.');
    expect(prompt).toContain('ORDER_JSON: [{"name":"<drink>","qty":<number>}]');
  });

  test('a drink that is NOT on the menu is still reported, not dropped', () => {
    // The old wording read as "drop anything else", so the shop never learned the AI had
    // read a drink it does not sell.
    const prompt = buildVisionPrompt({ menu: MENU });
    expect(prompt).toMatch(/NOT in that list, still include it/i);
  });

  test('an unreadable line must be admitted, never guessed', () => {
    const prompt = buildVisionPrompt({ menu: MENU });
    expect(prompt).toMatch(/do not guess it/i);
    expect(prompt).toMatch(/unclear/i);
  });

  test('a missing quantity is 1, not an invented number', () => {
    expect(buildVisionPrompt({ menu: MENU })).toMatch(/not written, use 1/i);
  });

  test('a photo with no order produces no ORDER_JSON line', () => {
    expect(buildVisionPrompt({ menu: MENU })).toMatch(/no order[\s\S]*do NOT include an ORDER_JSON line/i);
  });

  test('extra context is passed through, and omitted when there is none', () => {
    const withContext = buildVisionPrompt({
      menu: MENU,
      context: 'The order already contains 2x Beer.',
    });
    expect(withContext).toContain('Extra context from the user: The order already contains 2x Beer.');
    expect(buildVisionPrompt({ menu: MENU })).not.toContain('Extra context from the user');
  });

  test('works with no menu at all, without a dangling sentence', () => {
    const prompt = buildVisionPrompt({});
    expect(prompt).not.toContain('This shop only sells');
    expect(prompt).not.toContain('undefined');
    expect(prompt).toContain('ORDER_JSON');
  });

  test('one paragraph, because the model is handed a single instruction line', () => {
    const prompt = buildVisionPrompt({ menu: MENU, context: 'x' });
    expect(prompt).not.toMatch(/\n/);
    expect(prompt).not.toMatch(/ {2}/);
  });
});
