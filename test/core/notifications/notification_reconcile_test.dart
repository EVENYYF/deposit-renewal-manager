import 'package:deposit_renewal_manager/core/database/app_database.dart';
import 'package:deposit_renewal_manager/core/notifications/notification_plan.dart';
import 'package:deposit_renewal_manager/core/notifications/notification_scheduler.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/deposit.dart'
    as domain;
import 'package:deposit_renewal_manager/features/deposits/domain/deposit_repository.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/local_date.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  test('stable ID persists and probes deterministic collisions', () async {
    final store = StableNotificationIdStore(
      database,
      candidate: (entity, attempt) => attempt == 0 ? 42 : 100 + entity.length,
      nowUtc: () => DateTime.utc(2026),
    );

    final first = await store.idFor('a');
    final collision = await store.idFor('bb');
    final reopened = StableNotificationIdStore(
      database,
      candidate: (_, _) => 999,
    );

    expect(first, 42);
    expect(collision, 102);
    expect(await reopened.idFor('a'), 42);
    expect(
      await database.select(database.notificationIdMappings).get(),
      hasLength(2),
    );
  });

  test(
    'exact capability schedules exact and unavailable exact degrades',
    () async {
      final exact = _Gateway(canExact: true);
      final exactResult = await _scheduler(database, exact).reconcileAll();
      expect(exactResult.degraded, isFalse);
      expect(exact.requests.map((item) => item.precision).toSet(), {
        NotificationSchedulePrecision.exactAllowWhileIdle,
      });

      final inexact = _Gateway(canExact: false);
      final inexactResult = await _scheduler(database, inexact).reconcileAll();
      expect(inexactResult.degraded, isTrue);
      expect(inexact.requests.map((item) => item.precision).toSet(), {
        NotificationSchedulePrecision.inexactAllowWhileIdle,
      });
    },
  );

  test('permission denied reports degraded without scheduling', () async {
    final gateway = _Gateway(notificationsAllowed: false);
    final result = await _scheduler(database, gateway).reconcileAll();

    expect(result.degraded, isTrue);
    expect(result.scheduledCount, 0);
    expect(gateway.requests, isEmpty);
  });

  test(
    'reconcile replaces active IDs without clearing and cancel removes mappings',
    () async {
      final gateway = _Gateway();
      final scheduler = _scheduler(database, gateway);
      await scheduler.reconcileAll();
      final firstIds = gateway.requests.map((item) => item.id).toSet();

      await scheduler.reconcileDeposit('deposit-1');
      expect(gateway.cancelled, isEmpty);

      final cancel = await scheduler.cancelDeposit('deposit-1');
      expect(cancel.cancelledCount, 3);
      expect(gateway.cancelled, containsAll(firstIds));
      expect(
        await database.select(database.notificationIdMappings).get(),
        isEmpty,
      );
    },
  );

  test('caps deposit alarms at 400 and reports truncation', () async {
    final gateway = _Gateway();
    final deposits = List.generate(
      150,
      (index) => _stored('d-$index', 'c-$index', LocalDate(2026, 7, 27)),
    );
    final result = await _scheduler(
      database,
      gateway,
      deposits: deposits,
    ).reconcileAll();

    expect(gateway.requests, hasLength(400));
    expect(result.truncatedCount, 50);
    expect(result.status, NotificationReconcileStatus.degraded);
  });

  test('schedule failure keeps stale valid alarms and mappings', () async {
    final store = StableNotificationIdStore(database);
    final staleId = await store.idFor('deposit:stale:0');
    final gateway = _Gateway(failAtSchedule: 0);
    final result = await _scheduler(database, gateway).reconcileAll();

    expect(result.status, NotificationReconcileStatus.error);
    expect(gateway.cancelled, isNot(contains(staleId)));
    expect(
      (await store.mappingsWithPrefix('deposit:stale:')).single.notificationId,
      staleId,
    );
  });

  test(
    'upgrade removes 30 legacy summary mappings without recreating them',
    () async {
      final store = StableNotificationIdStore(database);
      final legacyIds = <int>{};
      for (var index = 0; index < 30; index++) {
        legacyIds.add(await store.idFor('summary:$index'));
      }
      final gateway = _Gateway();

      await _scheduler(database, gateway).reconcileAll();

      expect(gateway.cancelled.toSet(), containsAll(legacyIds));
      expect(await store.mappingsWithPrefix('summary:'), isEmpty);
    },
  );

  test('notification payload JSON is strict and round trips', () {
    const payload = NotificationPayload(customerId: 'c-1', depositId: 'd-1');
    expect(NotificationPayload.parse(payload.toJson()).depositId, 'd-1');
    expect(
      () =>
          NotificationPayload.parse('{"customerId":"c","depositId":"d","x":1}'),
      throwsFormatException,
    );
    expect(
      () => NotificationPayload.parse('{"customerId":"c"}'),
      throwsFormatException,
    );
  });
}

NotificationScheduler _scheduler(
  AppDatabase database,
  _Gateway gateway, {
  List<StoredDeposit>? deposits,
}) => NotificationReconciler(
  dataSource: _DataSource(
    deposits ?? [_stored('deposit-1', 'customer-1', LocalDate(2026, 7, 27))],
  ),
  gateway: gateway,
  idStore: StableNotificationIdStore(
    database,
    nowUtc: () => DateTime.utc(2026),
  ),
  clock: _Clock(),
  settings: const NotificationPlanSettings(summaryHorizonDays: 2),
);

final class _Gateway implements NotificationGateway {
  _Gateway({
    this.notificationsAllowed = true,
    this.canExact = true,
    this.failAtSchedule,
  });

  final bool notificationsAllowed;
  final bool canExact;
  final int? failAtSchedule;
  final List<ScheduledNotificationRequest> requests = [];
  final List<int> cancelled = [];

  @override
  Future<void> cancel(int notificationId) async =>
      cancelled.add(notificationId);

  @override
  Future<void> openSettings() async {}

  @override
  Future<bool> requestExactAlarmPermission() async => canExact;

  @override
  Future<bool> requestNotificationPermission() async => notificationsAllowed;

  @override
  Future<NotificationCapability> capability() async => NotificationCapability(
    support: NotificationSupport.supported,
    notificationsAllowed: notificationsAllowed,
    canScheduleExact: canExact,
  );

  @override
  Future<void> schedule(ScheduledNotificationRequest request) async {
    if (requests.length == failAtSchedule) throw StateError('schedule failed');
    requests.add(request);
  }
}

final class _Clock implements NotificationLocalClock {
  @override
  DateTime at(LocalDate date, int hour, int minute) =>
      DateTime(date.year, date.month, date.day, hour, minute);

  @override
  DateTime now() => DateTime(2026, 7, 20, 8);

  @override
  LocalDate today() => LocalDate(2026, 7, 20);
}

final class _DataSource implements NotificationDataSource {
  const _DataSource(this.deposits);
  final List<StoredDeposit> deposits;

  @override
  Future<List<StoredDeposit>> activeDeposits() async => deposits;

  @override
  Future<StoredDeposit?> deposit(String depositId) async =>
      deposits.where((stored) => stored.deposit.id == depositId).firstOrNull;
}

StoredDeposit _stored(String id, String customerId, LocalDate expiry) =>
    StoredDeposit(
      deposit: domain.Deposit.direct(id: id, expiryDate: expiry),
      customerId: customerId,
      amountCents: 1,
      bankName: '',
      interestRateScaled: 0,
      ratePrecision: 0,
      startDate: expiry,
    );
