import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/backup/backup_service.dart';
import '../../../core/backup/snapshot_store.dart';

final class BackupSettingsBindings {
  const BackupSettingsBindings({
    required this.listSnapshots,
    required this.exportBackup,
    required this.pickBackup,
    required this.inspectBackup,
    required this.inspectRestoreImpact,
    required this.restoreBackup,
  });

  final Future<List<SnapshotInfo>> Function() listSnapshots;
  final Future<String?> Function() exportBackup;
  final Future<String?> Function() pickBackup;
  final Future<InspectedBackup> Function(String path) inspectBackup;
  final Future<RestoreImpact> Function(InspectedBackup backup)
  inspectRestoreImpact;
  final Future<void> Function(
    InspectedBackup backup,
    int expectedBusinessRevision,
  )
  restoreBackup;

  static BackupSettingsBindings fromService(
    BackupService backup, {
    Future<void> Function()? afterRestore,
  }) => BackupSettingsBindings(
    listSnapshots: backup.listSnapshots,
    exportBackup: () async {
      final archive = await backup.buildBackupArchive();
      final path = await FilePicker.platform.saveFile(
        dialogTitle: '导出备份',
        fileName: archive.suggestedFileName,
        type: FileType.custom,
        allowedExtensions: const ['drbackup'],
        bytes: archive.bytes,
      );
      if (path == null) return null;
      return path;
    },
    pickBackup: () async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['drbackup'],
      );
      return result?.files.single.path;
    },
    inspectBackup: backup.inspectBackup,
    inspectRestoreImpact: backup.inspectRestoreImpact,
    restoreBackup: (inspected, expectedBusinessRevision) async {
      await backup.restore(
        inspected,
        expectedBusinessRevision: expectedBusinessRevision,
      );
      await afterRestore?.call();
    },
  );
}

class BackupSettingsPage extends StatefulWidget {
  BackupSettingsPage({
    super.key,
    required BackupService backup,
    Future<void> Function()? afterRestore,
  }) : bindings = BackupSettingsBindings.fromService(
         backup,
         afterRestore: afterRestore,
       );

  const BackupSettingsPage.withBindings({super.key, required this.bindings});

  final BackupSettingsBindings bindings;

  @override
  State<BackupSettingsPage> createState() => _BackupSettingsPageState();
}

class _BackupSettingsPageState extends State<BackupSettingsPage> {
  List<SnapshotInfo> _snapshots = const [];
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadSnapshots();
  }

  Future<void> _loadSnapshots() async {
    try {
      final snapshots = await widget.bindings.listSnapshots();
      if (mounted) setState(() => _snapshots = snapshots);
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    }
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final path = await widget.bindings.exportBackup();
      if (path == null) return;
      if (mounted) setState(() => _message = '备份已导出：$path');
    } catch (error) {
      if (mounted) setState(() => _message = '导出失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    try {
      final path = await widget.bindings.pickBackup();
      if (path == null) return;
      final inspected = await widget.bindings.inspectBackup(path);
      final impact = await widget.bindings.inspectRestoreImpact(inspected);
      if (!mounted) return;
      final counts = inspected.manifest.counts;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认恢复备份？'),
          content: Text(
            '来源设备：${inspected.manifest.sourceDevice}\n版本：${inspected.manifest.schemaVersion}\n时间：${inspected.manifest.createdAtUtc.toLocal()}\n备份包含客户 ${counts['customers'] ?? 0} 条、存款 ${counts['deposits'] ?? 0} 条。\n\n当前库中将丢失 ${impact.totalLost} 条记录：客户 ${impact.lostRecords['customers'] ?? 0}、存款 ${impact.lostRecords['deposits'] ?? 0}、续期关系 ${impact.lostRecords['renewals'] ?? 0}、模板 ${impact.lostRecords['message_templates'] ?? 0}、导入批次 ${impact.lostRecords['import_batches'] ?? 0}、审计记录 ${impact.lostRecords['audit_history'] ?? 0}。\n\n同一编号的记录也会被备份内容覆盖。恢复前会自动创建快照。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认恢复'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
      await widget.bindings.restoreBackup(inspected, impact.businessRevision);
      if (mounted) setState(() => _message = '恢复完成，请重新打开需要刷新的页面');
      await _loadSnapshots();
    } catch (error) {
      if (mounted) setState(() => _message = '恢复失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('备份与设置')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: const ListTile(
            leading: Icon(Icons.warning_amber_outlined),
            title: Text('本地明文数据'),
            subtitle: Text('备份文件未加密，请妥善保管手机和导出文件。'),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy ? null : _export,
          icon: const Icon(Icons.upload_file),
          label: const Text('导出本地备份'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _restore,
          icon: const Icon(Icons.restore),
          label: const Text('导入并恢复备份'),
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_message!),
          ),
        const Divider(height: 32),
        Text('自动快照（最多保留 10 份）', style: Theme.of(context).textTheme.titleMedium),
        if (_snapshots.isEmpty)
          const ListTile(contentPadding: EdgeInsets.zero, title: Text('暂无快照')),
        for (final snapshot in _snapshots)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history),
            title: Text(snapshot.operation),
            subtitle: Text(snapshot.createdAtUtc.toLocal().toString()),
            dense: true,
          ),
      ],
    ),
  );
}
