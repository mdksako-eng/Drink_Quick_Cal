// scripts/generate_campay_guide.dart
//
// Builds docs/CamerPay-Setup-Guide.pdf — the document a shop hands to whoever
// configures its CamerPay account.
//
// WHY A SCRIPT AND NOT A PDF IN THE REPO: a binary cannot be reviewed, diffed or
// corrected. The source of truth is this file; the PDF is an artefact you rebuild
// with:
//
//     dart run scripts/generate_campay_guide.dart      (from the repo root)
//
// It uses the `pdf` package the app already depends on (no new dependency) and
// deliberately sticks to the built-in Helvetica font, so it needs no network and
// no font files. For the same reason the text stays inside Latin-1: no emoji, no
// arrows, no typographic quotes — the French dashboard labels (e.g. "Tokens
// d'acces") do use their accents, which Latin-1 covers.
//
// The content mirrors what the code actually does — utils/campay.js,
// routes/payment.routes.js and utils/companyPaymentCredentials.js — plus
// CamerPay's published documentation (camerpay.biz/docs).

import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// The app's brand blue and teal, so this document looks like the app's reports.
const PdfColor _brand = PdfColor.fromInt(0xFF4361EE);
const PdfColor _accent = PdfColor.fromInt(0xFF2A9D8F);
const PdfColor _ink = PdfColor.fromInt(0xFF1F2937);
const PdfColor _muted = PdfColor.fromInt(0xFF6B7280);
const PdfColor _warn = PdfColor.fromInt(0xFFB45309);
const PdfColor _line = PdfColor.fromInt(0xFFD1D5DB);
const PdfColor _tint = PdfColor.fromInt(0xFFF3F4F6);

pw.Widget _h2(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 13, bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(text,
              style: pw.TextStyle(
                  fontSize: 13.5, fontWeight: pw.FontWeight.bold, color: _brand)),
          pw.SizedBox(height: 3),
          pw.Container(height: 1.2, width: 40, color: _brand),
        ],
      ),
    );

pw.Widget _p(String text, {double size = 10}) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Text(text,
          style: pw.TextStyle(fontSize: size, color: _ink, lineSpacing: 1.6)),
    );

pw.Widget _gap([double height = 8]) => pw.SizedBox(height: height);

pw.Widget _list(List<String> items) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final item in items)
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 8, bottom: 3),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 11,
                  child: pw.Text('-',
                      style: pw.TextStyle(
                          fontSize: 10,
                          color: _brand,
                          fontWeight: pw.FontWeight.bold)),
                ),
                pw.Expanded(
                  child: pw.Text(item,
                      style: pw.TextStyle(
                          fontSize: 10, color: _ink, lineSpacing: 1.5)),
                ),
              ],
            ),
          ),
      ],
    );

pw.Widget _steps(List<String> items) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 15,
                  height: 15,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                      color: _brand, borderRadius: pw.BorderRadius.circular(8)),
                  child: pw.Text('${i + 1}',
                      style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(width: 7),
                pw.Expanded(
                  child: pw.Text(items[i],
                      style: pw.TextStyle(
                          fontSize: 10, color: _ink, lineSpacing: 1.5)),
                ),
              ],
            ),
          ),
      ],
    );

/// A boxed remark. [warn] switches the accent to amber for the "this bites you"
/// notes (a wrong secret, a rotated token).
pw.Widget _callout({
  required String title,
  required List<String> lines,
  bool warn = false,
}) {
  final colour = warn ? _warn : _accent;
  return pw.Container(
    margin: const pw.EdgeInsets.only(top: 4, bottom: 7),
    padding: const pw.EdgeInsets.all(9),
    decoration: pw.BoxDecoration(
      color: _tint,
      border: pw.Border(left: pw.BorderSide(color: colour, width: 3)),
      borderRadius: pw.BorderRadius.circular(3),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title,
            style: pw.TextStyle(
                fontSize: 10, fontWeight: pw.FontWeight.bold, color: colour)),
        pw.SizedBox(height: 3),
        for (final line in lines)
          pw.Text(line,
              style:
                  pw.TextStyle(fontSize: 9.5, color: _ink, lineSpacing: 1.5)),
      ],
    ),
  );
}

/// Monospace block for a URL or a command line, so it can be copied exactly.
pw.Widget _code(String text) => pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.all(7),
      decoration: pw.BoxDecoration(
        color: _tint,
        border: pw.Border.all(color: _line, width: 0.5),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Text(text,
          style: pw.TextStyle(
              font: pw.Font.courier(),
              fontSize: 8.5,
              color: _ink,
              lineSpacing: 1.4)),
    );

pw.Widget _cell(String text, {bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 8.5,
              color: _ink,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              lineSpacing: 1.4)),
    );

pw.Widget _table(
  List<String> headers,
  List<List<String>> rows, {
  Map<int, pw.TableColumnWidth>? widths,
}) =>
    pw.Table(
      border: pw.TableBorder.all(color: _line, width: 0.5),
      columnWidths: widths,
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _tint),
          children: [for (final header in headers) _cell(header, bold: true)],
        ),
        for (final row in rows)
          pw.TableRow(children: [for (final value in row) _cell(value)]),
      ],
    );

pw.Widget _checklist(List<String> items) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final item in items)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 9,
                  height: 9,
                  margin: const pw.EdgeInsets.only(top: 1.5, right: 6),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _muted, width: 0.8),
                    borderRadius: pw.BorderRadius.circular(1.5),
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(item,
                      style: pw.TextStyle(
                          fontSize: 9.5, color: _ink, lineSpacing: 1.5)),
                ),
              ],
            ),
          ),
      ],
    );

List<pw.Widget> _cover() => [
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: pw.BoxDecoration(
          color: _brand,
          borderRadius: pw.BorderRadius.circular(5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Accepting payments from your customers',
                style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
            pw.SizedBox(height: 3),
            pw.Text('CamerPay setup guide for Drink Quick Cal',
                style: pw.TextStyle(
                    fontSize: 11, color: PdfColor.fromInt(0xFFDCE4FF))),
          ],
        ),
      ),
      _gap(12),
      _p(
          'This guide configures one shop so that its customers can pay by MTN MoMo, Orange Money, '
          'card or PayPal at the till. Everything below is done once; after that the cashier only '
          'rings a sale and shows a QR code.'),
      _callout(title: 'The money goes to you, not to us', lines: [
        'Each shop connects its OWN CamerPay account. Payments from your customers land in your '
            'CamerPay balance and are paid out to your bank or mobile-money wallet by CamerPay.',
        'That is why the token and the secret in this guide must come from YOUR CamerPay account.',
      ]),
      _p(
          'Two pieces of information are needed, and both come from your CamerPay dashboard:',
          size: 10),
      _list([
        'An API token - it lets our server start a payment on your behalf.',
        'A webhook secret - it proves that a payment confirmation really came from CamerPay.',
      ]),
      _gap(6),
      _p('You will also be shown a webhook URL. It is generated for you; you only copy it.',
          size: 10),
    ];

List<pw.Widget> _sectionBefore() => [
      _h2('1. Before you start'),
      _checklist([
        'A CamerPay merchant account. Sign up at camerpay.biz - a new account starts in sandbox '
            'mode, so you can follow this guide immediately and take real money after the KYC step '
            '(section 7).',
        'A MANAGER login in the app. Only a manager can open or change the payment settings.',
        'Your server online at a public https address (for example the Render URL). It must know '
            'that address: set APP_BASE_URL, or rely on the address Render provides automatically.',
        'PAYMENT_CREDENTIALS_KEY set on the server. Without it nothing can be stored at all and '
            'the app shows the blocker "vault_key_missing" - tell whoever runs the server.',
      ]),
      _callout(title: 'Who does what', lines: [
        'The shop manager does sections 2 to 5 in the app and in the CamerPay dashboard.',
        'Sections 1 and 7 also touch the server, so keep whoever runs it within reach.',
      ]),
    ];

List<pw.Widget> _sectionToken() => [
      _h2('2. Get your API token from CamerPay'),
      _steps([
        'Sign in at camerpay.biz with the account that will RECEIVE the money.',
        'Open the API section of the dashboard: /client/api',
        'Under "Tokens d\'acces" (access tokens), click "Generer un nouveau token".',
        'Give it a name you will recognise later, for example "Drink Quick Cal - <shop name>".',
        'Copy the token straight away. It is shown ONCE and cannot be read again; if you lose it, '
            'revoke it and generate another one.',
      ]),
      _callout(
        title: 'Treat the token like a wallet key',
        warn: true,
        lines: [
          'The token can start and read payments on your account. Do not paste it into a chat, a '
              'screenshot or a public ticket.',
          'If you think it leaked: revoke it in /client/api and generate a new one - then put the '
              'new one in the app (section 3).',
        ],
      ),
    ];

List<pw.Widget> _sectionAppToken() => [
      _h2('3. Put the token in the app'),
      _steps([
        'In the app, open Settings.',
        'Open the CamerPay section.',
        'Paste the token into "CamerPay API token" and save.',
        'If you are replacing a token that was already saved, the app asks for your password again. '
            'That is deliberate: this is the one setting that can send the shop\'s money to another '
            'CamerPay account.',
      ]),
      _p(
          'The token is write-only. The app only ever tells you that one is set - it never shows the '
          'value again, and an empty field means "keep the current token".'),
    ];

List<pw.Widget> _sectionWebhookUrl() => [
      _h2('4. Give CamerPay your webhook URL'),
      _p(
          'Once the token is saved, the app shows a box titled "Give this URL to CamerPay as your '
          'webhook". It looks like this:'),
      _code('https://<your-backend>/api/payment/campay-webhook/<long-token>'),
      _steps([
        'Copy that URL (it is selectable text).',
        'In the CamerPay dashboard, open "Webhook Configuration".',
        'Paste it into the field "Callback URL" and save.',
      ]),
      _p(
          'What that URL is: the long token at the end identifies WHICH shop the payment belongs to. '
          'It is unique to your company, which is why two shops must never be given the same URL.'),
      _callout(title: 'Why the dashboard field matters', lines: [
        'Our server also sends this URL with every payment it starts, so normal sales are already '
            'routed correctly.',
        'The dashboard field is the account-level safety net: it catches anything started from '
            'CamerPay itself (a payment link, an invoice) that our server never saw.',
      ]),
      _callout(
        title: 'Do not publish the URL',
        warn: true,
        lines: [
          'Anyone who has it can send requests to that endpoint. They still cannot forge a valid '
              'signature without the secret, so no fake payment can be confirmed - but there is no '
              'reason to put it in a public post.',
        ],
      ),
    ];

List<pw.Widget> _sectionSecret() => [
      _h2('5. The webhook secret (Secret HMAC)'),
      _steps([
        'In the same "Webhook Configuration" screen, find "Secret HMAC".',
        'Click "Generate" - or paste the secret this account already uses elsewhere - then copy it.',
        'In the app, paste it into "CamerPay webhook secret" and save.',
      ]),
      _p(
          'What it is for: CamerPay signs every webhook with this secret (HMAC-SHA256, sent as the '
          'X-CamerPay-Signature header and repeated in the body as "signature"). Our server '
          'recalculates the signature and refuses anything that does not match - that is what proves '
          'a payment confirmation really came from CamerPay and not from someone who guessed your URL.'),
      _callout(
        title: 'One account, one secret - and it must match exactly',
        warn: true,
        lines: [
          'The dashboard says it too: "Must be the same in WHMCS/WooCommerce". If this CamerPay '
              'account already feeds another system, generating a new secret breaks that system '
              'until you update it there as well.',
          'Copy it character for character. One wrong character and every webhook is refused, and '
              'payments will never confirm.',
          'If no secret is saved at all, payments still arrive but are never confirmed - the app '
              'warns about this in the CamerPay section.',
        ],
      ),
      _p(
          'Like the token, the secret is write-only: leave the field empty to keep the current one. '
          'The app only reports whether one is set.',
          size: 10),
    ];

List<pw.Widget> _sectionVerify() => [
      _h2('6. Check that it is wired'),
      _p('In the app, the CamerPay section should show the webhook URL and no blocker. The '
          'blockers it can show are:'),
      _table(
        ['Blocker', 'What is missing'],
        [
          ['no_token', 'No API token saved yet - section 3.'],
          ['no_webhook_secret', 'No webhook secret saved yet - section 5.'],
          ['vault_key_missing', 'A server-side key (PAYMENT_CREDENTIALS_KEY) is missing. Tell '
              'whoever runs the server; no shop can fix this from the app.'],
        ],
        widths: {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(5)},
      ),
      _gap(8),
      _p('Then take one real test payment and read the server log. A confirmed webhook prints:'),
      _code('CamerPay webhook verified for company <N> (signature mode: ..., status=completed,\n'
          'invoice=...)'),
      _p(
          'That line only appears when the signature verified. CamerPay shows the other side of it: '
          'the dashboard path /client/webhook-logs lists every delivery with its result, and each '
          'row has a "Rejouer" (replay) button.'),
      _callout(
        title: 'CamerPay does not retry our errors',
        warn: true,
        lines: [
          'CamerPay retries only NETWORK failures (a few attempts, 5 seconds each). If our server '
              'answers 401 or 500, the attempt is counted as done and is NOT retried.',
          'That is why a wrong secret looks like "nothing ever happens": fix the secret, then replay '
              'the delivery from /client/webhook-logs.',
        ],
      ),
    ];

List<pw.Widget> _sectionLive() => [
      _h2('7. Going live (real money)'),
      _steps([
        'Complete KYC in the CamerPay dashboard (/client/kyc). At minimum: the manager\'s national '
            'ID or the RCCM.',
        'Wait for validation - usually 24 to 48 business hours. CamerPay confirms by email, SMS and '
            'WhatsApp.',
        'Sandbox and live tokens are SEPARATE: generate a LIVE token and replace the sandbox one in '
            'the app.',
        'Whoever runs the server sets CAMERPAY_ACCOUNT_LIVE=true. This is our own declaration: '
            'CamerPay cannot tell us which mode the account is in.',
        'Take one small real payment (for example 500 XAF) and confirm the sale shows as paid in the '
            'app.',
      ]),
      _callout(
        title: 'Sandbox payments are ignored on purpose',
        warn: true,
        lines: [
          'Our server refuses a sandbox transaction so that a test can never mark a real order paid.',
          'The log then says "sandbox_payment". It is not a fault: it means the setup is fine but '
              'the payment came from a sandbox account. Only a live payment proves the chain.',
        ],
      ),
    ];

List<pw.Widget> _sectionSale() => [
      _h2('8. What happens at the till'),
      _steps([
        'The cashier rings the sale and chooses CamerPay.',
        'The app asks our server to start the payment. The server prices the cart itself, so the '
            'amount cannot be edited on the device, then asks CamerPay for a checkout link.',
        'The app shows a QR code on screen. The customer scans it and pays on their own phone - MTN '
            'MoMo, Orange Money, card or PayPal. No card data is handled at the counter and no phone '
            'changes hands.',
        'CamerPay posts the signed webhook to your URL.',
        'Our server verifies the signature, then re-reads the transaction from CamerPay using YOUR '
            'token, checks that the amount matches what was asked, and only then marks the order paid.',
        'The till shows the confirmation. Stock was already deducted when the sale was made.',
      ]),
      _callout(title: 'When a customer payment fails', lines: [
        'CamerPay now reports why: the webhook carries a readable reason and a code (for example '
            '"Le solde du compte du payeur est insuffisant", an incorrect PIN, or a card decline).',
        'Our log repeats both, so the cashier can tell the customer what to do - usually retry with '
            'another number or top up the wallet.',
      ]),
    ];

List<pw.Widget> _sectionTrouble() => [
      _h2('9. If something does not work'),
      _table(
        ['What you see', 'What it means', 'What to do'],
        [
          [
            'Payments arrive but are never confirmed',
            'No webhook secret saved, so no webhook can be trusted.',
            'Save the Secret HMAC in the app (section 5).',
          ],
          [
            'Log: "CamerPay webhook: invalid signature"',
            'The secret in the app does not match the account\'s Secret HMAC.',
            'Copy it again, character for character, and save.',
          ],
          [
            'Log: "unknown company token"',
            'You rotated the webhook token, so the URL changed.',
            'Paste the NEW URL from the app into the dashboard.',
          ],
          [
            'The webhook URL box never appears in the app',
            'The server does not know its public address.',
            'Set APP_BASE_URL (https) on the server, or use the address Render provides.',
          ],
          [
            'Log: "sandbox_payment"',
            'The payment was made from a sandbox account.',
            'Expected while testing. Install the LIVE token to take real money.',
          ],
          [
            'Log: "Could not verify the transaction"',
            'Our server could not re-read the payment from CamerPay.',
            'Retry; if it repeats, check the token and that the account is active.',
          ],
          [
            'The customer\'s payment fails',
            'The provider refused it (balance, PIN, limit, card).',
            'The log repeats CamerPay\'s reason and code - retry with another number.',
          ],
          [
            'Nothing arrives at all',
            'The Callback URL is missing, or it belongs to another account.',
            'Confirm the URL is saved, and that the token in the app is from the SAME account.',
          ],
        ],
        widths: {
          0: pw.FlexColumnWidth(3),
          1: pw.FlexColumnWidth(3),
          2: pw.FlexColumnWidth(3),
        },
      ),
      _gap(8),
      _p('CamerPay lists these five causes most often on their side, in case you need to talk to '
          'their support:'),
      _list([
        'A signature that does not match: the secret configured here is not the one the account uses.',
        'Parsing the body as JSON: it is form-encoded, not JSON. (Our server already handles this.)',
        'An expired or self-signed HTTPS certificate: CamerPay refuses it.',
        'An endpoint slower than 10 seconds, which is counted as a failure.',
        'An internal URL (localhost, 192.168.x.x): CamerPay blocks those to prevent SSRF.',
      ]),
    ];

List<pw.Widget> _sectionRules() => [
      _h2('10. Rules worth remembering'),
      _list([
        'One CamerPay account has ONE Secret HMAC. If the same account is used by another system (a '
            'shop website, WHMCS, WooCommerce), every system must hold that same secret.',
        'Prefer a separate CamerPay account per purpose. Sharing one token between several services '
            'is what CamerPay itself advises against, and separate accounts keep the money and the '
            'secrets apart.',
        'Rotating the webhook token changes the URL. Update the dashboard the same day, or webhooks '
            'will be refused as "unknown company token".',
        'Only a manager can change these settings, and replacing the API token asks for the '
            'password again.',
        'The API token and the webhook secret are never shown again by the app. Keep them where the '
            'shop keeps its other credentials.',
        'CamerPay charges its fees on deposits and withdrawals - check your current pricing with '
            'CamerPay. Our server can either absorb the fee or add it on top of the price the '
            'customer sees (a server setting, CAMERPAY_FEE_MODE).',
        'The webhook URL carries an opaque per-shop token: it is not a password, but treat it as '
            'private.',
      ]),
    ];

List<pw.Widget> _sectionChecklist() => [
      _h2('11. One-page checklist'),
      _checklist([
        'CamerPay merchant account created and confirmed by email.',
        'API token generated in /client/api and copied.',
        'Token saved in the app (Settings, CamerPay) by a manager.',
        'Webhook URL from the app pasted into CamerPay, Webhook Configuration, Callback URL.',
        'Secret HMAC generated (or the existing one copied) and saved in the app.',
        'Server has PAYMENT_CREDENTIALS_KEY and a public https address.',
        'The app shows the webhook URL and no blocker.',
        'One real payment taken and confirmed in the app.',
        'KYC approved and the LIVE token installed for real money.',
        'Staff know where to look when a customer payment fails (section 9).',
      ]),
    ];

String _two(int value) => value.toString().padLeft(2, '0');

Future<void> main() async {
  final doc = pw.Document(
    title: 'CamerPay setup guide - Drink Quick Cal',
    author: 'Drink Quick Cal',
    creator: 'scripts/generate_campay_guide.dart',
  );

  final now = DateTime.now();
  final stamp = '${now.year}-${_two(now.month)}-${_two(now.day)}';

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(34, 34, 34, 40),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          'Drink Quick Cal - CamerPay setup guide - page '
          '${context.pageNumber}/${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: _muted),
        ),
      ),
      build: (context) => [
        ..._cover(),
        ..._sectionBefore(),
        ..._sectionToken(),
        ..._sectionAppToken(),
        ..._sectionWebhookUrl(),
        ..._sectionSecret(),
        ..._sectionVerify(),
        ..._sectionLive(),
        ..._sectionSale(),
        ..._sectionTrouble(),
        ..._sectionRules(),
        ..._sectionChecklist(),
        _gap(10),
        pw.Divider(color: _line),
        _p(
            'Generated $stamp from the Drink Quick Cal backend. CamerPay documentation: '
            'camerpay.biz/docs - webhook deliveries and replay: /client/webhook-logs.',
            size: 8.5),
      ],
    ),
  );

  final file = File('docs/CamerPay-Setup-Guide.pdf');
  await file.parent.create(recursive: true);
  final bytes = await doc.save();
  await file.writeAsBytes(bytes);
  stdout.writeln(
      'Wrote ${file.path} (${(bytes.length / 1024).toStringAsFixed(0)} KB)');
}







