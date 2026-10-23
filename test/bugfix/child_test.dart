import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finfamily_mobile/features/child/child_coach_screen.dart';
import 'package:finfamily_mobile/features/child/learn_screen.dart';
import 'package:finfamily_mobile/features/child/meeza_card_screen.dart';
import 'package:finfamily_mobile/features/child/missions_screen.dart';
import 'package:finfamily_mobile/features/child/wallet_screen.dart';

/// Backend timestamps are naive UTC ISO strings (no 'Z').
String naiveUtc(DateTime d) => d.toUtc().toIso8601String().replaceAll('Z', '');

void main() {
  group('AI coach history (#20, #127)', () {
    test('skips client-only bubbles and maps bot → assistant', () {
      final history = buildCoachHistory([
        {'role': 'bot', 'text': 'greeting', 'local': 'true'},
        {'role': 'user', 'text': 'إزاي أحوش لشراء عجلة؟'},
        {'role': 'bot', 'text': 'العجلة سعرها كام؟'},
        {'role': 'user', 'text': '500'},
        {'role': 'bot', 'text': 'error bubble', 'local': 'true'},
      ]);
      expect(history, [
        {'role': 'user', 'content': 'إزاي أحوش لشراء عجلة؟'},
        {'role': 'assistant', 'content': 'العجلة سعرها كام؟'},
        {'role': 'user', 'content': '500'},
      ]);
    });

    test('only the greeting gives an empty history', () {
      expect(buildCoachHistory([
        {'role': 'bot', 'text': 'greeting', 'local': 'true'},
      ]), isEmpty);
    });

    test('keeps at most the last 10 turns, oldest → newest', () {
      final msgs = [
        for (int i = 0; i < 15; i++) {'role': i.isEven ? 'user' : 'bot', 'text': 'm$i'},
      ];
      final history = buildCoachHistory(msgs);
      expect(history.length, kCoachMaxHistoryItems);
      expect(history.first['content'], 'm5');
      expect(history.last['content'], 'm14');
    });

    test('caps each item at 1000 and the total at 4000 characters', () {
      final long = 'ا' * 1500;
      final history = buildCoachHistory([
        for (int i = 0; i < 6; i++) {'role': 'user', 'text': i == 0 ? long : 'x' * 900},
      ]);
      for (final h in history) {
        expect(h['content']!.runes.length, lessThanOrEqualTo(kCoachMaxMessageChars));
        expect(h.keys.toSet(), {'role', 'content'});
      }
      final total = history.fold<int>(0, (s, h) => s + h['content']!.runes.length);
      expect(total, lessThanOrEqualTo(kCoachMaxHistoryTotalChars));
      // Oldest items are dropped first
      expect(history.last['content'], 'x' * 900);
    });
  });

  group('Coach input (#133, #134)', () {
    testWidgets('input is limited to 1000 characters', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ChildCoachScreen()));
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLength, kCoachMaxMessageChars);
    });

    testWidgets('a message over 1000 code points is rejected locally and the draft is kept', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ChildCoachScreen()));
      // 600 graphemes (fits maxLength) but 1200 code points (over the backend limit)
      final text = '👍🏽' * 600;
      await tester.enterText(find.byType(TextField), text);
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      expect(find.textContaining('سؤالك طويل جداً'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, text);
    });
  });

  group('Mission parsing (#64, #116, #258, #115)', () {
    test('chore XP equals int(reward), like the backend apply_xp', () {
      expect(parseChildMission({'id': 'm1', 'kind': 'chore', 'reward': 15.0, 'status': 'pending'}).rewardXp, 15);
      expect(parseChildMission({'id': 'm2', 'kind': 'chore', 'reward': 25.5}).rewardXp, 25);
      expect(parseChildMission({'id': 'm3', 'reward': 200}).rewardXp, 200);
    });

    test('redemptions award no XP', () {
      final m = parseChildMission({'id': 'r1', 'kind': 'redemption', 'reward': 40.0, 'status': 'submitted'});
      expect(m.rewardXp, 0);
      expect(m.isRedemption, isTrue);
      expect(m.rewardAmount, 40.0);
    });

    test('an explicit reward_xp from the server wins', () {
      expect(parseChildMission({'id': 'm4', 'kind': 'chore', 'reward': 15, 'reward_xp': 7}).rewardXp, 7);
    });

    test('rejected status is preserved', () {
      expect(parseChildMission({'id': 'm5', 'status': 'rejected', 'reward': 5}).isRejected, isTrue);
    });
  });

  group('Mission pages merge (#123)', () {
    test('keeps page order and the first occurrence of each id', () {
      final merged = mergeMissionPages([
        [
          {'id': 'p1', 'status': 'pending'},
        ],
        [
          {'id': 's1', 'status': 'submitted'},
        ],
        [
          {'id': 's1', 'status': 'submitted'},
          {'id': 'a1', 'status': 'approved'},
          {'id': 'p1', 'status': 'pending'},
        ],
      ]);
      expect(merged.map((m) => m['id']).toList(), ['p1', 's1', 'a1']);
    });
  });

  group('Lesson statuses (#70, #125, #220, #129)', () {
    const ids = ['les_1', 'les_2', 'les_3'];

    test('nothing completed: les_1 is claimable, the rest locked', () {
      expect(computeLessonStatuses(ids, const []), ['in_progress', 'locked', 'locked']);
    });

    test('server list drives completion', () {
      expect(computeLessonStatuses(ids, const ['les_1']), ['completed', 'in_progress', 'locked']);
      expect(computeLessonStatuses(ids, const ['les_1', 'les_2']), ['completed', 'completed', 'in_progress']);
    });
  });

  group('Meeza today spent (#111, #230, #255)', () {
    test('counts card purchases and redemptions since local midnight, parsing naive UTC', () {
      final now = DateTime.now();
      final localMidnight = DateTime(now.year, now.month, now.day);
      final txs = [
        {'direction': 'debit', 'type': 'card_purchase', 'amount': 10.0, 'created_date': naiveUtc(now)},
        {'direction': 'debit', 'type': 'redemption', 'amount': 40.0, 'created_date': naiveUtc(now)},
        // Just after local midnight: still today even when the UTC date is the previous day
        {
          'direction': 'debit',
          'type': 'card_purchase',
          'amount': 5.25,
          'created_date': naiveUtc(localMidnight.add(const Duration(minutes: 1))),
        },
        // Not spending / not today
        {'direction': 'debit', 'type': 'savings_transfer', 'amount': 20.0, 'created_date': naiveUtc(now)},
        {'direction': 'credit', 'type': 'allowance', 'amount': 100.0, 'created_date': naiveUtc(now)},
        {
          'direction': 'debit',
          'type': 'card_purchase',
          'amount': 7.0,
          'created_date': naiveUtc(localMidnight.subtract(const Duration(minutes: 1))),
        },
      ];
      expect(computeTodaySpent(txs, now: now), closeTo(55.25, 1e-9));
    });
  });

  group('Wallet monthly spending (#112, #224, #256)', () {
    test('groups completed card purchases by category, excludes saving and other months', () {
      final now = DateTime(2026, 10, 15, 12);
      final thisMonth = naiveUtc(DateTime(2026, 10, 10, 12));
      final lastMonth = naiveUtc(DateTime(2026, 9, 10, 12));
      final purchases = [
        {'category': 'Food', 'amount': 10.1, 'status': 'completed', 'created_date': thisMonth},
        {'category': 'Food', 'amount': 20.2, 'status': 'completed', 'created_date': thisMonth},
        {'category': 'Toys', 'amount': 50.0, 'status': 'pending', 'created_date': thisMonth},
        {'category': 'Gaming', 'amount': 30.0, 'status': 'completed', 'created_date': lastMonth},
        {'category': 'Books', 'amount': 3.0, 'status': 'completed', 'created_date': thisMonth},
      ];
      final txs = [
        {'direction': 'debit', 'type': 'savings_transfer', 'amount': 50.0, 'created_date': thisMonth},
        {'direction': 'debit', 'type': 'card_purchase', 'amount': 10.1, 'created_date': thisMonth},
        {'direction': 'debit', 'type': 'redemption', 'amount': 40.0, 'created_date': thisMonth},
        {'direction': 'debit', 'type': 'redemption', 'amount': 99.0, 'created_date': lastMonth},
        {'direction': 'credit', 'type': 'allowance', 'amount': 100.0, 'created_date': thisMonth},
      ];

      final sums = computeMonthlySpending(txs, purchases, now: now);
      expect(sums['الوجبات السريعة والمطاعم 🍔'], 30.3);
      expect(sums['مكافآت مصروفة 🏆'], 40.0);
      expect(sums['أخرى'], 3.0);
      expect(sums.containsKey('الألعاب والدمى 🧸'), isFalse);
      expect(sums.containsKey('ألعاب الفيديو والشحن الإلكتروني 🎮'), isFalse);
      expect(sums.values.fold<double>(0, (s, v) => s + v), closeTo(73.3, 1e-9));
    });

    test('no spending this month gives an empty breakdown', () {
      expect(computeMonthlySpending(const [], const []), isEmpty);
    });
  });
}
