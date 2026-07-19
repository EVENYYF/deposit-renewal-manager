import 'package:deposit_renewal_manager/features/settings/presentation/backup_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps plaintext warning and real backup actions visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BackupSettingsPage.withBindings(
          bindings: BackupSettingsBindings(
            listSnapshots: () async => const [],
            exportBackup: () async => null,
            pickBackup: () async => null,
            inspectBackup: (_) => throw UnimplementedError(),
            restoreBackup: (_) async {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('本地明文数据'), findsOneWidget);
    expect(find.text('导出本地备份'), findsOneWidget);
    expect(find.text('导入并恢复备份'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
