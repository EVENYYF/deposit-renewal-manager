import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart' as db;
import '../domain/message_template.dart';

final class TemplateRepository {
  TemplateRepository(
    this._database, {
    required this.sourceDeviceId,
    DateTime Function()? nowUtc,
    Uuid? uuid,
  }) : _nowUtc = nowUtc ?? clock.now,
       _uuid = uuid ?? const Uuid();

  final db.AppDatabase _database;
  final String sourceDeviceId;
  final DateTime Function() _nowUtc;
  final Uuid _uuid;

  Future<List<MessageTemplate>> load() async {
    final rows =
        await (_database.select(_database.messageTemplates)..orderBy([
              (row) => OrderingTerm.desc(row.isDefault),
              (row) => OrderingTerm.asc(row.name),
            ]))
            .get();
    return rows
        .map(
          (row) => MessageTemplate(
            id: row.id,
            name: row.name,
            body: row.content,
            isEnabled: row.isActive,
            isDefault: row.isDefault,
          ),
        )
        .toList(growable: false);
  }

  Future<MessageTemplate> save(MessageTemplate draft) => _database.transaction(
    () async {
      final name = draft.name.trim();
      final body = draft.body.trim();
      if (name.isEmpty) throw const FormatException('模板名称不能为空');
      if (body.isEmpty) throw const FormatException('模板内容不能为空');
      if (draft.isDefault && !draft.isEnabled) {
        throw const FormatException('默认模板必须启用');
      }

      final id = draft.id.isEmpty ? _uuid.v4() : draft.id;
      final existing = await (_database.select(
        _database.messageTemplates,
      )..where((row) => row.id.equals(id))).getSingleOrNull();
      final timestamp = _nowUtc().toUtc().microsecondsSinceEpoch;
      final demotedDefaults = draft.isDefault
          ? await (_database.select(_database.messageTemplates)..where(
                  (row) => row.isDefault.equals(true) & row.id.isNotValue(id),
                ))
                .get()
          : const <db.MessageTemplate>[];
      if (draft.isDefault) {
        await (_database.update(
          _database.messageTemplates,
        )..where((row) => row.id.isNotValue(id))).write(
          db.MessageTemplatesCompanion(
            isDefault: const Value(false),
            updatedAtUtc: Value(timestamp),
          ),
        );
      }
      final saved = MessageTemplate(
        id: id,
        name: name,
        body: body,
        isEnabled: draft.isEnabled,
        isDefault: draft.isDefault,
      );
      await _database
          .into(_database.messageTemplates)
          .insertOnConflictUpdate(
            db.MessageTemplatesCompanion.insert(
              id: id,
              name: name,
              content: body,
              isActive: Value(draft.isEnabled),
              isDefault: Value(draft.isDefault),
              createdAtUtc: existing?.createdAtUtc ?? timestamp,
              updatedAtUtc: timestamp,
            ),
          );
      final revision = await _database.incrementBusinessRevision();
      for (final demoted in demotedDefaults) {
        final after = MessageTemplate(
          id: demoted.id,
          name: demoted.name,
          body: demoted.content,
          isEnabled: demoted.isActive,
          isDefault: false,
        );
        await _database
            .into(_database.auditHistory)
            .insert(
              db.AuditHistoryCompanion.insert(
                id: _uuid.v4(),
                entityType: 'message_template',
                entityId: demoted.id,
                operation: 'unset_default',
                beforeJson: Value(_encodeRow(demoted)),
                afterJson: Value(jsonEncode(_toJson(after))),
                occurredAtUtc: timestamp,
                sourceDeviceId: sourceDeviceId,
                businessRevision: revision,
              ),
            );
      }
      await _database
          .into(_database.auditHistory)
          .insert(
            db.AuditHistoryCompanion.insert(
              id: _uuid.v4(),
              entityType: 'message_template',
              entityId: id,
              operation: existing == null ? 'create' : 'update',
              beforeJson: Value(existing == null ? null : _encodeRow(existing)),
              afterJson: Value(jsonEncode(_toJson(saved))),
              occurredAtUtc: timestamp,
              sourceDeviceId: sourceDeviceId,
              businessRevision: revision,
            ),
          );
      return saved;
    },
  );

  String _encodeRow(db.MessageTemplate row) => jsonEncode({
    'id': row.id,
    'name': row.name,
    'body': row.content,
    'isEnabled': row.isActive,
    'isDefault': row.isDefault,
  });

  Map<String, Object?> _toJson(MessageTemplate value) => {
    'id': value.id,
    'name': value.name,
    'body': value.body,
    'isEnabled': value.isEnabled,
    'isDefault': value.isDefault,
  };
}
