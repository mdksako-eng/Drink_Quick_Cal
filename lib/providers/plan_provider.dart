// providers/plan_provider.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/subscription_model.dart';
import '../services/subscription_service.dart';
import '../services/voice_service.dart';
import '../utils/plan_gate_logic.dart';
import '../utils/voice_access.dart';

class PlanProvider extends ChangeNotifier {
  SubscriptionInfo _info = const SubscriptionInfo();
  bool _loading = false;

  /// True once a plan fetch has completed (successfully or not). The
  /// subscription gate uses this to know it is safe to decide whether to show
  /// the plans, instead of judging on the default ('free') placeholder.
  bool _hasLoaded = false;

  /// True once the SERVER has answered for THIS session.
  ///
  /// Deliberately separate from [hasLoaded]: "we are done asking" and "we know the
  /// answer" are not the same thing, and treating a failed ask as an answer is how a
  /// paying company gets told it is on Free.
  bool _resolved = false;

  /// One GET at a time — the login handler and the plan gate ask at the same moment.
  Future<void>? _inFlight;

  SubscriptionInfo get info => _info;
  bool get loading => _loading;
  bool get hasLoaded => _hasLoaded;
  String get plan => _info.plan;
  bool get isActive => _info.isActive;

  /// The server answered for this session.
  bool get resolved => _resolved;

  /// We asked and did not get through — NOT the same as "the plan is free".
  bool get fetchFailed => _hasLoaded && !_resolved;

  static const Map<String, String> _featurePlans = {
    'staff': 'starter',
    'reports': 'starter',
    'analytics': 'pro',
    'forecast': 'pro',
    'scanner': 'pro',
    'printing': 'pro',
    'ai': 'pro',
    'inbox': 'pro',
    // 🍸 Recipe / pour cost: the backend gates every /recipes route with
    // requirePlan(['pro']), so the app must not offer the entry on a lower plan —
    // otherwise a manager taps it and hits a wall the server built.
    'recipes': 'pro',
  };

  int _rank(String plan) {
    switch (plan.toLowerCase()) {
      case 'pro':
        return 2;
      case 'starter':
        return 1;
      default:
        return 0;
    }
  }

  /// Whether the current plan grants access to [feature].
  ///
  /// A platform administrator is let through regardless of the plan — the backend
  /// already does exactly that in `requirePlan`, so the app must not be stricter
  /// than the server it is talking to.
  bool canAccess(String feature) {
    final required = _featurePlans[feature] ?? 'pro';
    return featureAccessAllowed(
      isAdmin: _isAdmin,
      planGrants: _rank(_info.plan) >= _rank(required),
    );
  }

  /// 🔐 True when the signed-in user is a platform administrator.
  ///
  /// Pushed in after login (see `main.dart`) because this provider resolves the
  /// plan only and never reads the auth state itself.
  bool _isAdmin = false;
  bool get isAdmin => _isAdmin;

  /// Called right after login / session restore, before the plan is fetched.
  void setIsAdmin(bool isAdmin) {
    if (_isAdmin == isAdmin) return;
    _isAdmin = isAdmin;
    notifyListeners();
  }

  /// The session whose plan this is (user + company). A plan belongs to a SIGNED-IN SESSION,
  /// not to the device.
  ///
  /// THE BUG THIS EXISTS FOR: on a shared till one shop signs out and another signs in. The
  /// provider still held the previous shop's plan and still reported `hasLoaded: true`, so
  /// the gate judged the new user on the old answer — a Pro shop was sent to the plans
  /// screen and only got in once a fetch happened to replace it. Nothing about a plan
  /// survives a session change now, not even "we already asked".
  String? _sessionKey;

  /// Called whenever the signed-in session changes — login, logout, a different user —
  /// BEFORE the plan is fetched. Any plan already held belongs to the previous session.
  ///
  /// 🔒 This is the security half of the shared-till bug: a plan (and the administrator
  /// bypass) is a property of a SESSION, so signing out must DROP it, not hide it. The
  /// early return used to fire for `null -> null` too, so a provider that had been
  /// seeded — or whose session was never recorded — kept one shop's plan through another
  /// shop's logout.
  void setSession(String? sessionKey) {
    // The same signed-in user: nothing changed, and clearing here would throw away the
    // plan that has just been fetched for them.
    if (sessionKey != null && _sessionKey == sessionKey) return;
    // Signing out with nothing held is a no-op; signing out while holding an answer
    // must clear it.
    if (sessionKey == null && !_holdsAPlan) return;

    _sessionKey = sessionKey;
    _info = const SubscriptionInfo();
    _hasLoaded = false;
    _resolved = false;
    _isAdmin = false;
    // Voice is a paid capability that ships off: an unresolved plan is a "no" until THIS
    // session's plan arrives.
    _syncVoiceEntitlement();
    notifyListeners();
  }

  /// Is anything held that belongs to a session — a fetched answer, an admin bypass, or
  /// a plan that is not the default?
  bool get _holdsAPlan => _hasLoaded || _isAdmin || _info.plan != 'free';

  /// Seeds a plan without a server round-trip, so a test can prove what a session change
  /// does to it. Same idea as `RecipeProvider.seedReport` / `AppUpdateProvider.seedRelease`.
  @visibleForTesting
  void seedPlan(SubscriptionInfo info) {
    _info = info;
    _hasLoaded = true;
    _syncVoiceEntitlement();
    notifyListeners();
  }

  /// Returns a human price for a plan (e.g. "5,000 XAF") or ''.
  String priceLabel(String plan) {
    final p = _info.prices[plan];
    if (p is! Map) return '';
    final amount = num.tryParse('${p['amount']}') ?? 0;
    if (amount == 0) return '';
    final formatted = amount.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '$formatted ${p['currency'] ?? 'XAF'}';
  }

  /// Ask the server for this session's plan.
  ///
  /// One GET at a time (the login handler and the plan gate ask at the same moment), and
  /// a FAILED ask is never recorded as an answer: `_resolved` stays false, so the gate can
  /// tell "on Free" from "we could not find out" — the difference between asking a paying
  /// shop to pay again and letting them sell.
  Future<void> refresh() async {
    final pending = _inFlight;
    if (pending != null) {
      await pending;
      return;
    }

    final future = _fetchOnce();
    _inFlight = future;
    try {
      await future;
    } finally {
      _inFlight = null;
    }

    // The first ask did not get through: keep trying quietly, so the plan arrives on its
    // own instead of the user having to open the subscription screen.
    if (!_resolved && _sessionKey != null) unawaited(_retryForThisSession());
  }

  Future<void> _fetchOnce() async {
    _loading = true;
    notifyListeners();
    try {
      final info = await SubscriptionService.getStatus();
      if (info != null) {
        _info = info;
        _resolved = true;
      }
    } finally {
      _loading = false;
      // Still "done asking" — the gate may decide now, and [fetchFailed] says which kind
      // of done this is.
      _hasLoaded = true;
      _syncVoiceEntitlement();
      notifyListeners();
    }
  }

  /// Keeps asking until THIS session's plan is known.
  ///
  /// Bounded (three tries), stops the instant the server answers or the session changes,
  /// and never runs with nobody signed in — a plan must not be fetched on behalf of a user
  /// who has gone.
  Future<void> _retryForThisSession() async {
    final session = _sessionKey;
    if (session == null) return;
    for (var attempt = 1; attempt <= 3; attempt++) {
      await Future<void>.delayed(Duration(seconds: attempt * 3));
      if (_sessionKey != session || _resolved || _loading) return;
      await _fetchOnce();
      if (_resolved) return;
    }
  }

  /// 🔒 Tells `VoiceService` whether this plan includes voice.
  ///
  /// Voice is a paid capability that ships OFF, so an unresolved plan (boot, a
  /// failed first fetch) is a "no". A later successful fetch flips it on without a
  /// restart; a downgrade flips it off immediately.
  void _syncVoiceEntitlement() {
    VoiceService.setPlanAllowsVoice(voiceAllowedForPlan(
      planResolved: _hasLoaded,
      grantsAiFeature: canAccess('ai'),
    ));
  }

  /// Begin a card payment for [plan]; returns the checkout URL (or null).
  Future<Map<String, dynamic>?> initiate(String plan) async {
    final result = await SubscriptionService.initiate(plan: plan);
    return result;
  }

  /// Begin a mobile-money (MTN/Orange) payment; returns the initiate data.
  Future<Map<String, dynamic>?> momoInitiate({
    required String plan,
    required String provider,
    required String customerPhone,
  }) {
    return SubscriptionService.momoInitiate(
      plan: plan,
      provider: provider,
      customerPhone: customerPhone,
    );
  }

  /// Poll mobile-money payment status; refreshes state when it becomes active.
  Future<Map<String, dynamic>?> momoStatus({required String reference}) async {
    final result = await SubscriptionService.momoStatus(reference: reference);
    if (result?['active'] == true) {
      await refresh();
    }
    return result;
  }

  /// Confirm a mobile-money payment and refresh local state.
  Future<bool> momoConfirm({
    required String reference,
    required String plan,
  }) async {
    final ok = await SubscriptionService.momoConfirm(
      reference: reference,
      plan: plan,
    );
    if (ok) await refresh();
    return ok;
  }

  /// Begin a CamerPay payment (unified MoMo/OM/card); returns initiate data.
  Future<Map<String, dynamic>?> campayInitiate({
    required String plan,
    String? channel,
    String? customerPhone,
  }) {
    return SubscriptionService.campayInitiate(
        plan: plan, channel: channel, customerPhone: customerPhone);
  }

  /// Poll CamerPay payment status; refreshes state when it becomes active.
  Future<Map<String, dynamic>?> campayStatus({required String reference}) async {
    final result = await SubscriptionService.campayStatus(reference: reference);
    if (result?['active'] == true) {
      await refresh();
    }
    return result;
  }

  /// Verify a payment and refresh local state.
  Future<bool> verify({required String transactionId, required String plan}) async {
    final ok = await SubscriptionService.verify(
      transactionId: transactionId,
      plan: plan,
    );
    if (ok) await refresh();
    return ok;
  }
}
