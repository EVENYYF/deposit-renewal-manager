import 'package:deposit_renewal_manager/core/database/app_database.dart';
import 'package:deposit_renewal_manager/features/templates/application/template_repository.dart';
import 'package:deposit_renewal_manager/features/templates/domain/message_template.dart'
    as domain;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase database;
  late TemplateRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = TemplateRepository(
      database,
      sourceDeviceId: 'test-device',
      nowUtc: () => DateTime.utc(2026, 7, 19),
      uuid: const Uuid(),
    );
  });

  tearDown(() => database.close());

  test(
    'persists enabled state and atomically moves the default flag',
    () async {
      final first = await repository.save(
        const domain.MessageTemplate(
          name: '模板一',
          body: '您好 {{customerName}}',
          isDefault: true,
        ),
      );
      final second = await repository.save(
        const domain.MessageTemplate(
          name: '模板二',
          body: '{{expiryDate}} 到期',
          isEnabled: false,
        ),
      );
      await repository.save(
        domain.MessageTemplate(
          id: second.id,
          name: second.name,
          body: second.body,
          isDefault: true,
        ),
      );

      final templates = await repository.load();
      expect(templates, hasLength(2));
      expect(
        templates.singleWhere((item) => item.id == first.id).isDefault,
        false,
      );
      expect(
        templates.singleWhere((item) => item.id == second.id).isDefault,
        true,
      );
      expect(await database.businessRevision(), 3);
      expect(await database.auditEntryCount(), 3);
    },
  );

  test('rejects a disabled default without writing partial data', () async {
    await expectLater(
      repository.save(
        const domain.MessageTemplate(
          name: '非法模板',
          body: '内容',
          isEnabled: false,
          isDefault: true,
        ),
      ),
      throwsFormatException,
    );

    expect(await repository.load(), isEmpty);
    expect(await database.businessRevision(), 0);
    expect(await database.auditEntryCount(), 0);
  });
}
