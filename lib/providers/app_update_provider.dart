// providers/app_update_provider.dart
import 'package:flutter/foundation.dart';

import '../services/supabase_service.dart';
import '../utils/app_update_helper.dart';

/// Whether this build is out of date, and what a shop can do about it.
///
/// This app is distributed as an APK download, so nothing tells a phone that a newer
/// build exists. This provider asks the backend once per launch — and again whenever the
/// app comes back to the foreground, because a till is left open all day — then keeps the
/// answer for the banner to show.
///
/// It never guesses: no answer, an unreachable backend or an unreadable version all mean
/// there is nothing to show (utils/app_update_helper.dart).
class AppUpdateProvider extends ChangeNotifier {
  AppRelease? _release;
  bool _checking = false;
  bool _dismissed = false;

  AppRelease? get release => _release;
  bool get checking => _checking;

  /// A build this app has not got.
  bool get hasUpdate =>
      _release != null && AppUpdateHelper.isUpdateAvailable(_release!);

  /// A mandatory release cannot be put away for the session. Selling is never blocked
  /// by it: a shop must be able to keep trading on an old build.
  bool get dismissible => !(_release?.mandatory ?? false);

  /// What the banner should show: an update, unless it was put away by someone allowed
  /// to put it away.
  bool get visible => hasUpdate && (!_dismissed || !dismissible);

  /// Puts the notice away for this session. A mandatory one stays.
  void dismiss() {
    if (!dismissible) return;
    _dismissed = true;
    notifyListeners();
  }

  /// Asks the backend what the latest build is. Safe to call repeatedly.
  Future<void> check() async {
    if (_checking) return;
    _checking = true;
    notifyListeners();
    try {
      final release = await SupabaseService.getAppRelease();
      // A failed check must not erase what this session already knows.
      if (release != null) _release = release;
    } finally {
      _checking = false;
      notifyListeners();
    }
  }

  /// Seeds a release without a server round-trip, so a test can lay the notice out.
  @visibleForTesting
  void seedRelease(AppRelease? release) {
    _release = release;
    _dismissed = false;
    notifyListeners();
  }
}
