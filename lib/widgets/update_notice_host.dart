// widgets/update_notice_host.dart
// Tells a shop that a newer build of the app exists — the thing a store would normally
// do, and this app is handed out as an APK download instead.
//
// WHY A DIALOG AND NOT A BANNER. A bar pinned over the app would cover the screen's own
// AppBar (so its drawer button), and pushing the whole app down would change the layout
// of every screen on a live till. A dialog is explicit, costs one tap, and cannot break a
// layout. Selling is never blocked: "Later" is always there.
//
// It is mounted INSIDE the Navigator (main.dart wraps AuthWrapper's home widget), so it
// can reach the root navigator and the lock overlay — which covers the whole Navigator —
// still sits above it.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/app_update_provider.dart';
import '../utils/constants.dart';
import '../utils/i18n.dart';

class UpdateNoticeHost extends StatefulWidget {
  const UpdateNoticeHost({
    super.key,
    required this.child,
    this.startupDelay = const Duration(seconds: 3),
  });

  final Widget child;

  /// How long to wait after launch before asking. Long enough that the app is on screen
  /// first, so the answer never lands on the splash.
  final Duration startupDelay;

  @override
  State<UpdateNoticeHost> createState() => _UpdateNoticeHostState();
}

class _UpdateNoticeHostState extends State<UpdateNoticeHost>
    with WidgetsBindingObserver {
  AppUpdateProvider? _updates;
  Timer? _startupTimer;
  bool _shown = false;
  bool _dialogOpen = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    // A widget must not leave a timer behind: the test harness fails on a pending timer,
    // and so would the frame budget of a debug build.
    _startupTimer?.cancel();
    _updates?.removeListener(_onProviderChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A till is left open all day, so a launch-only check would miss every release.
    if (state == AppLifecycleState.resumed) _check();
  }

  void _start() {
    if (!mounted) return;
    final updates = Provider.of<AppUpdateProvider>(context, listen: false);
    _updates = updates;
    updates.addListener(_onProviderChanged);
    _startupTimer = Timer(widget.startupDelay, () {
      if (mounted) _check();
    });
  }

  Future<void> _check() async {
    final updates = _updates;
    if (updates == null || _checking) return;
    _checking = true;
    try {
      await updates.check();
    } finally {
      _checking = false;
    }
  }

  void _onProviderChanged() {
    final updates = _updates;
    if (updates == null || !updates.visible) return;
    // A mandatory notice may not be put away: it comes back after every check, while
    // "Later" still lets the shop keep selling.
    if (updates.release?.mandatory == true) _shown = false;
    if (_shown) return;
    _shown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _show(updates);
    });
  }

  Future<void> _show(AppUpdateProvider updates) async {
    final release = updates.release;
    // A mandatory notice is re-armed on every provider change (above), and a check notifies
    // TWICE — once when it starts, once when it answers. Without this guard the second
    // notification pushed a SECOND dialog on top of the one already on screen, so tapping
    // "Later" still left a dialog behind.
    if (release == null || _dialogOpen || !mounted) return;
    _dialogOpen = true;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(t('updateAvailableTitle')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('updateBody')
                  .replaceAll('@version', release.latestVersion ?? '')
                  .replaceAll('@current', AppConstants.appVersion)),
              if (release.notes != null) ...[
                const SizedBox(height: 8),
                Text(release.notes!, style: const TextStyle(fontSize: 12)),
              ],
              if (release.mandatory) ...[
                const SizedBox(height: 8),
                Text(
                  t('updateMandatory'),
                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ],
            ],
          ),
          actions: [
            if (release.downloadUrl != null)
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _open(release.downloadUrl!);
                },
                child: Text(t('updateDownload')),
              ),
            TextButton(
              onPressed: () {
                updates.dismiss();
                Navigator.pop(dialogContext);
              },
              child: Text(t('updateLater')),
            ),
          ],
        ),
      );
    } finally {
      // The dialog is gone: a later check may legitimately show it again.
      _dialogOpen = false;
    }
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
