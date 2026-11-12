// utils/printer_status_helper.dart
// "Is the printer ready?" — the one question a cashier asks before pressing print.
//
// The Bluetooth plugin exposes FACTS (is Bluetooth on? was the permission granted?
// how many devices are paired? is a socket open?) but nothing a shop can act on,
// and the old screen answered only with a toast AFTER a print had already failed.
// This turns those facts into the state the status card shows and the sentence that
// says what to do next.
//
// Pure — only the plugin's plain `BluetoothInfo` data class is touched, never a
// platform channel — so every combination is unit tested instead of being guessed
// at inside a widget.
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

/// Where the printer is, in words a cashier can act on.
enum PrinterState {
  /// The thermal printer is Android/Windows only; the web build cannot print.
  unsupported,

  /// Android refused Bluetooth permission — nothing works until it is granted.
  permissionDenied,

  /// The device's Bluetooth is switched off.
  bluetoothOff,

  /// Bluetooth is on, but no printer was ever paired in system settings.
  noPrinterPaired,

  /// Paired, but nothing is connected right now.
  notConnected,

  connecting,

  connected,

  /// A connect attempt was made and did not get through.
  failed,
}

class PrinterStatusHelper {
  PrinterStatusHelper._();

  /// The user-facing state, derived from the facts in one place.
  static PrinterState derive({
    bool isWeb = false,
    bool bluetoothEnabled = false,
    bool permissionGranted = true,
    int pairedCount = 0,
    bool connected = false,
  }) {
    if (isWeb) return PrinterState.unsupported;
    // Bluetooth OFF is checked before the permission on purpose: Android also reports
    // the runtime permission as missing while Bluetooth is off, and "switch Bluetooth
    // on" is the only instruction the shop can act on at that moment.
    if (!bluetoothEnabled) return PrinterState.bluetoothOff;
    if (!permissionGranted) return PrinterState.permissionDenied;
    if (pairedCount <= 0) return PrinterState.noPrinterPaired;
    if (connected) return PrinterState.connected;
    return PrinterState.notConnected;
  }

  /// The printer we remember, matched against what is paired RIGHT NOW.
  ///
  /// Returns null when it is gone — a new printer was paired, or the old pairing
  /// was deleted — which is what lets the screen say "choose your printer again"
  /// instead of quietly doing nothing.
  static BluetoothInfo? findRemembered(
    List<BluetoothInfo> paired,
    String? rememberedMac,
  ) {
    final mac = (rememberedMac ?? '').trim().toUpperCase();
    if (mac.isEmpty) return null;
    for (final printer in paired) {
      if ((printer.macAdress).trim().toUpperCase() == mac) return printer;
    }
    return null;
  }

  /// A name to show.
  ///
  /// Thermal printers very often report an empty name (or a bare `?`), and
  /// "Printer" tells nobody which one is on the shelf — the MAC does.
  static String deviceLabel(BluetoothInfo printer) {
    final name = (printer.name).trim();
    if (name.isEmpty || name == '?' || name.toLowerCase() == 'null') {
      return (printer.macAdress).trim();
    }
    return name;
  }

  /// The card's headline.
  static String titleKey(PrinterState state) {
    switch (state) {
      case PrinterState.unsupported:
        return 'printerWebTitle';
      case PrinterState.permissionDenied:
        return 'printerPermissionTitle';
      case PrinterState.bluetoothOff:
        return 'printerBtOffTitle';
      case PrinterState.noPrinterPaired:
        return 'printerNonePairedTitle';
      case PrinterState.notConnected:
        return 'printerNotConnectedTitle';
      case PrinterState.connecting:
        return 'printerConnectingTitle';
      case PrinterState.connected:
        return 'printerConnectedTitle';
      case PrinterState.failed:
        return 'printerFailedTitle';
    }
  }

  /// What to DO about it — the part that was missing before.
  static String hintKey(PrinterState state) {
    switch (state) {
      case PrinterState.unsupported:
        return 'printerWebHint';
      case PrinterState.permissionDenied:
        return 'printerPermissionHint';
      case PrinterState.bluetoothOff:
        return 'printerBtOffHint';
      case PrinterState.noPrinterPaired:
        return 'printerNonePairedHint';
      case PrinterState.notConnected:
        return 'printerNotConnectedHint';
      case PrinterState.connecting:
        return 'printerConnectingHint';
      case PrinterState.connected:
        return 'printerConnectedHint';
      case PrinterState.failed:
        return 'printerFailedHint';
    }
  }

  /// Is a print worth attempting? Waiting to be connected still counts: the print
  /// action connects first. Everything else has to be fixed by the shop.
  static bool canAttemptPrint(PrinterState state) {
    switch (state) {
      case PrinterState.unsupported:
      case PrinterState.permissionDenied:
      case PrinterState.bluetoothOff:
      case PrinterState.noPrinterPaired:
        return false;
      case PrinterState.notConnected:
      case PrinterState.connecting:
      case PrinterState.connected:
      case PrinterState.failed:
        return true;
    }
  }

  /// Fully ready — the card shows the green state and the test slip is one tap away.
  static bool isReady(PrinterState state) => state == PrinterState.connected;

  /// Needs the shop to do something before printing can work at all.
  static bool needsSetup(PrinterState state) => !canAttemptPrint(state);

  /// Which action button the card should lead with.
  static String primaryActionKey(PrinterState state) {
    switch (state) {
      case PrinterState.noPrinterPaired:
        return 'printerFindPrinters';
      case PrinterState.connected:
        return 'printerDisconnect';
      default:
        return 'printerConnect';
    }
  }
}
