// test/printer_status_test.dart
// "Is the printer connected?" — the question the receipt screen now answers in
// words, before a receipt is at stake.
//
// The old screen could only say "print failed", and only afterwards. These are the
// states it shows instead, and the label rules that make a nameless thermal printer
// identifiable in the picker.
import 'package:flutter_test/flutter_test.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'package:drinks_calculator_fixed/utils/printer_status_helper.dart';

BluetoothInfo device(String name, String mac) =>
    BluetoothInfo(name: name, macAdress: mac);

void main() {
  group('derive', () {
    test('the facts become one state, most blocking first', () {
      expect(
        PrinterStatusHelper.derive(
            isWeb: true, bluetoothEnabled: true, pairedCount: 3),
        PrinterState.unsupported,
      );
      expect(
        PrinterStatusHelper.derive(
            bluetoothEnabled: false, pairedCount: 3),
        PrinterState.bluetoothOff,
      );
      expect(
        PrinterStatusHelper.derive(
            bluetoothEnabled: true, permissionGranted: false, pairedCount: 3),
        PrinterState.permissionDenied,
      );
      expect(
        PrinterStatusHelper.derive(bluetoothEnabled: true, pairedCount: 0),
        PrinterState.noPrinterPaired,
      );
      expect(
        PrinterStatusHelper.derive(bluetoothEnabled: true, pairedCount: 2),
        PrinterState.notConnected,
      );
      expect(
        PrinterStatusHelper.derive(
            bluetoothEnabled: true, pairedCount: 2, connected: true),
        PrinterState.connected,
      );
    });

    test('Bluetooth off outranks a refused permission', () {
      // Android reports the permission as missing while Bluetooth is off too, and
      // "switch Bluetooth on" is the only thing the shop can act on then.
      expect(
        PrinterStatusHelper.derive(
            bluetoothEnabled: false, permissionGranted: false, pairedCount: 1),
        PrinterState.bluetoothOff,
      );
    });
  });

  group('what the shop can do', () {
    test('a print is worth attempting unless setup is unfinished', () {
      expect(PrinterStatusHelper.canAttemptPrint(PrinterState.connected), isTrue);
      expect(PrinterStatusHelper.canAttemptPrint(PrinterState.notConnected), isTrue);
      expect(PrinterStatusHelper.canAttemptPrint(PrinterState.failed), isTrue);

      expect(PrinterStatusHelper.canAttemptPrint(PrinterState.bluetoothOff), isFalse);
      expect(
          PrinterStatusHelper.canAttemptPrint(PrinterState.permissionDenied), isFalse);
      expect(
          PrinterStatusHelper.canAttemptPrint(PrinterState.noPrinterPaired), isFalse);
      expect(PrinterStatusHelper.canAttemptPrint(PrinterState.unsupported), isFalse);
    });

    test('ready is connected, and needsSetup is its opposite side', () {
      expect(PrinterStatusHelper.isReady(PrinterState.connected), isTrue);
      expect(PrinterStatusHelper.isReady(PrinterState.notConnected), isFalse);
      expect(PrinterStatusHelper.needsSetup(PrinterState.bluetoothOff), isTrue);
      expect(PrinterStatusHelper.needsSetup(PrinterState.connected), isFalse);
    });

    test('the lead action matches the state', () {
      expect(PrinterStatusHelper.primaryActionKey(PrinterState.noPrinterPaired),
          'printerFindPrinters');
      expect(PrinterStatusHelper.primaryActionKey(PrinterState.connected),
          'printerDisconnect');
      expect(PrinterStatusHelper.primaryActionKey(PrinterState.bluetoothOff),
          'printerConnect');
    });
  });

  group('every state has something to say', () {
    test('a title and a different hint, so the hint can say what to DO', () {
      for (final state in PrinterState.values) {
        final title = PrinterStatusHelper.titleKey(state);
        final hint = PrinterStatusHelper.hintKey(state);
        expect(title, startsWith('printer'), reason: '$state needs a title');
        expect(hint, startsWith('printer'), reason: '$state needs a hint');
        expect(hint, isNot(title),
            reason: '$state: a hint that repeats the title helps nobody');
      }
    });
  });

  group('deviceLabel', () {
    test('a nameless printer is identified by its address', () {
      expect(PrinterStatusHelper.deviceLabel(device('', '11:22:33:44:55:66')),
          '11:22:33:44:55:66');
      expect(PrinterStatusHelper.deviceLabel(device('?', 'AA:BB:CC:DD:EE:FF')),
          'AA:BB:CC:DD:EE:FF');
      expect(PrinterStatusHelper.deviceLabel(device('null', 'AA:BB')), 'AA:BB');
    });

    test('a real name is used as it is', () {
      expect(PrinterStatusHelper.deviceLabel(device('Xprinter XP-58', 'AA:BB')),
          'Xprinter XP-58');
    });
  });

  group('findRemembered', () {
    final paired = [
      device('Printer A', '11:11:11:11:11:11'),
      device('Printer B', 'AA:BB:CC:DD:EE:FF'),
    ];

    test('matches the saved printer however it is cased or padded', () {
      expect(
        PrinterStatusHelper.findRemembered(paired, 'aa:bb:cc:dd:ee:ff')?.name,
        'Printer B',
      );
      expect(
        PrinterStatusHelper.findRemembered(paired, ' 11:11:11:11:11:11 ')?.name,
        'Printer A',
      );
    });

    test('a printer that is no longer paired is null, never a guess', () {
      expect(PrinterStatusHelper.findRemembered(paired, '99:99:99:99:99:99'),
          isNull);
      expect(PrinterStatusHelper.findRemembered(paired, ''), isNull);
      expect(PrinterStatusHelper.findRemembered(paired, null), isNull);
      expect(PrinterStatusHelper.findRemembered(const [], 'AA:BB'), isNull);
    });
  });
}
