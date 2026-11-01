// test/customer_ledger_test.dart
// The shop's rule: STAFF enrol a customer, the MANAGER decides who is approved.
// Only an approved account may hold credit. No widgets are pumped here.
import 'package:flutter_test/flutter_test.dart';
import 'package:drinks_calculator_fixed/models/customer_model.dart';
import 'package:drinks_calculator_fixed/utils/customer_ledger_helper.dart';

Customer customer({
  int id = 1,
  String number = 'C-0001',
  String status = 'approved',
  double limit = 0,
  String name = 'Awa',
  String phone = '',
  String address = '',
}) =>
    Customer(
      id: id,
      customerNumber: number,
      name: name,
      status: status,
      creditLimit: limit,
      phone: phone,
      address: address,
    );

CustomerLedgerEntry entry({
  int id = 1,
  int customerId = 1,
  String kind = 'charge',
  double amount = 1000,
}) =>
    CustomerLedgerEntry(
      id: id,
      customerId: customerId,
      kind: kind,
      amount: amount,
    );

void main() {
  group('who may do what', () {
    test('staff may enrol but may not decide', () {
      expect(CustomerLedgerHelper.canEnroll('Staff'), isTrue);
      expect(CustomerLedgerHelper.canDecide('Staff'), isFalse);
    });

    test('a manager holds the final say', () {
      expect(CustomerLedgerHelper.canDecide('Manager'), isTrue);
      expect(CustomerLedgerHelper.canDecide('Administrator'), isTrue);
      expect(CustomerLedgerHelper.canDecide('Admin'), isTrue);
    });

    test('a customer account may not enrol anyone', () {
      expect(CustomerLedgerHelper.canEnroll('Customer'), isFalse);
      expect(CustomerLedgerHelper.canEnroll(null), isFalse);
    });

    test('a staff enrolment starts pending, a manager enrolment is approved', () {
      expect(CustomerLedgerHelper.initialStatusForRole('Staff'), 'pending');
      expect(CustomerLedgerHelper.initialStatusForRole('Manager'), 'approved');
    });
  });

  group('credit is only for an approved account', () {
    test('approved accounts can hold credit', () {
      expect(CustomerLedgerHelper.canHoldCredit(customer()), isTrue);
    });

    test('pending, rejected and blocked accounts cannot', () {
      for (final status in ['pending', 'rejected', 'blocked']) {
        expect(
          CustomerLedgerHelper.canHoldCredit(customer(status: status)),
          isFalse,
          reason: '$status must not hold credit',
        );
      }
      expect(CustomerLedgerHelper.canHoldCredit(null), isFalse);
    });
  });

  group('ledger totals', () {
    test('balance is charged minus paid', () {
      final totals = CustomerLedgerHelper.totalsFor([
        entry(id: 1, kind: 'charge', amount: 5000),
        entry(id: 2, kind: 'payment', amount: 2000),
        entry(id: 3, kind: 'charge', amount: 1000),
      ]);
      expect(totals.charged, 6000);
      expect(totals.paid, 2000);
      expect(totals.balance, 4000);
      expect(totals.owes, isTrue);
      expect(totals.inCredit, isFalse);
    });

    test('an overpaid account is in credit, not in debt', () {
      final totals = CustomerLedgerHelper.totalsFor([
        entry(id: 1, kind: 'charge', amount: 1000),
        entry(id: 2, kind: 'payment', amount: 1500),
      ]);
      expect(totals.balance, -500);
      expect(totals.owes, isFalse);
      expect(totals.inCredit, isTrue);
    });

    test('an empty ledger owes nothing', () {
      expect(CustomerLedgerHelper.totalsFor([]).balance, 0);
    });

    test('totals are per customer', () {
      final entries = [
        entry(id: 1, customerId: 7, kind: 'charge', amount: 3000),
        entry(id: 2, customerId: 8, kind: 'charge', amount: 900),
        entry(id: 3, customerId: 7, kind: 'payment', amount: 1000),
      ];
      expect(CustomerLedgerHelper.totalsForCustomer(7, entries).balance, 2000);
      expect(CustomerLedgerHelper.totalsForCustomer(8, entries).balance, 900);
    });
  });

  group('credit limit', () {
    test('no limit set means no warning', () {
      expect(
        CustomerLedgerHelper.exceedsLimit(
          balance: 99999,
          amount: 1,
          creditLimit: 0,
        ),
        isFalse,
      );
    });

    test('warns only when the new balance passes the limit', () {
      expect(
        CustomerLedgerHelper.exceedsLimit(
          balance: 900,
          amount: 200,
          creditLimit: 1000,
        ),
        isTrue,
      );
      expect(
        CustomerLedgerHelper.exceedsLimit(
          balance: 900,
          amount: 100,
          creditLimit: 1000,
        ),
        isFalse,
      );
    });
  });

  group('lists', () {
    test('the ledger is shown newest first', () {
      final entries = [
        entry(id: 1, amount: 100),
        entry(id: 2, amount: 200),
        entry(id: 3, amount: 300),
      ];
      expect(
        CustomerLedgerHelper.newestFirst(entries).map((e) => e.id).toList(),
        [3, 2, 1],
      );
    });

    test('who owes what is sorted by debt', () {
      final customers = [
        customer(id: 1, number: 'C-0001'),
        customer(id: 2, number: 'C-0002'),
        customer(id: 3, number: 'C-0003'),
      ];
      final entries = [
        entry(id: 1, customerId: 1, kind: 'charge', amount: 1000),
        entry(id: 2, customerId: 2, kind: 'charge', amount: 9000),
        entry(id: 3, customerId: 2, kind: 'payment', amount: 500),
        entry(id: 4, customerId: 3, kind: 'charge', amount: 4000),
      ];
      final ordered = CustomerLedgerHelper.orderedByDebt(customers, entries);
      expect(
        ordered.map((c) => c.customerNumber).toList(),
        ['C-0002', 'C-0003', 'C-0001'],
      );
    });

    test('pending accounts are counted for the manager', () {
      final customers = [
        customer(id: 1, status: 'pending'),
        customer(id: 2, status: 'approved'),
        customer(id: 3, status: 'pending'),
      ];
      expect(CustomerLedgerHelper.pendingCount(customers), 2);
    });
  });

  group('formatting', () {
    test('each status has its own label key', () {
      expect(CustomerLedgerHelper.statusKey('approved'), 'custStatusApproved');
      expect(CustomerLedgerHelper.statusKey('rejected'), 'custStatusRejected');
      expect(CustomerLedgerHelper.statusKey('blocked'), 'custStatusBlocked');
      expect(CustomerLedgerHelper.statusKey('pending'), 'custStatusPending');
      expect(CustomerLedgerHelper.statusKey(null), 'custStatusPending');
    });

    test('the same phone matches however it was typed', () {
      expect(CustomerLedgerHelper.normalizePhone('6 77 12 34 56'), '677123456');
      expect(
        CustomerLedgerHelper.normalizePhone('+237 677-123-456'),
        '237677123456',
      );
      expect(CustomerLedgerHelper.normalizePhone(null), '');
    });
  });

  group('parsing server rows', () {
    test('a NUMERIC string from Postgres is still a number', () {
      final parsed = Customer.fromJson(const {
        'id': 3,
        'customer_number': 'C-0003',
        'name': 'Awa',
        'status': 'approved',
        'credit_limit': '5000.00',
      });
      expect(parsed.id, 3);
      expect(parsed.creditLimit, 5000);
      expect(parsed.customerNumber, 'C-0003');
    });

    test('a ledger entry reads its amount as a string too', () {
      final parsed = CustomerLedgerEntry.fromJson(const {
        'id': 9,
        'customer_id': 3,
        'kind': 'charge',
        'amount': '1500.00',
      });
      expect(parsed.amount, 1500);
      expect(parsed.isPayment, isFalse);
    });
  });

  group('finding a customer at the counter', () {
    final emile = customer(
      id: 7,
      number: 'C-0007',
      name: 'Émile Nkolo',
      phone: '+237 677 12 34 56',
      address: 'Marché Mokolo',
    );
    final awa = customer(id: 1, number: 'C-0001', name: 'Awa', phone: '699887766');
    final all = [emile, awa];

    test('an empty search keeps everyone', () {
      expect(CustomerLedgerHelper.search(all, ''), all);
      expect(CustomerLedgerHelper.search(all, '   '), all);
    });

    test('finds by name, with or without the accent and in any case', () {
      expect(CustomerLedgerHelper.search(all, 'emile'), [emile]);
      expect(CustomerLedgerHelper.search(all, 'ÉMILE'), [emile]);
      expect(CustomerLedgerHelper.search(all, 'nkolo'), [emile]);
      expect(CustomerLedgerHelper.search(all, 'awa'), [awa]);
    });

    test('finds by the customer number, which is the account identity', () {
      expect(CustomerLedgerHelper.search(all, 'C-0007'), [emile]);
      expect(CustomerLedgerHelper.search(all, '0007'), [emile]);
      // A partial number is a legitimate way to search a long list.
      expect(CustomerLedgerHelper.search(all, 'c-000'), all);
    });

    test('finds by phone however it is typed', () {
      // Digits only, so a space every three digits still finds the stored number.
      expect(CustomerLedgerHelper.search(all, '677 12 34 56'), [emile]);
      expect(CustomerLedgerHelper.search(all, '677123456'), [emile]);
      expect(CustomerLedgerHelper.search(all, '+237677'), [emile]);
    });

    test('finds by address, and answers nothing when nothing matches', () {
      expect(CustomerLedgerHelper.search(all, 'mokolo'), [emile]);
      expect(CustomerLedgerHelper.search(all, 'zzz'), isEmpty);
    });

    test('one customer is never confused with another', () {
      expect(CustomerLedgerHelper.matches(awa, 'C-0007'), isFalse);
      expect(CustomerLedgerHelper.matches(emile, 'C-0007'), isTrue);
      // A single digit must not drag in everyone whose number starts with it.
      expect(CustomerLedgerHelper.matches(awa, '699887766'), isTrue);
    });
  });
}
