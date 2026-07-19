import 'package:deposit_renewal_manager/core/database/app_database.dart';
import 'package:deposit_renewal_manager/core/database/daos/customer_dao.dart';
import 'package:deposit_renewal_manager/features/customers/application/customer_search_service.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/seed_search_benchmark.dart';

void main() {
  test(
    '10k customer SQLite memory development baseline has P95 under 200ms',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await seedSearchBenchmark(database);

      final count = database.customers.id.count();
      final row = await (database.selectOnly(
        database.customers,
      )..addColumns([count])).getSingle();
      expect(row.read(count), 10000);

      final samples = await runSearchBenchmark(
        CustomerSearchService(
          CustomerDao(database, sourceDeviceId: 'benchmark-test'),
        ),
      );
      // Android device acceptance remains a separate release verification step.
      // ignore: avoid_print
      print(
        'SQLite memory development-host P95: ${samples.p95.inMicroseconds}us',
      );
      expect(samples.p95.inMilliseconds, lessThan(200));
    },
  );
}
