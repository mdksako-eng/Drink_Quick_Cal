// screens/receipt_print_screen.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:share_plus/share_plus.dart';
import '../models/drink_model.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/receipt_printer.dart';
import '../utils/helpers.dart';
import '../utils/i18n.dart';
import '../utils/printer_status_helper.dart';
import '../theme/app_theme.dart';

class ReceiptPrintScreen extends StatefulWidget {
  final List<Drink> drinks;
  final double totalAmount;
  final double amountPaid;
  final double balance;
  final String? orderId;
  final String? customerName;
  final String companyName;
  final String companyAddress;
  final String companyPhone;
  final String companyEmail;

  /// The ORIGINAL order date. A reprinted receipt must not be dated today.
  final DateTime? date;

  const ReceiptPrintScreen({
    Key? key,
    required this.drinks,
    required this.totalAmount,
    required this.amountPaid,
    required this.balance,
    this.orderId,
    this.customerName,
    this.companyName = 'Drink Quick Cal',
    this.companyAddress = '',
    this.companyPhone = '',
    this.companyEmail = '',
    this.date,
  }) : super(key: key);

  @override
  State<ReceiptPrintScreen> createState() => _ReceiptPrintScreenState();
}

class _ReceiptPrintScreenState extends State<ReceiptPrintScreen> {
  int _paperWidth = 32; // 58mm ~ 32 chars; 80mm ~ 48 chars
  bool _busy = false;

  /// The printer the shop uses, remembered on the DEVICE.
  ///
  /// Deliberately not company-scoped cache: the till keeps the same physical printer
  /// whoever signs in, so it survives a sign-out the way the device PIN does.
  static const String _macKey = 'receipt_printer_mac';
  static const String _nameKey = 'receipt_printer_name';

  PrinterState _printerState = PrinterState.notConnected;
  BluetoothInfo? _printer;
  bool _connecting = false;
  String _rememberedMac = '';
  String _rememberedName = '';

  @override
  void initState() {
    super.initState();
    // Ask on open, not when the print button is pressed: the cashier then sees the
    // truth before a receipt is at stake, and the saved printer reconnects itself.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshPrinterState(autoConnect: true);
    });
  }

  ReceiptData get _data {
    final counts = <String, int>{};
    final prices = <String, double>{};
    for (final d in widget.drinks) {
      counts[d.name] = (counts[d.name] ?? 0) + 1;
      prices[d.name] = d.price;
    }
    final items = <ReceiptLineItem>[];
    counts.forEach((name, qty) {
      items.add(ReceiptLineItem(
          name: name, quantity: qty, price: prices[name] ?? 0));
    });
    return ReceiptData(
      companyName: widget.companyName,
      companyAddress: widget.companyAddress,
      companyPhone: widget.companyPhone,
      companyEmail: widget.companyEmail,
      orderId:
          widget.orderId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      customerName: widget.customerName ?? '',
      date: widget.date ?? DateTime.now(),
      items: items,
      totalAmount: widget.totalAmount,
      amountPaid: widget.amountPaid,
      balance: widget.balance,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final text = ReceiptPrinter.buildPlainText(_data, width: _paperWidth);
    return Scaffold(
      appBar: AppBar(
        title: Text(t('receiptTitle')),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildPrinterCard(),
          _buildPaperSelector(primary),
          Expanded(child: _buildPreview(text)),
          _buildActions(primary),
        ],
      ),
    );
  }

  /// 🖨️ The status card — the answer to "is the printer connected?" that the screen
  /// never used to give: the state in words, what to do about it, and a test slip that
  /// proves the paper before a real receipt is at stake.
  Widget _buildPrinterCard() {
    final state = _printerState;
    final ready = PrinterStatusHelper.isReady(state);
    final blocked = PrinterStatusHelper.needsSetup(state);
    final color = ready
        ? Colors.green
        : blocked
            ? Colors.orange
            : Colors.blueGrey;
    final device = _printer;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (_connecting)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(ready ? Icons.print : Icons.print_disabled, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t(PrinterStatusHelper.titleKey(state)),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      if (device != null)
                        Text(
                          PrinterStatusHelper.deviceLabel(device),
                          style: const TextStyle(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: t('printerRefresh'),
                  visualDensity: VisualDensity.compact,
                  onPressed: _busy || _connecting
                      ? null
                      : () => _refreshPrinterState(),
                  icon: const Icon(Icons.refresh, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              t(PrinterStatusHelper.hintKey(state)),
              style: const TextStyle(fontSize: 12),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (state == PrinterState.noPrinterPaired)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _choosePrinter(),
                    icon: const Icon(Icons.search, size: 16),
                    label: Text(t('printerFindPrinters')),
                  )
                else if (!ready)
                  ElevatedButton.icon(
                    onPressed: _busy || _connecting ? null : () => _connectNow(),
                    icon: const Icon(Icons.link, size: 16),
                    label: Text(t('printerConnect')),
                  )
                else ...[
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _disconnect(),
                    icon: const Icon(Icons.link_off, size: 16),
                    label: Text(t('printerDisconnect')),
                  ),
                  ElevatedButton.icon(
                    onPressed: _busy ? null : () => _testPrint(),
                    icon: const Icon(Icons.receipt_long, size: 16),
                    label: Text(t('printerTestPrint')),
                  ),
                ],
                if (state != PrinterState.noPrinterPaired)
                  TextButton(
                    onPressed: _busy ? null : () => _choosePrinter(),
                    child: Text(t('printerChoose')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaperSelector(Color primary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Text(t('receiptPaper'),
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(width: 12),
          ChoiceChip(
            label: const Text('58mm'),
            selected: _paperWidth == 32,
            onSelected: (_) => setState(() => _paperWidth = 32),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('80mm'),
            selected: _paperWidth == 48,
            onSelected: (_) => setState(() => _paperWidth = 48),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.smallAll,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: AppAlpha.subtle), blurRadius: 8),
          ],
          border: Border.all(color: Colors.black.withValues(alpha: AppAlpha.subtle)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: Colors.black,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(Color primary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: AppAlpha.faint), blurRadius: 10),
        ],
      ),
      child: SafeArea(
        child: Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _print,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.print),
              label: Text(t('receiptPrint')),
              style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _share,
              icon: const Icon(Icons.share),
              label: Text(t('receiptShare')),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(t('receiptSave')),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ]),
      ),
    );
  }

  // ============================================================
  // 🖨️ PRINTER STATE — the answer to "is the printer connected?"
  // ============================================================

  /// Reads the facts and turns them into what the card shows. Runs on open, after
  /// every action, and when the shop taps Refresh — which is also how they come back
  /// from Android settings.
  Future<void> _refreshPrinterState({bool autoConnect = false}) async {
    if (kIsWeb) {
      if (mounted) setState(() => _printerState = PrinterState.unsupported);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    _rememberedMac = prefs.getString(_macKey) ?? '';
    _rememberedName = prefs.getString(_nameKey) ?? '';

    final permission = await ReceiptPrinter.hasBluetoothPermission();
    final enabled = await ReceiptPrinter.isBluetoothEnabled();
    final paired = await ReceiptPrinter.pairedPrinters();
    final connected = await ReceiptPrinter.isConnected();

    // Match the remembered printer against what is paired NOW: a pairing can be
    // deleted in Android settings, and the card must say so rather than pretend the
    // printer is still there.
    final inUse = PrinterStatusHelper.findRemembered(paired, _rememberedMac) ??
        (connected && _rememberedMac.isNotEmpty
            ? BluetoothInfo(name: _rememberedName, macAdress: _rememberedMac)
            : null);

    if (!mounted) return;
    setState(() {
      _printer = inUse;
      _printerState = PrinterStatusHelper.derive(
        bluetoothEnabled: enabled,
        permissionGranted: permission,
        pairedCount: paired.length,
        connected: connected,
      );
    });

    // Reconnect the saved printer without being asked — but never when the shop has
    // something to fix first (Bluetooth off, permission refused).
    if (!autoConnect || inUse == null || connected) return;
    if (_printerState != PrinterState.notConnected) return;
    await _connect(inUse);
  }

  Future<void> _remember(BluetoothInfo printer) async {
    _rememberedMac = printer.macAdress;
    _rememberedName = printer.name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_macKey, printer.macAdress);
    await prefs.setString(_nameKey, printer.name);
  }

  /// Opens the connection and KEEPS it, so "connected" on the card is a fact rather
  /// than a guess.
  Future<bool> _connect(BluetoothInfo printer) async {
    setState(() {
      _connecting = true;
      _printerState = PrinterState.connecting;
    });
    final ok = await ReceiptPrinter.connect(printer.macAdress);
    if (!mounted) return ok;
    setState(() {
      _connecting = false;
      if (ok) _printer = printer;
      _printerState = ok ? PrinterState.connected : PrinterState.failed;
    });
    if (ok) {
      await _remember(printer);
      Helpers.showToast('${t('printerConnectedTitle')} · '
          '${PrinterStatusHelper.deviceLabel(printer)}');
    } else {
      Helpers.showToast(t('receiptPrintFailed'), isError: true);
    }
    return ok;
  }

  Future<void> _disconnect() async {
    await ReceiptPrinter.disconnect();
    if (!mounted) return;
    setState(() => _printerState = PrinterState.notConnected);
    Helpers.showToast(t('printerNotConnectedTitle'));
  }

  /// The printer to use: the connected one, the remembered one, or whatever the shop
  /// picks from the paired list. Never invents a device.
  Future<BluetoothInfo?> _resolvePrinter() async {
    if (_printer != null) return _printer;
    final paired = await ReceiptPrinter.pairedPrinters();
    if (!mounted) return null;
    if (paired.isEmpty) {
      setState(() => _printerState = PrinterState.noPrinterPaired);
      Helpers.showToast(t('printerNonePairedHint'), isError: true);
      return null;
    }
    final remembered = PrinterStatusHelper.findRemembered(paired, _rememberedMac);
    if (remembered != null) return remembered;

    // Nothing saved, or it is gone: one tap to choose, with the machines named.
    if (_rememberedMac.isNotEmpty) {
      Helpers.showToast(t('printerRememberedGone'));
    }
    return _showPrinterPicker(paired);
  }

  /// Connect if needed and hand back the printer that is ready, or null when the shop
  /// has something to fix first (the card says what).
  Future<BluetoothInfo?> _ensureConnected() async {
    if (await ReceiptPrinter.isConnected()) return _printer;
    final printer = await _resolvePrinter();
    if (printer == null) return null;
    return await _connect(printer) ? printer : null;
  }

  Future<void> _print() async {
    if (kIsWeb) {
      Helpers.showToast(t('printerWebTitle'));
      return;
    }
    setState(() => _busy = true);
    try {
      final printer = await _ensureConnected();
      if (printer == null) return;
      final bytes = ReceiptPrinter.buildEscPosBytes(_data, width: _paperWidth);
      final ok = await ReceiptPrinter.writeBytes(bytes);
      if (!mounted) return;
      // A failed write usually means the socket dropped (printer switched off, out of
      // range). Reflect it on the card instead of leaving a stale "connected".
      setState(
          () => _printerState = ok ? PrinterState.connected : PrinterState.failed);
      Helpers.showToast(
        ok ? t('receiptPrinted') : t('receiptPrintFailed'),
        isError: !ok,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Proves paper, feed and connection BEFORE a real receipt is at stake. The lines
  /// go in already translated: the printer service holds the bytes, not the copy.
  Future<void> _testPrint() async {
    if (kIsWeb) {
      Helpers.showToast(t('printerWebTitle'));
      return;
    }
    setState(() => _busy = true);
    try {
      final printer = await _ensureConnected();
      if (printer == null) return;
      final bytes = ReceiptPrinter.buildSlipBytes([
        t('printerTestHeadline'),
        t('printerTestReady'),
        DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
        t('printerTestNoSale'),
      ], width: _paperWidth);
      final ok = await ReceiptPrinter.writeBytes(bytes);
      if (!mounted) return;
      setState(
          () => _printerState = ok ? PrinterState.connected : PrinterState.failed);
      Helpers.showToast(
        ok ? t('printerTestSent') : t('receiptPrintFailed'),
        isError: !ok,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    final text = ReceiptPrinter.buildPlainText(_data, width: _paperWidth);
    await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _save() async {
    final text = ReceiptPrinter.buildPlainText(_data, width: _paperWidth);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.txt');
      await file.writeAsString(text);
      if (!mounted) return;
      Helpers.showToast(t('receiptSaved'));
    } catch (e) {
      debugPrint('Receipt save failed: $e');
      if (mounted) Helpers.showToast(t('errorGeneric'), isError: true);
    }
  }

  /// The paired printers, named — with the one in use marked, so re-choosing after a
  /// printer change is one tap and no guesswork.
  Future<BluetoothInfo?> _showPrinterPicker(List<BluetoothInfo> printers) {
    return showDialog<BluetoothInfo>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(t('receiptSelectPrinter')),
        children: printers.map((p) {
          final isCurrent = p.macAdress.trim().toUpperCase() ==
              _rememberedMac.trim().toUpperCase();
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, p),
            child: ListTile(
              leading: Icon(isCurrent ? Icons.print : Icons.bluetooth),
              // A thermal printer very often has no name at all — show the MAC then.
              title: Text(PrinterStatusHelper.deviceLabel(p)),
              subtitle: Text(p.macAdress),
              trailing: isCurrent ? const Icon(Icons.check, size: 18) : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _connectNow() async {
    final printer = await _resolvePrinter();
    if (printer == null) return;
    await _connect(printer);
  }

  /// Choose a printer explicitly — the path a shop takes when they buy a new one, or
  /// when the saved one was re-paired in system settings.
  Future<void> _choosePrinter() async {
    final paired = await ReceiptPrinter.pairedPrinters();
    if (!mounted) return;
    if (paired.isEmpty) {
      setState(() => _printerState = PrinterState.noPrinterPaired);
      Helpers.showToast(t('printerNonePairedHint'), isError: true);
      return;
    }
    final picked = await _showPrinterPicker(paired);
    if (picked == null) return;
    await _connect(picked);
  }
}

