// test/app_update_test.dart
// "Is there a newer build?" — the rule, and the notice a shop sees.
//
// This app is handed out as an APK download, so nothing tells a phone that a new version
// exists; the backend publishes it and these rules decide whether that is news. The tests
// pin the two ways it must stay quiet: an unreadable version, and a backend that knows
// nothing. A wrong "update available" is worse than silence.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:drinks_calculator_fixed/providers/app_update_provider.dart';
import 'package:drinks_calculator_fixed/utils/app_update_helper.dart';
import 'package:drinks_calculator_fixed/utils/constants.dart';
import 'package:drinks_calculator_fixed/utils/i18n.dart';
import 'package:drinks_calculator_fixed/widgets/update_notice_host.dart';

void main() {
  group('comparing versions', () {
    test('part by part, so 1.10.0 is newer than 1.9.0', () {
      expect(AppUpdateHelper.compareVersions('1.10.0', '1.9.0'), 1);
      expect(AppUpdateHelper.compareVersions('2.0', '1.99.99'), 1);
      expect(AppUpdateHelper.compareVersions('1.2.0', '1.2.0'), 0);
      expect(AppUpdateHelper.compareVersions('1.2.0', '1.2.1'), -1);
    });

    test('a missing part counts as zero', () {
      expect(AppUpdateHelper.compareVersions('1.2', '1.2.0'), 0);
      expect(AppUpdateHelper.compareVersions('1.2.0.1', '1.2'), 1);
    });

    test('an unreadable version is refused, never guessed', () {
      expect(AppUpdateHelper.compareVersions(null, '1.0.0'), isNull);
      expect(AppUpdateHelper.compareVersions('1.0.0', null), isNull);
      expect(AppUpdateHelper.compareVersions('latest', '1.0.0'), isNull);
      expect(AppUpdateHelper.compareVersions('1.2.0-beta', '1.0.0'), isNull);
    });
  });

  group('deciding whether an update is news', () {
    test('a newer version is an update', () {
      expect(
        AppUpdateHelper.isUpdateAvailable(
            const AppRelease(latestVersion: '1.2.0')),
        isTrue,
      );
    });

    test('the same version is not, unless it was rebuilt', () {
      expect(
        AppUpdateHelper.isUpdateAvailable(
            const AppRelease(latestVersion: '1.1.0')),
        isFalse,
      );
      expect(
        AppUpdateHelper.isUpdateAvailable(
            const AppRelease(latestVersion: '1.1.0', latestBuild: 1)),
        isFalse,
      );
      expect(
        AppUpdateHelper.isUpdateAvailable(
            const AppRelease(latestVersion: '1.1.0', latestBuild: 2)),
        isTrue,
      );
    });

    test('an older build is not an update', () {
      expect(
        AppUpdateHelper.isUpdateAvailable(
            const AppRelease(latestVersion: '1.0.9')),
        isFalse,
      );
    });

    test('a backend that knows nothing says nothing', () {
      expect(const AppRelease().known, isFalse);
      expect(AppUpdateHelper.isUpdateAvailable(const AppRelease()), isFalse);
    });

    test('an unreadable published version is not an update', () {
      expect(
        AppUpdateHelper.isUpdateAvailable(
            const AppRelease(latestVersion: 'latest')),
        isFalse,
      );
    });
  });

  group('reading what the backend sent', () {
    test('the payload it actually sends', () {
      final release = AppRelease.fromJson({
        'latestVersion': '1.2.0',
        'latestBuild': 3,
        'downloadUrl': 'https://example.com/app.apk',
        'notes': 'Fixed the till total',
        'mandatory': true,
      });
      expect(release.known, isTrue);
      expect(release.latestBuild, 3);
      expect(release.downloadUrl, 'https://example.com/app.apk');
      expect(release.notes, 'Fixed the till total');
      expect(release.mandatory, isTrue);
    });

    test('an empty payload means "we do not know", not version zero', () {
      final release = AppRelease.fromJson(const {});
      expect(release.known, isFalse);
      expect(release.latestBuild, isNull);
      expect(release.mandatory, isFalse);
    });

    test('numbers arriving as strings still work', () {
      final release =
          AppRelease.fromJson(const {'latestVersion': '2.0', 'latestBuild': '7'});
      expect(release.latestBuild, 7);
    });

    test('mandatory is only true when it is a real true', () {
      expect(AppRelease.fromJson(const {'mandatory': 'true'}).mandatory, isFalse);
      expect(AppRelease.fromJson(const {'mandatory': true}).mandatory, isTrue);
    });
  });

  group('the version this build reports', () {
    test('is the app version, not a second copy of it', () {
      // AppConstants.appVersion is the app's one declared source of truth, pinned to
      // pubspec.yaml by test/app_info_test.dart. The default here must be it — a separate
      // version literal is exactly what that guard exists to prevent.
      expect(
        AppUpdateHelper.isUpdateAvailable(
            AppRelease(latestVersion: AppConstants.appVersion)),
        isFalse,
        reason: 'the installed version must compare equal to itself',
      );
      // A rebuild of the SAME version is still news once the build number moves.
      expect(
        AppUpdateHelper.isUpdateAvailable(AppRelease(
          latestVersion: AppConstants.appVersion,
          latestBuild: AppConstants.appBuild + 1,
        )),
        isTrue,
      );
    });
  });

  group('the notice a shop sees', () {
    testWidgets('a newer build is announced, and Later keeps the shop selling',
        (tester) async {
      final updates = AppUpdateProvider();
      addTearDown(updates.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppUpdateProvider>.value(
          value: updates,
          child: const MaterialApp(
            home: UpdateNoticeHost(
              // No pending timer at the end of the test.
              startupDelay: Duration.zero,
              child: Scaffold(body: Text('till')),
            ),
          ),
        ),
      );
      await tester.pump();

      updates.seedRelease(const AppRelease(
        latestVersion: '1.2.0',
        downloadUrl: 'https://example.com/app-release.apk',
      ));
      await tester.pumpAndSettle();

      expect(find.text(t('updateAvailableTitle')), findsOneWidget);
      expect(find.text(t('updateDownload')), findsOneWidget);

      await tester.tap(find.text(t('updateLater')));
      await tester.pumpAndSettle();

      expect(find.text(t('updateAvailableTitle')), findsNothing);
      // The till is still there: a notice never blocks a sale.
      expect(find.text('till'), findsOneWidget);
    });

    testWidgets('nothing is shown when this build is current', (tester) async {
      final updates = AppUpdateProvider()
        ..seedRelease(const AppRelease(latestVersion: '1.1.0'));
      addTearDown(updates.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppUpdateProvider>.value(
          value: updates,
          child: const MaterialApp(
            home: UpdateNoticeHost(
              startupDelay: Duration.zero,
              child: Scaffold(body: Text('till')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(t('updateAvailableTitle')), findsNothing);
    });

    test('a mandatory notice cannot be put away', () {
      final mandatory = AppUpdateProvider()
        ..seedRelease(const AppRelease(latestVersion: '1.2.0', mandatory: true));
      addTearDown(mandatory.dispose);
      expect(mandatory.visible, isTrue);
      mandatory.dismiss();
      expect(mandatory.visible, isTrue,
          reason: 'the shop can keep selling, but it is reminded again');

      final optional = AppUpdateProvider()
        ..seedRelease(const AppRelease(latestVersion: '1.2.0'));
      addTearDown(optional.dispose);
      expect(optional.visible, isTrue);
      optional.dismiss();
      expect(optional.visible, isFalse);
    });
  });
}
