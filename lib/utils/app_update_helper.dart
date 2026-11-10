// utils/app_update_helper.dart
// "Is there a newer build of this app?" — the one thing a direct APK download cannot
// tell a shop by itself.
//
// WHY THIS EXISTS. This app is handed out as an APK file, not through a store. A store
// tells every phone that a new version is out; a download link does not, so a shop
// silently stays on an old build for ever. The backend publishes what the latest build
// is (GET /api/app/release) and these rules decide whether that is news.
//
// NOTHING IS GUESSED, in both directions:
//   * the backend announces nothing when it is not configured, and
//   * [AppUpdateHelper.isUpdateAvailable] answers false whenever either side cannot be
//     read — a phone must never be told to update because of a string it did not
//     understand. A wrong "update available" is worse than staying quiet.
//
// Pure, so the rule is testable without a widget (test/app_update_test.dart). The version
// this build IS comes from `AppConstants.appVersion` — the app's single declared source of
// truth, pinned to pubspec.yaml by test/app_info_test.dart — never a second copy of it.
import 'constants.dart';

/// What the backend says the latest published build is.
class AppRelease {
  const AppRelease({
    this.latestVersion,
    this.latestBuild,
    this.downloadUrl,
    this.notes,
    this.mandatory = false,
  });

  final String? latestVersion;
  final int? latestBuild;

  /// Where to get it. Null when none was published: the notice then tells the shop to
  /// ask whoever supplied the app instead of offering a button that goes nowhere.
  final String? downloadUrl;
  final String? notes;

  /// True when the notice cannot be dismissed for the session. Selling is never blocked
  /// by it — a shop must be able to keep trading on an old build.
  final bool mandatory;

  /// The backend had nothing configured, so there is nothing to say.
  bool get known => latestVersion != null;

  factory AppRelease.fromJson(Map<String, dynamic> json) => AppRelease(
        latestVersion:
            _asString(json['latestVersion'] ?? json['latest_version']),
        latestBuild: _asInt(json['latestBuild'] ?? json['latest_build']),
        downloadUrl: _asString(json['downloadUrl'] ?? json['download_url']),
        notes: _asString(json['notes']),
        mandatory: json['mandatory'] == true,
      );
}

class AppUpdateHelper {
  AppUpdateHelper._();

  /// -1, 0 or 1 — or null when either side is not a dotted numeric version.
  ///
  /// Compared part by part on purpose: **1.10.0 IS newer than 1.9.0**, and a plain
  /// string compare would say the opposite and hide the update.
  static int? compareVersions(String? a, String? b) {
    final left = _parts(a);
    final right = _parts(b);
    if (left == null || right == null) return null;
    final length = left.length > right.length ? left.length : right.length;
    for (var i = 0; i < length; i++) {
      final mine = i < left.length ? left[i] : 0;
      final theirs = i < right.length ? right[i] : 0;
      if (mine != theirs) return mine < theirs ? -1 : 1;
    }
    return 0;
  }

  /// True when [release] is a build this app has not got.
  ///
  /// The version decides; the build number only breaks a tie (same version, rebuilt).
  static bool isUpdateAvailable(
    AppRelease release, {
    String installedVersion = AppConstants.appVersion,
    int installedBuild = AppConstants.appBuild,
  }) {
    if (!release.known) return false;
    final compared = compareVersions(release.latestVersion, installedVersion);
    if (compared == null) return false;
    if (compared > 0) return true;
    if (compared < 0) return false;
    final build = release.latestBuild;
    if (build == null) return false;
    return build > installedBuild;
  }

  /// "1.1.0" → [1, 1, 0]; anything else → null.
  static List<int>? _parts(String? value) {
    if (value == null) return null;
    final text = value.trim().replaceFirst(RegExp(r'^[vV]'), '');
    if (!RegExp(r'^\d+(\.\d+){0,3}$').hasMatch(text)) return null;
    return text.split('.').map(int.parse).toList();
  }
}

String? _asString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? _asInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString().trim());
}
