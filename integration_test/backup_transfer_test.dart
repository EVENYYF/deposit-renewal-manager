import 'dart:io';

import 'package:deposit_renewal_manager/core/backup/backup_service.dart';
import 'package:deposit_renewal_manager/core/database/app_database.dart';
import 'package:deposit_renewal_manager/core/database/daos/customer_dao.dart';
import 'package:deposit_renewal_manager/core/database/daos/deposit_dao.dart';
import 'package:deposit_renewal_manager/features/customers/domain/customer_repository.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/deposit_repository.dart';
import 'package:deposit_renewal_manager/features/deposits/domain/local_date.dart';
import 'package:deposit_renewal_manager/features/templates/application/template_repository.dart';
import 'package:deposit_renewal_manager/features/templates/domain/message_template.dart'
    as template_domain;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('transfers business data and keeps target device settings', (
    tester,
  ) async {
    final temp = await Directory.systemTemp.createTemp('deposit-transfer-');
    final source = AppDatabase.forTesting(NativeDatabase.memory());
    final target = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async {
      await source.close();
      await target.close();
      await temp.delete(recursive: true);
    });

    const customerId = 'customer-1';
    const sourceDepositId = 'deposit-source';
    const targetDepositId = 'deposit-renewed';
    final customerDao = CustomerDao(
      source,
      sourceDeviceId: 'android',
      nowUtc: () => DateTime.utc(2026, 7, 19),
    );
    await customerDao.create(
      const CustomerDraft(id: customerId, name: '张三', phone: '13800138000'),
    );
    final deposits = DepositDao(
      source,
      sourceDeviceId: 'android',
      nowUtc: () => DateTime.utc(2026, 7, 19),
    );
    final draft = DepositDraft(
      id: sourceDepositId,
      customerId: customerId,
      amountCents: 1000000,
      bankName: '测试银行',
      interestRateScaled: 150,
      ratePrecision: 2,
      startDate: LocalDate(2025, 7, 19),
      calculatedExpiryDate: LocalDate(2026, 7, 19),
      finalExpiryDate: LocalDate(2026, 7, 19),
    );
    await deposits.create(draft);
    await deposits.renew(
      sourceDepositId,
      DepositDraft(
        id: targetDepositId,
        customerId: customerId,
        amountCents: draft.amountCents,
        bankName: draft.bankName,
        interestRateScaled: draft.interestRateScaled,
        ratePrecision: draft.ratePrecision,
        startDate: LocalDate(2026, 7, 19),
        calculatedExpiryDate: LocalDate(2027, 7, 19),
        finalExpiryDate: LocalDate(2027, 7, 19),
      ),
    );
    await TemplateRepository(
      source,
      sourceDeviceId: 'android',
      nowUtc: () => DateTime.utc(2026, 7, 19),
    ).save(
      const template_domain.MessageTemplate(
        id: 'template-1',
        name: '到期提醒',
        body: '您好，{{customerName}}',
        isDefault: true,
      ),
    );
    await target
        .into(target.notificationIdMappings)
        .insert(
          NotificationIdMappingsCompanion.insert(
            entityId: 'local-device-setting',
            notificationId: 42,
            createdAtUtc: DateTime.utc(2026, 7, 19).microsecondsSinceEpoch,
          ),
        );

    final sourceBackup = BackupService(
      database: source,
      sourceDevice: 'Android',
      snapshotsDirectory: temp,
    );
    final path = (await sourceBackup.exportBackup(
      outputPath: '${temp.path}${Platform.pathSeparator}transfer.drbackup',
    )).path;
    final targetBackup = BackupService(
      database: target,
      sourceDevice: 'Windows',
      snapshotsDirectory: temp,
    );
    final inspected = await targetBackup.inspectBackup(path);
    await targetBackup.restore(inspected);

    expect(
      await target.exportBusinessData(),
      await source.exportBusinessData(),
    );
    expect(
      (await target.select(target.notificationIdMappings).getSingle())
          .notificationId,
      42,
    );
    expect(
      (await target.select(target.deposits).get()).map((row) => row.lifecycle),
      containsAll(<String>['renewed', 'active']),
    );
  });
}
