import 'package:deposit_renewal_manager/core/database/app_database.dart';
import 'package:deposit_renewal_manager/core/database/daos/customer_dao.dart';
import 'package:deposit_renewal_manager/features/customers/application/customer_search_service.dart';
import 'package:deposit_renewal_manager/features/customers/domain/name_search_index.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

final class BenchmarkSamples {
  BenchmarkSamples(Iterable<Duration> values)
    : values = List.unmodifiable(values);

  final List<Duration> values;

  Duration get p95 {
    if (values.isEmpty) return Duration.zero;
    final sorted = [...values]..sort();
    final index = ((sorted.length * 95 + 99) ~/ 100) - 1;
    return sorted[index.clamp(0, sorted.length - 1)];
  }
}

Future<void> seedSearchBenchmark(AppDatabase database, {int count = 10000}) {
  final timestamp = DateTime.utc(2026, 7, 18).microsecondsSinceEpoch;
  return database.batch((batch) {
    for (var index = 0; index < count; index++) {
      final suffix = index.toString().padLeft(5, '0');
      final name = '客户$suffix';
      final searchIndex = buildNameIndex(name);
      batch.insert(
        database.customers,
        CustomersCompanion.insert(
          id: 'benchmark-$suffix',
          name: name,
          phone: Value('138${index.toString().padLeft(8, '0')}'),
          normalizedName: Value(searchIndex.normalizedName),
          fullPinyin: Value(searchIndex.fullPinyin),
          initials: Value(searchIndex.initials),
          normalizedPhone: Value('138${index.toString().padLeft(8, '0')}'),
          createdAtUtc: timestamp,
          updatedAtUtc: timestamp,
        ),
      );
    }
  });
}

Future<BenchmarkSamples> runSearchBenchmark(
  CustomerSearchService service, {
  int sampleCount = 30,
}) async {
  await service.search(const CustomerQuery(text: 'kehu09999'));
  final samples = <Duration>[];
  for (var index = 0; index < sampleCount; index++) {
    final stopwatch = Stopwatch()..start();
    final result = await service.search(const CustomerQuery(text: 'kehu09999'));
    stopwatch.stop();
    if (result.length != 1 || result.single.customer.name != '客户09999') {
      throw StateError('Benchmark query returned an unexpected result');
    }
    samples.add(stopwatch.elapsed);
  }
  return BenchmarkSamples(samples);
}

Future<void> main() async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  try {
    await seedSearchBenchmark(database);
    final service = CustomerSearchService(
      CustomerDao(database, sourceDeviceId: 'benchmark'),
    );
    final samples = await runSearchBenchmark(service);
    // This is a development-host baseline, not Android device acceptance.
    // ignore: avoid_print
    print(
      'SQLite memory development-host P95: ${samples.p95.inMicroseconds}us',
    );
  } finally {
    await database.close();
  }
}
