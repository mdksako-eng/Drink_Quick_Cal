// test/plan_provider_session_test.dart
// A PLAN BELONGS TO A SESSION, NOT TO A DEVICE.
//
// The bug this pins: on a shared till a Starter shop signed out and a Pro shop signed in.
// The provider still held the Starter plan and still answered `hasLoaded: true`, so the gate
// judged the new user on the old answer and sent a paying shop to the plans screen — it got
// in only once a fetch happened to replace the stale plan.
//
// Nothing here touches the network: `setSession` is deliberately pure state, which is what
// makes it testable.
import 'package:flutter_test/flutter_test.dart';

import 'package:drinks_calculator_fixed/models/subscription_model.dart';
import 'package:drinks_calculator_fixed/providers/plan_provider.dart';

void main() {
  test('a different session drops the plan the previous one left behind', () {
    final provider = PlanProvider()
      ..seedPlan(const SubscriptionInfo(plan: 'starter', status: 'active'));
    expect(provider.hasLoaded, isTrue);
    expect(provider.isActive, isTrue);
    expect(provider.plan, 'starter');

    // The next shop signs in on the same device.
    provider.setSession('companyB:user2');

    // Not "loaded", not active, not the old plan: the gate now waits for a real answer
    // instead of judging the new user on the previous one's subscription.
    expect(provider.hasLoaded, isFalse,
        reason: 'the previous session\'s plan must not count as loaded for this one');
    expect(provider.isActive, isFalse);
    expect(provider.plan, 'free');
  });

  test('admin rights do not survive a session change either', () {
    final provider = PlanProvider()..setIsAdmin(true);
    expect(provider.isAdmin, isTrue);

    provider.setSession('companyB:user2');

    expect(provider.isAdmin, isFalse,
        reason: 'the next user must not inherit a bypass they were never granted');
  });

  test('the same session is left alone', () {
    final provider = PlanProvider()..seedPlan(const SubscriptionInfo(plan: 'pro'));
    const key = 'companyA:user1';

    provider.setSession(key);
    expect(provider.hasLoaded, isFalse, reason: 'the first call records the session');

    provider.seedPlan(const SubscriptionInfo(plan: 'pro', status: 'active'));
    provider.setSession(key); // the same shop, back on the same device
    expect(provider.hasLoaded, isTrue,
        reason: 're-entering the same session must not throw the answer away');
    expect(provider.isActive, isTrue);
  });

  test('signing out leaves no plan on the device', () {
    final provider = PlanProvider()
      ..seedPlan(const SubscriptionInfo(plan: 'pro', status: 'active'));

    provider.setSession(null); // logged out

    expect(provider.hasLoaded, isFalse);
    expect(provider.isActive, isFalse);
    expect(provider.plan, 'free');
  });

  test('an active plan needs its status, so the fixture is not a lie', () {
    // Guards the test itself: if SubscriptionInfo.isActive ever stops depending on
    // `status`, the assertions above would pass without proving anything.
    expect(const SubscriptionInfo(plan: 'pro').isActive, isFalse);
    expect(const SubscriptionInfo(plan: 'pro', status: 'active').isActive, isTrue);
  });
}
