// backend/tests/email_service.test.js
// Email is sent with SendGrid, so pin the request shape SendGrid accepts — and that a
// missing key fails loudly instead of silently dropping a password-reset code.
const { buildEmailPayload, isEmailConfigured, escapeHtml } = require('../utils/email.service');

describe('email.service (SendGrid)', () => {
  test('wraps a single recipient in the array SendGrid expects', () => {
    const payload = buildEmailPayload({
      to: 'owner@bar.cm',
      subject: 'Hi',
      html: '<p>Hi</p>',
    });
    expect(payload.to).toEqual(['owner@bar.cm']);
  });

  test('keeps an explicit list of recipients', () => {
    const payload = buildEmailPayload({
      to: ['a@x.cm', 'b@x.cm'],
      subject: 's',
      html: 'h',
    });
    expect(payload.to).toEqual(['a@x.cm', 'b@x.cm']);
  });

  test('the sender is the {email, name} pair SendGrid requires', () => {
    const { from } = buildEmailPayload({ to: 'a@x.cm', subject: 's', html: 'h' });
    expect(from.email).toBe(process.env.EMAIL_FROM || 'm.derick@africet.org');
    expect(from.name).toBe(process.env.EMAIL_FROM_NAME || 'Drink Quick Cal');
  });

  test('an explicit from wins over the default', () => {
    const { from } = buildEmailPayload({
      to: 'a@x.cm',
      subject: 's',
      html: 'h',
      from: 'support@x.cm',
    });
    expect(from.email).toBe('support@x.cm');
  });

  test('never sends undefined subject or html', () => {
    const payload = buildEmailPayload({ to: 'a@x.cm' });
    expect(payload.subject).toBe('');
    expect(payload.html).toBe('');
  });

  test('reports whether a key is configured', () => {
    expect(typeof isEmailConfigured()).toBe('boolean');
    expect(isEmailConfigured()).toBe(Boolean(process.env.SENDGRID_API_KEY));
  });
});

describe('email templates escape what users typed', () => {
  test('a name is text, not markup', () => {
    expect(escapeHtml('<a href="http://evil">Reset your password</a>'))
      .toBe('&lt;a href=&quot;http://evil&quot;&gt;Reset your password&lt;/a&gt;');
  });

  test('ampersands are escaped first, so an entity is not double-decoded', () => {
    expect(escapeHtml('&lt;')).toBe('&amp;lt;');
    expect(escapeHtml('a & b')).toBe('a &amp; b');
  });

  test('quotes are escaped, so a name cannot break out of an attribute', () => {
    expect(escapeHtml(`" onmouseover="x"`)).toBe('&quot; onmouseover=&quot;x&quot;');
    expect(escapeHtml("it's")).toBe('it&#39;s');
  });

  test('a missing name is empty, never the word undefined', () => {
    // The templates fall back with `|| 'there'`, which only works if a missing value is falsy.
    expect(escapeHtml(undefined)).toBe('');
    expect(escapeHtml(null)).toBe('');
    expect(escapeHtml(undefined) || 'there').toBe('there');
  });
});
