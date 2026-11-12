// services/receipt_printer.dart
// Thermal receipt generation + Bluetooth printing (ESC/POS).
// The ESC/POS byte stream is built locally (no external generator dependency),
// keeping it compatible with the app's other packages.
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../utils/currency_helper.dart';

class ReceiptLineItem {
  final String name;
  final int quantity;
  final double price;
  const ReceiptLineItem({
    required this.name,
    required this.quantity,
    required this.price,
  });
  double get total => quantity * price;
}

class ReceiptData {
  final String companyName;
  final String companyAddress;
  final String companyPhone;
  final String companyEmail;
  final String orderId;
  final String customerName;
  final DateTime date;
  final List<ReceiptLineItem> items;
  final double totalAmount;
  final double amountPaid;
  final double balance;

  const ReceiptData({
    required this.companyName,
    this.companyAddress = '',
    this.companyPhone = '',
    this.companyEmail = '',
    required this.orderId,
    this.customerName = '',
    required this.date,
    required this.items,
    required this.totalAmount,
    required this.amountPaid,
    required this.balance,
  });
}

class ReceiptPrinter {
  ReceiptPrinter._();

  /// Plain monospace receipt text (used for preview, share and save).
  static String buildPlainText(ReceiptData d, {int width = 32}) {
    final lines = <String>[];
    String center(String s) {
      if (s.length >= width) return s.substring(0, width);
      final left = (width - s.length) ~/ 2;
      return s.padLeft(s.length + left).padRight(width);
    }

    lines.add(center(d.companyName));
    if (d.companyAddress.isNotEmpty) lines.add(center(d.companyAddress));
    final contact = [d.companyPhone, d.companyEmail]
        .where((s) => s.isNotEmpty)
        .join('  ');
    if (contact.isNotEmpty) lines.add(center(contact));
    lines.add('-'.padRight(width, '-'));
    lines.add('Order: ${d.orderId}');
    lines.add('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(d.date)}');
    if (d.customerName.isNotEmpty) lines.add('Customer: ${d.customerName}');
    lines.add('-'.padRight(width, '-'));
    for (final it in d.items) {
      lines.add(_formatItem(it, width));
    }
    lines.add('-'.padRight(width, '-'));
    lines.add(_row('Subtotal', CurrencyHelper.format(d.totalAmount), width));
    lines.add(_row('Paid', CurrencyHelper.format(d.amountPaid), width));
    lines.add(_row('Balance', CurrencyHelper.format(d.balance), width));
    lines.add('-'.padRight(width, '-'));
    lines.add(center('Thank you!'));
    lines.add('');
    return lines.join('\n');
  }

  static String _formatItem(ReceiptLineItem it, int width) {
    final left = '${it.name} x${it.quantity}';
    final right = CurrencyHelper.format(it.total);
    final maxLeft = width - right.length;
    final l = left.length > maxLeft ? left.substring(0, maxLeft) : left;
    return l.padRight(width - right.length) + right;
  }

  static String _row(String label, String value, int width) {
    return label.padRight(width - value.length) + value;
  }

  /// ESC/POS byte stream for a 58mm (width=32) or 80mm (width=48) printer.
  static List<int> buildEscPosBytes(ReceiptData d, {int width = 32}) {
    final b = <int>[];
    void esc(List<int> c) => b.addAll(c);
    void txt(String s, {int align = 0, bool doubleSize = false}) {
      esc([0x1B, 0x61, align]); // alignment: 0 left, 1 center, 2 right
      esc([0x1B, 0x21, doubleSize ? 0x30 : 0x00]); // double width + height
      b.addAll(_encode(s));
      esc([0x0A]);
    }

    esc([0x1B, 0x40]); // initialize
    txt(d.companyName, align: 1, doubleSize: true);
    if (d.companyAddress.isNotEmpty) txt(d.companyAddress, align: 1);
    final contact = [d.companyPhone, d.companyEmail]
        .where((s) => s.isNotEmpty)
        .join('  ');
    if (contact.isNotEmpty) txt(contact, align: 1);
    txt('-'.padRight(width, '-'));
    txt('Order: ${d.orderId}');
    txt('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(d.date)}');
    if (d.customerName.isNotEmpty) txt('Customer: ${d.customerName}');
    txt('-'.padRight(width, '-'));
    for (final it in d.items) {
      txt(_formatItem(it, width));
    }
    txt('-'.padRight(width, '-'));
    txt(_row('Subtotal', CurrencyHelper.format(d.totalAmount), width));
    txt(_row('Paid', CurrencyHelper.format(d.amountPaid), width));
    txt(_row('Balance', CurrencyHelper.format(d.balance), width));
    txt('-'.padRight(width, '-'));
    txt('Thank you!', align: 1);
    esc([0x1B, 0x64, 3]); // feed 3 lines
    esc([0x1D, 0x56, 1]); // partial cut
    return b;
  }

  /// Encode to a single-byte codepage (Latin-1 range), '?' otherwise.
  static List<int> _encode(String s) {
    return s.codeUnits.map((c) => c > 255 ? 0x3F : c).toList();
  }

  // ---------- Bluetooth printing (Android + Windows) ----------
  //
  // The pipeline is split into its steps on purpose. The old code connect → write →
  // disconnect in one call, so the app could never answer "is the printer
  // connected?" — a question a cashier asks before every print, and the reason a
  // failure was only ever discovered by losing a receipt. The screen now holds a
  // connection open, shows it, and can prove it with a test slip.

  /// Android needs the runtime Bluetooth permission before anything else works.
  static Future<bool> hasBluetoothPermission() async {
    if (kIsWeb) return false;
    try {
      return await PrintBluetoothThermal.isPermissionBluetoothGranted;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isBluetoothEnabled() async {
    if (kIsWeb) return false;
    try {
      return await PrintBluetoothThermal.bluetoothEnabled;
    } catch (_) {
      return false;
    }
  }

  static Future<List<BluetoothInfo>> pairedPrinters() async {
    if (kIsWeb) return [];
    try {
      return await PrintBluetoothThermal.pairedBluetooths;
    } catch (_) {
      return [];
    }
  }

  /// Is a socket open to a printer right now?
  static Future<bool> isConnected() async {
    if (kIsWeb) return false;
    try {
      return await PrintBluetoothThermal.connectionStatus;
    } catch (_) {
      return false;
    }
  }

  /// Opens the connection and KEEPS it, so the status card can be truthful.
  static Future<bool> connect(String macAddress) async {
    if (kIsWeb) return false;
    try {
      return await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
    } catch (_) {
      return false;
    }
  }

  static Future<void> disconnect() async {
    if (kIsWeb) return;
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {
      // Nothing to release — the socket was already gone.
    }
  }

  /// Sends bytes over the OPEN connection. Never connects: the caller decides when
  /// to, so a print can never silently pair to something else.
  static Future<bool> writeBytes(List<int> bytes) async {
    if (kIsWeb) return false;
    try {
      return await PrintBluetoothThermal.writeBytes(bytes);
    } catch (_) {
      return false;
    }
  }

  /// Connect (if needed) and write. Kept for callers that print in one go.
  static Future<bool> printViaBluetooth(
      List<int> bytes, String macAddress) async {
    if (!await isConnected()) {
      if (!await connect(macAddress)) return false;
    }
    return writeBytes(bytes);
  }

  /// A short slip that proves the paper, the feed and the connection BEFORE a real
  /// receipt is on the line.
  ///
  /// The caller passes already-translated lines: this service holds the ESC/POS
  /// bytes, not the copy, so the slip speaks the shop's language.
  static List<int> buildSlipBytes(List<String> lines, {int width = 32}) {
    final b = <int>[];
    void esc(List<int> c) => b.addAll(c);
    void txt(String s, {int align = 0, bool doubleSize = false}) {
      esc([0x1B, 0x61, align]);
      esc([0x1B, 0x21, doubleSize ? 0x30 : 0x00]);
      b.addAll(_encode(s));
      esc([0x0A]);
    }

    esc([0x1B, 0x40]); // initialize
    for (var i = 0; i < lines.length; i++) {
      txt(lines[i], align: i == 0 ? 1 : 0, doubleSize: i == 0);
    }
    txt('-'.padRight(width, '-'));
    esc([0x1B, 0x64, 3]); // feed 3 lines
    esc([0x1D, 0x56, 1]); // partial cut
    return b;
  }
}
