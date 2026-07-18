// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CustomersTable extends Customers
    with TableInfo<$CustomersTable, Customer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    check: () => ComparableExpr(name.length).isBiggerThanValue(0),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _normalizedNameMeta = const VerificationMeta(
    'normalizedName',
  );
  @override
  late final GeneratedColumn<String> normalizedName = GeneratedColumn<String>(
    'normalized_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _fullPinyinMeta = const VerificationMeta(
    'fullPinyin',
  );
  @override
  late final GeneratedColumn<String> fullPinyin = GeneratedColumn<String>(
    'full_pinyin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _initialsMeta = const VerificationMeta(
    'initials',
  );
  @override
  late final GeneratedColumn<String> initials = GeneratedColumn<String>(
    'initials',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _normalizedPhoneMeta = const VerificationMeta(
    'normalizedPhone',
  );
  @override
  late final GeneratedColumn<String> normalizedPhone = GeneratedColumn<String>(
    'normalized_phone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<int> createdAtUtc = GeneratedColumn<int>(
    'created_at_utc',
    aliasedName,
    false,
    check: () => utcEpochCheck('created_at_utc'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<int> updatedAtUtc = GeneratedColumn<int>(
    'updated_at_utc',
    aliasedName,
    false,
    check: () => utcEpochCheck('updated_at_utc'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    phone,
    normalizedName,
    fullPinyin,
    initials,
    normalizedPhone,
    isActive,
    createdAtUtc,
    updatedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'customers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Customer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('normalized_name')) {
      context.handle(
        _normalizedNameMeta,
        normalizedName.isAcceptableOrUnknown(
          data['normalized_name']!,
          _normalizedNameMeta,
        ),
      );
    }
    if (data.containsKey('full_pinyin')) {
      context.handle(
        _fullPinyinMeta,
        fullPinyin.isAcceptableOrUnknown(data['full_pinyin']!, _fullPinyinMeta),
      );
    }
    if (data.containsKey('initials')) {
      context.handle(
        _initialsMeta,
        initials.isAcceptableOrUnknown(data['initials']!, _initialsMeta),
      );
    }
    if (data.containsKey('normalized_phone')) {
      context.handle(
        _normalizedPhoneMeta,
        normalizedPhone.isAcceptableOrUnknown(
          data['normalized_phone']!,
          _normalizedPhoneMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Customer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Customer(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      normalizedName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_name'],
      )!,
      fullPinyin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}full_pinyin'],
      )!,
      initials: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}initials'],
      )!,
      normalizedPhone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_phone'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc'],
      )!,
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_utc'],
      )!,
    );
  }

  @override
  $CustomersTable createAlias(String alias) {
    return $CustomersTable(attachedDatabase, alias);
  }
}

class Customer extends DataClass implements Insertable<Customer> {
  final String id;
  final String name;
  final String? phone;
  final String normalizedName;
  final String fullPinyin;
  final String initials;
  final String normalizedPhone;
  final bool isActive;
  final int createdAtUtc;
  final int updatedAtUtc;
  const Customer({
    required this.id,
    required this.name,
    this.phone,
    required this.normalizedName,
    required this.fullPinyin,
    required this.initials,
    required this.normalizedPhone,
    required this.isActive,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    map['normalized_name'] = Variable<String>(normalizedName);
    map['full_pinyin'] = Variable<String>(fullPinyin);
    map['initials'] = Variable<String>(initials);
    map['normalized_phone'] = Variable<String>(normalizedPhone);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at_utc'] = Variable<int>(createdAtUtc);
    map['updated_at_utc'] = Variable<int>(updatedAtUtc);
    return map;
  }

  CustomersCompanion toCompanion(bool nullToAbsent) {
    return CustomersCompanion(
      id: Value(id),
      name: Value(name),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      normalizedName: Value(normalizedName),
      fullPinyin: Value(fullPinyin),
      initials: Value(initials),
      normalizedPhone: Value(normalizedPhone),
      isActive: Value(isActive),
      createdAtUtc: Value(createdAtUtc),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory Customer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Customer(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      phone: serializer.fromJson<String?>(json['phone']),
      normalizedName: serializer.fromJson<String>(json['normalizedName']),
      fullPinyin: serializer.fromJson<String>(json['fullPinyin']),
      initials: serializer.fromJson<String>(json['initials']),
      normalizedPhone: serializer.fromJson<String>(json['normalizedPhone']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAtUtc: serializer.fromJson<int>(json['createdAtUtc']),
      updatedAtUtc: serializer.fromJson<int>(json['updatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'phone': serializer.toJson<String?>(phone),
      'normalizedName': serializer.toJson<String>(normalizedName),
      'fullPinyin': serializer.toJson<String>(fullPinyin),
      'initials': serializer.toJson<String>(initials),
      'normalizedPhone': serializer.toJson<String>(normalizedPhone),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAtUtc': serializer.toJson<int>(createdAtUtc),
      'updatedAtUtc': serializer.toJson<int>(updatedAtUtc),
    };
  }

  Customer copyWith({
    String? id,
    String? name,
    Value<String?> phone = const Value.absent(),
    String? normalizedName,
    String? fullPinyin,
    String? initials,
    String? normalizedPhone,
    bool? isActive,
    int? createdAtUtc,
    int? updatedAtUtc,
  }) => Customer(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone.present ? phone.value : this.phone,
    normalizedName: normalizedName ?? this.normalizedName,
    fullPinyin: fullPinyin ?? this.fullPinyin,
    initials: initials ?? this.initials,
    normalizedPhone: normalizedPhone ?? this.normalizedPhone,
    isActive: isActive ?? this.isActive,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
  Customer copyWithCompanion(CustomersCompanion data) {
    return Customer(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      phone: data.phone.present ? data.phone.value : this.phone,
      normalizedName: data.normalizedName.present
          ? data.normalizedName.value
          : this.normalizedName,
      fullPinyin: data.fullPinyin.present
          ? data.fullPinyin.value
          : this.fullPinyin,
      initials: data.initials.present ? data.initials.value : this.initials,
      normalizedPhone: data.normalizedPhone.present
          ? data.normalizedPhone.value
          : this.normalizedPhone,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Customer(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('fullPinyin: $fullPinyin, ')
          ..write('initials: $initials, ')
          ..write('normalizedPhone: $normalizedPhone, ')
          ..write('isActive: $isActive, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    phone,
    normalizedName,
    fullPinyin,
    initials,
    normalizedPhone,
    isActive,
    createdAtUtc,
    updatedAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Customer &&
          other.id == this.id &&
          other.name == this.name &&
          other.phone == this.phone &&
          other.normalizedName == this.normalizedName &&
          other.fullPinyin == this.fullPinyin &&
          other.initials == this.initials &&
          other.normalizedPhone == this.normalizedPhone &&
          other.isActive == this.isActive &&
          other.createdAtUtc == this.createdAtUtc &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class CustomersCompanion extends UpdateCompanion<Customer> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> phone;
  final Value<String> normalizedName;
  final Value<String> fullPinyin;
  final Value<String> initials;
  final Value<String> normalizedPhone;
  final Value<bool> isActive;
  final Value<int> createdAtUtc;
  final Value<int> updatedAtUtc;
  final Value<int> rowid;
  const CustomersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.normalizedName = const Value.absent(),
    this.fullPinyin = const Value.absent(),
    this.initials = const Value.absent(),
    this.normalizedPhone = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CustomersCompanion.insert({
    required String id,
    required String name,
    this.phone = const Value.absent(),
    this.normalizedName = const Value.absent(),
    this.fullPinyin = const Value.absent(),
    this.initials = const Value.absent(),
    this.normalizedPhone = const Value.absent(),
    this.isActive = const Value.absent(),
    required int createdAtUtc,
    required int updatedAtUtc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAtUtc = Value(createdAtUtc),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<Customer> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? phone,
    Expression<String>? normalizedName,
    Expression<String>? fullPinyin,
    Expression<String>? initials,
    Expression<String>? normalizedPhone,
    Expression<bool>? isActive,
    Expression<int>? createdAtUtc,
    Expression<int>? updatedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (normalizedName != null) 'normalized_name': normalizedName,
      if (fullPinyin != null) 'full_pinyin': fullPinyin,
      if (initials != null) 'initials': initials,
      if (normalizedPhone != null) 'normalized_phone': normalizedPhone,
      if (isActive != null) 'is_active': isActive,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CustomersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? phone,
    Value<String>? normalizedName,
    Value<String>? fullPinyin,
    Value<String>? initials,
    Value<String>? normalizedPhone,
    Value<bool>? isActive,
    Value<int>? createdAtUtc,
    Value<int>? updatedAtUtc,
    Value<int>? rowid,
  }) {
    return CustomersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      normalizedName: normalizedName ?? this.normalizedName,
      fullPinyin: fullPinyin ?? this.fullPinyin,
      initials: initials ?? this.initials,
      normalizedPhone: normalizedPhone ?? this.normalizedPhone,
      isActive: isActive ?? this.isActive,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (normalizedName.present) {
      map['normalized_name'] = Variable<String>(normalizedName.value);
    }
    if (fullPinyin.present) {
      map['full_pinyin'] = Variable<String>(fullPinyin.value);
    }
    if (initials.present) {
      map['initials'] = Variable<String>(initials.value);
    }
    if (normalizedPhone.present) {
      map['normalized_phone'] = Variable<String>(normalizedPhone.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>(createdAtUtc.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<int>(updatedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('fullPinyin: $fullPinyin, ')
          ..write('initials: $initials, ')
          ..write('normalizedPhone: $normalizedPhone, ')
          ..write('isActive: $isActive, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DepositsTable extends Deposits with TableInfo<$DepositsTable, Deposit> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DepositsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customerIdMeta = const VerificationMeta(
    'customerId',
  );
  @override
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
    'customer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES customers (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _amountCentsMeta = const VerificationMeta(
    'amountCents',
  );
  @override
  late final GeneratedColumn<int> amountCents = GeneratedColumn<int>(
    'amount_cents',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('amount_cents > 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bankNameMeta = const VerificationMeta(
    'bankName',
  );
  @override
  late final GeneratedColumn<String> bankName = GeneratedColumn<String>(
    'bank_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _interestRateScaledMeta =
      const VerificationMeta('interestRateScaled');
  @override
  late final GeneratedColumn<int> interestRateScaled = GeneratedColumn<int>(
    'interest_rate_scaled',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('interest_rate_scaled >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ratePrecisionMeta = const VerificationMeta(
    'ratePrecision',
  );
  @override
  late final GeneratedColumn<int> ratePrecision = GeneratedColumn<int>(
    'rate_precision',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('rate_precision BETWEEN 0 AND 9'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<String> startDate = GeneratedColumn<String>(
    'start_date',
    aliasedName,
    false,
    check: () => isoDateTextCheck('start_date'),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _calculatedExpiryDateMeta =
      const VerificationMeta('calculatedExpiryDate');
  @override
  late final GeneratedColumn<String> calculatedExpiryDate =
      GeneratedColumn<String>(
        'calculated_expiry_date',
        aliasedName,
        true,
        check: () => isoDateTextCheck('calculated_expiry_date'),
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _finalExpiryDateMeta = const VerificationMeta(
    'finalExpiryDate',
  );
  @override
  late final GeneratedColumn<String> finalExpiryDate = GeneratedColumn<String>(
    'final_expiry_date',
    aliasedName,
    false,
    check: () => isoDateTextCheck('final_expiry_date'),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lifecycleMeta = const VerificationMeta(
    'lifecycle',
  );
  @override
  late final GeneratedColumn<String> lifecycle = GeneratedColumn<String>(
    'lifecycle',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>(
      "lifecycle IN ('active', 'renewed', 'stopped')",
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<int> createdAtUtc = GeneratedColumn<int>(
    'created_at_utc',
    aliasedName,
    false,
    check: () => utcEpochCheck('created_at_utc'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<int> updatedAtUtc = GeneratedColumn<int>(
    'updated_at_utc',
    aliasedName,
    false,
    check: () => utcEpochCheck('updated_at_utc'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceDeviceIdMeta = const VerificationMeta(
    'sourceDeviceId',
  );
  @override
  late final GeneratedColumn<String> sourceDeviceId = GeneratedColumn<String>(
    'source_device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    customerId,
    amountCents,
    bankName,
    interestRateScaled,
    ratePrecision,
    startDate,
    calculatedExpiryDate,
    finalExpiryDate,
    lifecycle,
    createdAtUtc,
    updatedAtUtc,
    sourceDeviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'deposits';
  @override
  VerificationContext validateIntegrity(
    Insertable<Deposit> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('customer_id')) {
      context.handle(
        _customerIdMeta,
        customerId.isAcceptableOrUnknown(data['customer_id']!, _customerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_customerIdMeta);
    }
    if (data.containsKey('amount_cents')) {
      context.handle(
        _amountCentsMeta,
        amountCents.isAcceptableOrUnknown(
          data['amount_cents']!,
          _amountCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountCentsMeta);
    }
    if (data.containsKey('bank_name')) {
      context.handle(
        _bankNameMeta,
        bankName.isAcceptableOrUnknown(data['bank_name']!, _bankNameMeta),
      );
    }
    if (data.containsKey('interest_rate_scaled')) {
      context.handle(
        _interestRateScaledMeta,
        interestRateScaled.isAcceptableOrUnknown(
          data['interest_rate_scaled']!,
          _interestRateScaledMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_interestRateScaledMeta);
    }
    if (data.containsKey('rate_precision')) {
      context.handle(
        _ratePrecisionMeta,
        ratePrecision.isAcceptableOrUnknown(
          data['rate_precision']!,
          _ratePrecisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ratePrecisionMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('calculated_expiry_date')) {
      context.handle(
        _calculatedExpiryDateMeta,
        calculatedExpiryDate.isAcceptableOrUnknown(
          data['calculated_expiry_date']!,
          _calculatedExpiryDateMeta,
        ),
      );
    }
    if (data.containsKey('final_expiry_date')) {
      context.handle(
        _finalExpiryDateMeta,
        finalExpiryDate.isAcceptableOrUnknown(
          data['final_expiry_date']!,
          _finalExpiryDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_finalExpiryDateMeta);
    }
    if (data.containsKey('lifecycle')) {
      context.handle(
        _lifecycleMeta,
        lifecycle.isAcceptableOrUnknown(data['lifecycle']!, _lifecycleMeta),
      );
    } else if (isInserting) {
      context.missing(_lifecycleMeta);
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    if (data.containsKey('source_device_id')) {
      context.handle(
        _sourceDeviceIdMeta,
        sourceDeviceId.isAcceptableOrUnknown(
          data['source_device_id']!,
          _sourceDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceDeviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Deposit map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Deposit(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      customerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_id'],
      )!,
      amountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_cents'],
      )!,
      bankName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bank_name'],
      )!,
      interestRateScaled: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interest_rate_scaled'],
      )!,
      ratePrecision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rate_precision'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_date'],
      )!,
      calculatedExpiryDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}calculated_expiry_date'],
      ),
      finalExpiryDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}final_expiry_date'],
      )!,
      lifecycle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lifecycle'],
      )!,
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc'],
      )!,
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_utc'],
      )!,
      sourceDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_device_id'],
      )!,
    );
  }

  @override
  $DepositsTable createAlias(String alias) {
    return $DepositsTable(attachedDatabase, alias);
  }
}

class Deposit extends DataClass implements Insertable<Deposit> {
  final String id;
  final String customerId;
  final int amountCents;
  final String bankName;
  final int interestRateScaled;
  final int ratePrecision;
  final String startDate;
  final String? calculatedExpiryDate;
  final String finalExpiryDate;
  final String lifecycle;
  final int createdAtUtc;
  final int updatedAtUtc;
  final String sourceDeviceId;
  const Deposit({
    required this.id,
    required this.customerId,
    required this.amountCents,
    required this.bankName,
    required this.interestRateScaled,
    required this.ratePrecision,
    required this.startDate,
    this.calculatedExpiryDate,
    required this.finalExpiryDate,
    required this.lifecycle,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.sourceDeviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['customer_id'] = Variable<String>(customerId);
    map['amount_cents'] = Variable<int>(amountCents);
    map['bank_name'] = Variable<String>(bankName);
    map['interest_rate_scaled'] = Variable<int>(interestRateScaled);
    map['rate_precision'] = Variable<int>(ratePrecision);
    map['start_date'] = Variable<String>(startDate);
    if (!nullToAbsent || calculatedExpiryDate != null) {
      map['calculated_expiry_date'] = Variable<String>(calculatedExpiryDate);
    }
    map['final_expiry_date'] = Variable<String>(finalExpiryDate);
    map['lifecycle'] = Variable<String>(lifecycle);
    map['created_at_utc'] = Variable<int>(createdAtUtc);
    map['updated_at_utc'] = Variable<int>(updatedAtUtc);
    map['source_device_id'] = Variable<String>(sourceDeviceId);
    return map;
  }

  DepositsCompanion toCompanion(bool nullToAbsent) {
    return DepositsCompanion(
      id: Value(id),
      customerId: Value(customerId),
      amountCents: Value(amountCents),
      bankName: Value(bankName),
      interestRateScaled: Value(interestRateScaled),
      ratePrecision: Value(ratePrecision),
      startDate: Value(startDate),
      calculatedExpiryDate: calculatedExpiryDate == null && nullToAbsent
          ? const Value.absent()
          : Value(calculatedExpiryDate),
      finalExpiryDate: Value(finalExpiryDate),
      lifecycle: Value(lifecycle),
      createdAtUtc: Value(createdAtUtc),
      updatedAtUtc: Value(updatedAtUtc),
      sourceDeviceId: Value(sourceDeviceId),
    );
  }

  factory Deposit.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Deposit(
      id: serializer.fromJson<String>(json['id']),
      customerId: serializer.fromJson<String>(json['customerId']),
      amountCents: serializer.fromJson<int>(json['amountCents']),
      bankName: serializer.fromJson<String>(json['bankName']),
      interestRateScaled: serializer.fromJson<int>(json['interestRateScaled']),
      ratePrecision: serializer.fromJson<int>(json['ratePrecision']),
      startDate: serializer.fromJson<String>(json['startDate']),
      calculatedExpiryDate: serializer.fromJson<String?>(
        json['calculatedExpiryDate'],
      ),
      finalExpiryDate: serializer.fromJson<String>(json['finalExpiryDate']),
      lifecycle: serializer.fromJson<String>(json['lifecycle']),
      createdAtUtc: serializer.fromJson<int>(json['createdAtUtc']),
      updatedAtUtc: serializer.fromJson<int>(json['updatedAtUtc']),
      sourceDeviceId: serializer.fromJson<String>(json['sourceDeviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'customerId': serializer.toJson<String>(customerId),
      'amountCents': serializer.toJson<int>(amountCents),
      'bankName': serializer.toJson<String>(bankName),
      'interestRateScaled': serializer.toJson<int>(interestRateScaled),
      'ratePrecision': serializer.toJson<int>(ratePrecision),
      'startDate': serializer.toJson<String>(startDate),
      'calculatedExpiryDate': serializer.toJson<String?>(calculatedExpiryDate),
      'finalExpiryDate': serializer.toJson<String>(finalExpiryDate),
      'lifecycle': serializer.toJson<String>(lifecycle),
      'createdAtUtc': serializer.toJson<int>(createdAtUtc),
      'updatedAtUtc': serializer.toJson<int>(updatedAtUtc),
      'sourceDeviceId': serializer.toJson<String>(sourceDeviceId),
    };
  }

  Deposit copyWith({
    String? id,
    String? customerId,
    int? amountCents,
    String? bankName,
    int? interestRateScaled,
    int? ratePrecision,
    String? startDate,
    Value<String?> calculatedExpiryDate = const Value.absent(),
    String? finalExpiryDate,
    String? lifecycle,
    int? createdAtUtc,
    int? updatedAtUtc,
    String? sourceDeviceId,
  }) => Deposit(
    id: id ?? this.id,
    customerId: customerId ?? this.customerId,
    amountCents: amountCents ?? this.amountCents,
    bankName: bankName ?? this.bankName,
    interestRateScaled: interestRateScaled ?? this.interestRateScaled,
    ratePrecision: ratePrecision ?? this.ratePrecision,
    startDate: startDate ?? this.startDate,
    calculatedExpiryDate: calculatedExpiryDate.present
        ? calculatedExpiryDate.value
        : this.calculatedExpiryDate,
    finalExpiryDate: finalExpiryDate ?? this.finalExpiryDate,
    lifecycle: lifecycle ?? this.lifecycle,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    sourceDeviceId: sourceDeviceId ?? this.sourceDeviceId,
  );
  Deposit copyWithCompanion(DepositsCompanion data) {
    return Deposit(
      id: data.id.present ? data.id.value : this.id,
      customerId: data.customerId.present
          ? data.customerId.value
          : this.customerId,
      amountCents: data.amountCents.present
          ? data.amountCents.value
          : this.amountCents,
      bankName: data.bankName.present ? data.bankName.value : this.bankName,
      interestRateScaled: data.interestRateScaled.present
          ? data.interestRateScaled.value
          : this.interestRateScaled,
      ratePrecision: data.ratePrecision.present
          ? data.ratePrecision.value
          : this.ratePrecision,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      calculatedExpiryDate: data.calculatedExpiryDate.present
          ? data.calculatedExpiryDate.value
          : this.calculatedExpiryDate,
      finalExpiryDate: data.finalExpiryDate.present
          ? data.finalExpiryDate.value
          : this.finalExpiryDate,
      lifecycle: data.lifecycle.present ? data.lifecycle.value : this.lifecycle,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
      sourceDeviceId: data.sourceDeviceId.present
          ? data.sourceDeviceId.value
          : this.sourceDeviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Deposit(')
          ..write('id: $id, ')
          ..write('customerId: $customerId, ')
          ..write('amountCents: $amountCents, ')
          ..write('bankName: $bankName, ')
          ..write('interestRateScaled: $interestRateScaled, ')
          ..write('ratePrecision: $ratePrecision, ')
          ..write('startDate: $startDate, ')
          ..write('calculatedExpiryDate: $calculatedExpiryDate, ')
          ..write('finalExpiryDate: $finalExpiryDate, ')
          ..write('lifecycle: $lifecycle, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('sourceDeviceId: $sourceDeviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    customerId,
    amountCents,
    bankName,
    interestRateScaled,
    ratePrecision,
    startDate,
    calculatedExpiryDate,
    finalExpiryDate,
    lifecycle,
    createdAtUtc,
    updatedAtUtc,
    sourceDeviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Deposit &&
          other.id == this.id &&
          other.customerId == this.customerId &&
          other.amountCents == this.amountCents &&
          other.bankName == this.bankName &&
          other.interestRateScaled == this.interestRateScaled &&
          other.ratePrecision == this.ratePrecision &&
          other.startDate == this.startDate &&
          other.calculatedExpiryDate == this.calculatedExpiryDate &&
          other.finalExpiryDate == this.finalExpiryDate &&
          other.lifecycle == this.lifecycle &&
          other.createdAtUtc == this.createdAtUtc &&
          other.updatedAtUtc == this.updatedAtUtc &&
          other.sourceDeviceId == this.sourceDeviceId);
}

class DepositsCompanion extends UpdateCompanion<Deposit> {
  final Value<String> id;
  final Value<String> customerId;
  final Value<int> amountCents;
  final Value<String> bankName;
  final Value<int> interestRateScaled;
  final Value<int> ratePrecision;
  final Value<String> startDate;
  final Value<String?> calculatedExpiryDate;
  final Value<String> finalExpiryDate;
  final Value<String> lifecycle;
  final Value<int> createdAtUtc;
  final Value<int> updatedAtUtc;
  final Value<String> sourceDeviceId;
  final Value<int> rowid;
  const DepositsCompanion({
    this.id = const Value.absent(),
    this.customerId = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.bankName = const Value.absent(),
    this.interestRateScaled = const Value.absent(),
    this.ratePrecision = const Value.absent(),
    this.startDate = const Value.absent(),
    this.calculatedExpiryDate = const Value.absent(),
    this.finalExpiryDate = const Value.absent(),
    this.lifecycle = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.sourceDeviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DepositsCompanion.insert({
    required String id,
    required String customerId,
    required int amountCents,
    this.bankName = const Value.absent(),
    required int interestRateScaled,
    required int ratePrecision,
    required String startDate,
    this.calculatedExpiryDate = const Value.absent(),
    required String finalExpiryDate,
    required String lifecycle,
    required int createdAtUtc,
    required int updatedAtUtc,
    required String sourceDeviceId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       customerId = Value(customerId),
       amountCents = Value(amountCents),
       interestRateScaled = Value(interestRateScaled),
       ratePrecision = Value(ratePrecision),
       startDate = Value(startDate),
       finalExpiryDate = Value(finalExpiryDate),
       lifecycle = Value(lifecycle),
       createdAtUtc = Value(createdAtUtc),
       updatedAtUtc = Value(updatedAtUtc),
       sourceDeviceId = Value(sourceDeviceId);
  static Insertable<Deposit> custom({
    Expression<String>? id,
    Expression<String>? customerId,
    Expression<int>? amountCents,
    Expression<String>? bankName,
    Expression<int>? interestRateScaled,
    Expression<int>? ratePrecision,
    Expression<String>? startDate,
    Expression<String>? calculatedExpiryDate,
    Expression<String>? finalExpiryDate,
    Expression<String>? lifecycle,
    Expression<int>? createdAtUtc,
    Expression<int>? updatedAtUtc,
    Expression<String>? sourceDeviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (customerId != null) 'customer_id': customerId,
      if (amountCents != null) 'amount_cents': amountCents,
      if (bankName != null) 'bank_name': bankName,
      if (interestRateScaled != null)
        'interest_rate_scaled': interestRateScaled,
      if (ratePrecision != null) 'rate_precision': ratePrecision,
      if (startDate != null) 'start_date': startDate,
      if (calculatedExpiryDate != null)
        'calculated_expiry_date': calculatedExpiryDate,
      if (finalExpiryDate != null) 'final_expiry_date': finalExpiryDate,
      if (lifecycle != null) 'lifecycle': lifecycle,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (sourceDeviceId != null) 'source_device_id': sourceDeviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DepositsCompanion copyWith({
    Value<String>? id,
    Value<String>? customerId,
    Value<int>? amountCents,
    Value<String>? bankName,
    Value<int>? interestRateScaled,
    Value<int>? ratePrecision,
    Value<String>? startDate,
    Value<String?>? calculatedExpiryDate,
    Value<String>? finalExpiryDate,
    Value<String>? lifecycle,
    Value<int>? createdAtUtc,
    Value<int>? updatedAtUtc,
    Value<String>? sourceDeviceId,
    Value<int>? rowid,
  }) {
    return DepositsCompanion(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      amountCents: amountCents ?? this.amountCents,
      bankName: bankName ?? this.bankName,
      interestRateScaled: interestRateScaled ?? this.interestRateScaled,
      ratePrecision: ratePrecision ?? this.ratePrecision,
      startDate: startDate ?? this.startDate,
      calculatedExpiryDate: calculatedExpiryDate ?? this.calculatedExpiryDate,
      finalExpiryDate: finalExpiryDate ?? this.finalExpiryDate,
      lifecycle: lifecycle ?? this.lifecycle,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      sourceDeviceId: sourceDeviceId ?? this.sourceDeviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (bankName.present) {
      map['bank_name'] = Variable<String>(bankName.value);
    }
    if (interestRateScaled.present) {
      map['interest_rate_scaled'] = Variable<int>(interestRateScaled.value);
    }
    if (ratePrecision.present) {
      map['rate_precision'] = Variable<int>(ratePrecision.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<String>(startDate.value);
    }
    if (calculatedExpiryDate.present) {
      map['calculated_expiry_date'] = Variable<String>(
        calculatedExpiryDate.value,
      );
    }
    if (finalExpiryDate.present) {
      map['final_expiry_date'] = Variable<String>(finalExpiryDate.value);
    }
    if (lifecycle.present) {
      map['lifecycle'] = Variable<String>(lifecycle.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>(createdAtUtc.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<int>(updatedAtUtc.value);
    }
    if (sourceDeviceId.present) {
      map['source_device_id'] = Variable<String>(sourceDeviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DepositsCompanion(')
          ..write('id: $id, ')
          ..write('customerId: $customerId, ')
          ..write('amountCents: $amountCents, ')
          ..write('bankName: $bankName, ')
          ..write('interestRateScaled: $interestRateScaled, ')
          ..write('ratePrecision: $ratePrecision, ')
          ..write('startDate: $startDate, ')
          ..write('calculatedExpiryDate: $calculatedExpiryDate, ')
          ..write('finalExpiryDate: $finalExpiryDate, ')
          ..write('lifecycle: $lifecycle, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('sourceDeviceId: $sourceDeviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RenewalsTable extends Renewals with TableInfo<$RenewalsTable, Renewal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RenewalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceDepositIdMeta = const VerificationMeta(
    'sourceDepositId',
  );
  @override
  late final GeneratedColumn<String> sourceDepositId = GeneratedColumn<String>(
    'source_deposit_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'UNIQUE REFERENCES deposits (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _targetDepositIdMeta = const VerificationMeta(
    'targetDepositId',
  );
  @override
  late final GeneratedColumn<String> targetDepositId = GeneratedColumn<String>(
    'target_deposit_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'UNIQUE REFERENCES deposits (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _renewedAtUtcMeta = const VerificationMeta(
    'renewedAtUtc',
  );
  @override
  late final GeneratedColumn<int> renewedAtUtc = GeneratedColumn<int>(
    'renewed_at_utc',
    aliasedName,
    false,
    check: () => utcEpochCheck('renewed_at_utc'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceDeviceIdMeta = const VerificationMeta(
    'sourceDeviceId',
  );
  @override
  late final GeneratedColumn<String> sourceDeviceId = GeneratedColumn<String>(
    'source_device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceDepositId,
    targetDepositId,
    renewedAtUtc,
    sourceDeviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'renewals';
  @override
  VerificationContext validateIntegrity(
    Insertable<Renewal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_deposit_id')) {
      context.handle(
        _sourceDepositIdMeta,
        sourceDepositId.isAcceptableOrUnknown(
          data['source_deposit_id']!,
          _sourceDepositIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceDepositIdMeta);
    }
    if (data.containsKey('target_deposit_id')) {
      context.handle(
        _targetDepositIdMeta,
        targetDepositId.isAcceptableOrUnknown(
          data['target_deposit_id']!,
          _targetDepositIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetDepositIdMeta);
    }
    if (data.containsKey('renewed_at_utc')) {
      context.handle(
        _renewedAtUtcMeta,
        renewedAtUtc.isAcceptableOrUnknown(
          data['renewed_at_utc']!,
          _renewedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_renewedAtUtcMeta);
    }
    if (data.containsKey('source_device_id')) {
      context.handle(
        _sourceDeviceIdMeta,
        sourceDeviceId.isAcceptableOrUnknown(
          data['source_device_id']!,
          _sourceDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceDeviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Renewal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Renewal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sourceDepositId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_deposit_id'],
      )!,
      targetDepositId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_deposit_id'],
      )!,
      renewedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}renewed_at_utc'],
      )!,
      sourceDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_device_id'],
      )!,
    );
  }

  @override
  $RenewalsTable createAlias(String alias) {
    return $RenewalsTable(attachedDatabase, alias);
  }
}

class Renewal extends DataClass implements Insertable<Renewal> {
  final String id;
  final String sourceDepositId;
  final String targetDepositId;
  final int renewedAtUtc;
  final String sourceDeviceId;
  const Renewal({
    required this.id,
    required this.sourceDepositId,
    required this.targetDepositId,
    required this.renewedAtUtc,
    required this.sourceDeviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source_deposit_id'] = Variable<String>(sourceDepositId);
    map['target_deposit_id'] = Variable<String>(targetDepositId);
    map['renewed_at_utc'] = Variable<int>(renewedAtUtc);
    map['source_device_id'] = Variable<String>(sourceDeviceId);
    return map;
  }

  RenewalsCompanion toCompanion(bool nullToAbsent) {
    return RenewalsCompanion(
      id: Value(id),
      sourceDepositId: Value(sourceDepositId),
      targetDepositId: Value(targetDepositId),
      renewedAtUtc: Value(renewedAtUtc),
      sourceDeviceId: Value(sourceDeviceId),
    );
  }

  factory Renewal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Renewal(
      id: serializer.fromJson<String>(json['id']),
      sourceDepositId: serializer.fromJson<String>(json['sourceDepositId']),
      targetDepositId: serializer.fromJson<String>(json['targetDepositId']),
      renewedAtUtc: serializer.fromJson<int>(json['renewedAtUtc']),
      sourceDeviceId: serializer.fromJson<String>(json['sourceDeviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourceDepositId': serializer.toJson<String>(sourceDepositId),
      'targetDepositId': serializer.toJson<String>(targetDepositId),
      'renewedAtUtc': serializer.toJson<int>(renewedAtUtc),
      'sourceDeviceId': serializer.toJson<String>(sourceDeviceId),
    };
  }

  Renewal copyWith({
    String? id,
    String? sourceDepositId,
    String? targetDepositId,
    int? renewedAtUtc,
    String? sourceDeviceId,
  }) => Renewal(
    id: id ?? this.id,
    sourceDepositId: sourceDepositId ?? this.sourceDepositId,
    targetDepositId: targetDepositId ?? this.targetDepositId,
    renewedAtUtc: renewedAtUtc ?? this.renewedAtUtc,
    sourceDeviceId: sourceDeviceId ?? this.sourceDeviceId,
  );
  Renewal copyWithCompanion(RenewalsCompanion data) {
    return Renewal(
      id: data.id.present ? data.id.value : this.id,
      sourceDepositId: data.sourceDepositId.present
          ? data.sourceDepositId.value
          : this.sourceDepositId,
      targetDepositId: data.targetDepositId.present
          ? data.targetDepositId.value
          : this.targetDepositId,
      renewedAtUtc: data.renewedAtUtc.present
          ? data.renewedAtUtc.value
          : this.renewedAtUtc,
      sourceDeviceId: data.sourceDeviceId.present
          ? data.sourceDeviceId.value
          : this.sourceDeviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Renewal(')
          ..write('id: $id, ')
          ..write('sourceDepositId: $sourceDepositId, ')
          ..write('targetDepositId: $targetDepositId, ')
          ..write('renewedAtUtc: $renewedAtUtc, ')
          ..write('sourceDeviceId: $sourceDeviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceDepositId,
    targetDepositId,
    renewedAtUtc,
    sourceDeviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Renewal &&
          other.id == this.id &&
          other.sourceDepositId == this.sourceDepositId &&
          other.targetDepositId == this.targetDepositId &&
          other.renewedAtUtc == this.renewedAtUtc &&
          other.sourceDeviceId == this.sourceDeviceId);
}

class RenewalsCompanion extends UpdateCompanion<Renewal> {
  final Value<String> id;
  final Value<String> sourceDepositId;
  final Value<String> targetDepositId;
  final Value<int> renewedAtUtc;
  final Value<String> sourceDeviceId;
  final Value<int> rowid;
  const RenewalsCompanion({
    this.id = const Value.absent(),
    this.sourceDepositId = const Value.absent(),
    this.targetDepositId = const Value.absent(),
    this.renewedAtUtc = const Value.absent(),
    this.sourceDeviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RenewalsCompanion.insert({
    required String id,
    required String sourceDepositId,
    required String targetDepositId,
    required int renewedAtUtc,
    required String sourceDeviceId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sourceDepositId = Value(sourceDepositId),
       targetDepositId = Value(targetDepositId),
       renewedAtUtc = Value(renewedAtUtc),
       sourceDeviceId = Value(sourceDeviceId);
  static Insertable<Renewal> custom({
    Expression<String>? id,
    Expression<String>? sourceDepositId,
    Expression<String>? targetDepositId,
    Expression<int>? renewedAtUtc,
    Expression<String>? sourceDeviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceDepositId != null) 'source_deposit_id': sourceDepositId,
      if (targetDepositId != null) 'target_deposit_id': targetDepositId,
      if (renewedAtUtc != null) 'renewed_at_utc': renewedAtUtc,
      if (sourceDeviceId != null) 'source_device_id': sourceDeviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RenewalsCompanion copyWith({
    Value<String>? id,
    Value<String>? sourceDepositId,
    Value<String>? targetDepositId,
    Value<int>? renewedAtUtc,
    Value<String>? sourceDeviceId,
    Value<int>? rowid,
  }) {
    return RenewalsCompanion(
      id: id ?? this.id,
      sourceDepositId: sourceDepositId ?? this.sourceDepositId,
      targetDepositId: targetDepositId ?? this.targetDepositId,
      renewedAtUtc: renewedAtUtc ?? this.renewedAtUtc,
      sourceDeviceId: sourceDeviceId ?? this.sourceDeviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourceDepositId.present) {
      map['source_deposit_id'] = Variable<String>(sourceDepositId.value);
    }
    if (targetDepositId.present) {
      map['target_deposit_id'] = Variable<String>(targetDepositId.value);
    }
    if (renewedAtUtc.present) {
      map['renewed_at_utc'] = Variable<int>(renewedAtUtc.value);
    }
    if (sourceDeviceId.present) {
      map['source_device_id'] = Variable<String>(sourceDeviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RenewalsCompanion(')
          ..write('id: $id, ')
          ..write('sourceDepositId: $sourceDepositId, ')
          ..write('targetDepositId: $targetDepositId, ')
          ..write('renewedAtUtc: $renewedAtUtc, ')
          ..write('sourceDeviceId: $sourceDeviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AuditHistoryTable extends AuditHistory
    with TableInfo<$AuditHistoryTable, AuditHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AuditHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _beforeJsonMeta = const VerificationMeta(
    'beforeJson',
  );
  @override
  late final GeneratedColumn<String> beforeJson = GeneratedColumn<String>(
    'before_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _afterJsonMeta = const VerificationMeta(
    'afterJson',
  );
  @override
  late final GeneratedColumn<String> afterJson = GeneratedColumn<String>(
    'after_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtUtcMeta = const VerificationMeta(
    'occurredAtUtc',
  );
  @override
  late final GeneratedColumn<int> occurredAtUtc = GeneratedColumn<int>(
    'occurred_at_utc',
    aliasedName,
    false,
    check: () => utcEpochCheck('occurred_at_utc'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceDeviceIdMeta = const VerificationMeta(
    'sourceDeviceId',
  );
  @override
  late final GeneratedColumn<String> sourceDeviceId = GeneratedColumn<String>(
    'source_device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _businessRevisionMeta = const VerificationMeta(
    'businessRevision',
  );
  @override
  late final GeneratedColumn<int> businessRevision = GeneratedColumn<int>(
    'business_revision',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('business_revision > 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entityType,
    entityId,
    operation,
    beforeJson,
    afterJson,
    occurredAtUtc,
    sourceDeviceId,
    businessRevision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audit_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<AuditHistoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('before_json')) {
      context.handle(
        _beforeJsonMeta,
        beforeJson.isAcceptableOrUnknown(data['before_json']!, _beforeJsonMeta),
      );
    }
    if (data.containsKey('after_json')) {
      context.handle(
        _afterJsonMeta,
        afterJson.isAcceptableOrUnknown(data['after_json']!, _afterJsonMeta),
      );
    }
    if (data.containsKey('occurred_at_utc')) {
      context.handle(
        _occurredAtUtcMeta,
        occurredAtUtc.isAcceptableOrUnknown(
          data['occurred_at_utc']!,
          _occurredAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_occurredAtUtcMeta);
    }
    if (data.containsKey('source_device_id')) {
      context.handle(
        _sourceDeviceIdMeta,
        sourceDeviceId.isAcceptableOrUnknown(
          data['source_device_id']!,
          _sourceDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceDeviceIdMeta);
    }
    if (data.containsKey('business_revision')) {
      context.handle(
        _businessRevisionMeta,
        businessRevision.isAcceptableOrUnknown(
          data['business_revision']!,
          _businessRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_businessRevisionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AuditHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AuditHistoryData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      beforeJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}before_json'],
      ),
      afterJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}after_json'],
      ),
      occurredAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}occurred_at_utc'],
      )!,
      sourceDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_device_id'],
      )!,
      businessRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}business_revision'],
      )!,
    );
  }

  @override
  $AuditHistoryTable createAlias(String alias) {
    return $AuditHistoryTable(attachedDatabase, alias);
  }
}

class AuditHistoryData extends DataClass
    implements Insertable<AuditHistoryData> {
  final String id;
  final String entityType;
  final String entityId;
  final String operation;
  final String? beforeJson;
  final String? afterJson;
  final int occurredAtUtc;
  final String sourceDeviceId;
  final int businessRevision;
  const AuditHistoryData({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    this.beforeJson,
    this.afterJson,
    required this.occurredAtUtc,
    required this.sourceDeviceId,
    required this.businessRevision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['operation'] = Variable<String>(operation);
    if (!nullToAbsent || beforeJson != null) {
      map['before_json'] = Variable<String>(beforeJson);
    }
    if (!nullToAbsent || afterJson != null) {
      map['after_json'] = Variable<String>(afterJson);
    }
    map['occurred_at_utc'] = Variable<int>(occurredAtUtc);
    map['source_device_id'] = Variable<String>(sourceDeviceId);
    map['business_revision'] = Variable<int>(businessRevision);
    return map;
  }

  AuditHistoryCompanion toCompanion(bool nullToAbsent) {
    return AuditHistoryCompanion(
      id: Value(id),
      entityType: Value(entityType),
      entityId: Value(entityId),
      operation: Value(operation),
      beforeJson: beforeJson == null && nullToAbsent
          ? const Value.absent()
          : Value(beforeJson),
      afterJson: afterJson == null && nullToAbsent
          ? const Value.absent()
          : Value(afterJson),
      occurredAtUtc: Value(occurredAtUtc),
      sourceDeviceId: Value(sourceDeviceId),
      businessRevision: Value(businessRevision),
    );
  }

  factory AuditHistoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AuditHistoryData(
      id: serializer.fromJson<String>(json['id']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      operation: serializer.fromJson<String>(json['operation']),
      beforeJson: serializer.fromJson<String?>(json['beforeJson']),
      afterJson: serializer.fromJson<String?>(json['afterJson']),
      occurredAtUtc: serializer.fromJson<int>(json['occurredAtUtc']),
      sourceDeviceId: serializer.fromJson<String>(json['sourceDeviceId']),
      businessRevision: serializer.fromJson<int>(json['businessRevision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'operation': serializer.toJson<String>(operation),
      'beforeJson': serializer.toJson<String?>(beforeJson),
      'afterJson': serializer.toJson<String?>(afterJson),
      'occurredAtUtc': serializer.toJson<int>(occurredAtUtc),
      'sourceDeviceId': serializer.toJson<String>(sourceDeviceId),
      'businessRevision': serializer.toJson<int>(businessRevision),
    };
  }

  AuditHistoryData copyWith({
    String? id,
    String? entityType,
    String? entityId,
    String? operation,
    Value<String?> beforeJson = const Value.absent(),
    Value<String?> afterJson = const Value.absent(),
    int? occurredAtUtc,
    String? sourceDeviceId,
    int? businessRevision,
  }) => AuditHistoryData(
    id: id ?? this.id,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    operation: operation ?? this.operation,
    beforeJson: beforeJson.present ? beforeJson.value : this.beforeJson,
    afterJson: afterJson.present ? afterJson.value : this.afterJson,
    occurredAtUtc: occurredAtUtc ?? this.occurredAtUtc,
    sourceDeviceId: sourceDeviceId ?? this.sourceDeviceId,
    businessRevision: businessRevision ?? this.businessRevision,
  );
  AuditHistoryData copyWithCompanion(AuditHistoryCompanion data) {
    return AuditHistoryData(
      id: data.id.present ? data.id.value : this.id,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      operation: data.operation.present ? data.operation.value : this.operation,
      beforeJson: data.beforeJson.present
          ? data.beforeJson.value
          : this.beforeJson,
      afterJson: data.afterJson.present ? data.afterJson.value : this.afterJson,
      occurredAtUtc: data.occurredAtUtc.present
          ? data.occurredAtUtc.value
          : this.occurredAtUtc,
      sourceDeviceId: data.sourceDeviceId.present
          ? data.sourceDeviceId.value
          : this.sourceDeviceId,
      businessRevision: data.businessRevision.present
          ? data.businessRevision.value
          : this.businessRevision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AuditHistoryData(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('beforeJson: $beforeJson, ')
          ..write('afterJson: $afterJson, ')
          ..write('occurredAtUtc: $occurredAtUtc, ')
          ..write('sourceDeviceId: $sourceDeviceId, ')
          ..write('businessRevision: $businessRevision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entityType,
    entityId,
    operation,
    beforeJson,
    afterJson,
    occurredAtUtc,
    sourceDeviceId,
    businessRevision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuditHistoryData &&
          other.id == this.id &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.operation == this.operation &&
          other.beforeJson == this.beforeJson &&
          other.afterJson == this.afterJson &&
          other.occurredAtUtc == this.occurredAtUtc &&
          other.sourceDeviceId == this.sourceDeviceId &&
          other.businessRevision == this.businessRevision);
}

class AuditHistoryCompanion extends UpdateCompanion<AuditHistoryData> {
  final Value<String> id;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> operation;
  final Value<String?> beforeJson;
  final Value<String?> afterJson;
  final Value<int> occurredAtUtc;
  final Value<String> sourceDeviceId;
  final Value<int> businessRevision;
  final Value<int> rowid;
  const AuditHistoryCompanion({
    this.id = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.operation = const Value.absent(),
    this.beforeJson = const Value.absent(),
    this.afterJson = const Value.absent(),
    this.occurredAtUtc = const Value.absent(),
    this.sourceDeviceId = const Value.absent(),
    this.businessRevision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AuditHistoryCompanion.insert({
    required String id,
    required String entityType,
    required String entityId,
    required String operation,
    this.beforeJson = const Value.absent(),
    this.afterJson = const Value.absent(),
    required int occurredAtUtc,
    required String sourceDeviceId,
    required int businessRevision,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       entityType = Value(entityType),
       entityId = Value(entityId),
       operation = Value(operation),
       occurredAtUtc = Value(occurredAtUtc),
       sourceDeviceId = Value(sourceDeviceId),
       businessRevision = Value(businessRevision);
  static Insertable<AuditHistoryData> custom({
    Expression<String>? id,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? operation,
    Expression<String>? beforeJson,
    Expression<String>? afterJson,
    Expression<int>? occurredAtUtc,
    Expression<String>? sourceDeviceId,
    Expression<int>? businessRevision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (operation != null) 'operation': operation,
      if (beforeJson != null) 'before_json': beforeJson,
      if (afterJson != null) 'after_json': afterJson,
      if (occurredAtUtc != null) 'occurred_at_utc': occurredAtUtc,
      if (sourceDeviceId != null) 'source_device_id': sourceDeviceId,
      if (businessRevision != null) 'business_revision': businessRevision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AuditHistoryCompanion copyWith({
    Value<String>? id,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? operation,
    Value<String?>? beforeJson,
    Value<String?>? afterJson,
    Value<int>? occurredAtUtc,
    Value<String>? sourceDeviceId,
    Value<int>? businessRevision,
    Value<int>? rowid,
  }) {
    return AuditHistoryCompanion(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      beforeJson: beforeJson ?? this.beforeJson,
      afterJson: afterJson ?? this.afterJson,
      occurredAtUtc: occurredAtUtc ?? this.occurredAtUtc,
      sourceDeviceId: sourceDeviceId ?? this.sourceDeviceId,
      businessRevision: businessRevision ?? this.businessRevision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (beforeJson.present) {
      map['before_json'] = Variable<String>(beforeJson.value);
    }
    if (afterJson.present) {
      map['after_json'] = Variable<String>(afterJson.value);
    }
    if (occurredAtUtc.present) {
      map['occurred_at_utc'] = Variable<int>(occurredAtUtc.value);
    }
    if (sourceDeviceId.present) {
      map['source_device_id'] = Variable<String>(sourceDeviceId.value);
    }
    if (businessRevision.present) {
      map['business_revision'] = Variable<int>(businessRevision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuditHistoryCompanion(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('beforeJson: $beforeJson, ')
          ..write('afterJson: $afterJson, ')
          ..write('occurredAtUtc: $occurredAtUtc, ')
          ..write('sourceDeviceId: $sourceDeviceId, ')
          ..write('businessRevision: $businessRevision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessageTemplatesTable extends MessageTemplates
    with TableInfo<$MessageTemplatesTable, MessageTemplate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessageTemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<int> createdAtUtc = GeneratedColumn<int>(
    'created_at_utc',
    aliasedName,
    false,
    check: () => utcEpochCheck('created_at_utc'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<int> updatedAtUtc = GeneratedColumn<int>(
    'updated_at_utc',
    aliasedName,
    false,
    check: () => utcEpochCheck('updated_at_utc'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    content,
    isActive,
    createdAtUtc,
    updatedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'message_templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessageTemplate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MessageTemplate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageTemplate(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc'],
      )!,
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_utc'],
      )!,
    );
  }

  @override
  $MessageTemplatesTable createAlias(String alias) {
    return $MessageTemplatesTable(attachedDatabase, alias);
  }
}

class MessageTemplate extends DataClass implements Insertable<MessageTemplate> {
  final String id;
  final String name;
  final String content;
  final bool isActive;
  final int createdAtUtc;
  final int updatedAtUtc;
  const MessageTemplate({
    required this.id,
    required this.name,
    required this.content,
    required this.isActive,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['content'] = Variable<String>(content);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at_utc'] = Variable<int>(createdAtUtc);
    map['updated_at_utc'] = Variable<int>(updatedAtUtc);
    return map;
  }

  MessageTemplatesCompanion toCompanion(bool nullToAbsent) {
    return MessageTemplatesCompanion(
      id: Value(id),
      name: Value(name),
      content: Value(content),
      isActive: Value(isActive),
      createdAtUtc: Value(createdAtUtc),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory MessageTemplate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageTemplate(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      content: serializer.fromJson<String>(json['content']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAtUtc: serializer.fromJson<int>(json['createdAtUtc']),
      updatedAtUtc: serializer.fromJson<int>(json['updatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'content': serializer.toJson<String>(content),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAtUtc': serializer.toJson<int>(createdAtUtc),
      'updatedAtUtc': serializer.toJson<int>(updatedAtUtc),
    };
  }

  MessageTemplate copyWith({
    String? id,
    String? name,
    String? content,
    bool? isActive,
    int? createdAtUtc,
    int? updatedAtUtc,
  }) => MessageTemplate(
    id: id ?? this.id,
    name: name ?? this.name,
    content: content ?? this.content,
    isActive: isActive ?? this.isActive,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
  MessageTemplate copyWithCompanion(MessageTemplatesCompanion data) {
    return MessageTemplate(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      content: data.content.present ? data.content.value : this.content,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageTemplate(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('content: $content, ')
          ..write('isActive: $isActive, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, content, isActive, createdAtUtc, updatedAtUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageTemplate &&
          other.id == this.id &&
          other.name == this.name &&
          other.content == this.content &&
          other.isActive == this.isActive &&
          other.createdAtUtc == this.createdAtUtc &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class MessageTemplatesCompanion extends UpdateCompanion<MessageTemplate> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> content;
  final Value<bool> isActive;
  final Value<int> createdAtUtc;
  final Value<int> updatedAtUtc;
  final Value<int> rowid;
  const MessageTemplatesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.content = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessageTemplatesCompanion.insert({
    required String id,
    required String name,
    required String content,
    this.isActive = const Value.absent(),
    required int createdAtUtc,
    required int updatedAtUtc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       content = Value(content),
       createdAtUtc = Value(createdAtUtc),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<MessageTemplate> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? content,
    Expression<bool>? isActive,
    Expression<int>? createdAtUtc,
    Expression<int>? updatedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (content != null) 'content': content,
      if (isActive != null) 'is_active': isActive,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessageTemplatesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? content,
    Value<bool>? isActive,
    Value<int>? createdAtUtc,
    Value<int>? updatedAtUtc,
    Value<int>? rowid,
  }) {
    return MessageTemplatesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      content: content ?? this.content,
      isActive: isActive ?? this.isActive,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>(createdAtUtc.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<int>(updatedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessageTemplatesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('content: $content, ')
          ..write('isActive: $isActive, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ImportBatchesTable extends ImportBatches
    with TableInfo<$ImportBatchesTable, ImportBatche> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImportBatchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importedRowsMeta = const VerificationMeta(
    'importedRows',
  );
  @override
  late final GeneratedColumn<int> importedRows = GeneratedColumn<int>(
    'imported_rows',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _rejectedRowsMeta = const VerificationMeta(
    'rejectedRows',
  );
  @override
  late final GeneratedColumn<int> rejectedRows = GeneratedColumn<int>(
    'rejected_rows',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _importedAtUtcMeta = const VerificationMeta(
    'importedAtUtc',
  );
  @override
  late final GeneratedColumn<int> importedAtUtc = GeneratedColumn<int>(
    'imported_at_utc',
    aliasedName,
    false,
    check: () => utcEpochCheck('imported_at_utc'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceDeviceIdMeta = const VerificationMeta(
    'sourceDeviceId',
  );
  @override
  late final GeneratedColumn<String> sourceDeviceId = GeneratedColumn<String>(
    'source_device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fileName,
    contentHash,
    importedRows,
    rejectedRows,
    importedAtUtc,
    sourceDeviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'import_batches';
  @override
  VerificationContext validateIntegrity(
    Insertable<ImportBatche> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentHashMeta);
    }
    if (data.containsKey('imported_rows')) {
      context.handle(
        _importedRowsMeta,
        importedRows.isAcceptableOrUnknown(
          data['imported_rows']!,
          _importedRowsMeta,
        ),
      );
    }
    if (data.containsKey('rejected_rows')) {
      context.handle(
        _rejectedRowsMeta,
        rejectedRows.isAcceptableOrUnknown(
          data['rejected_rows']!,
          _rejectedRowsMeta,
        ),
      );
    }
    if (data.containsKey('imported_at_utc')) {
      context.handle(
        _importedAtUtcMeta,
        importedAtUtc.isAcceptableOrUnknown(
          data['imported_at_utc']!,
          _importedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_importedAtUtcMeta);
    }
    if (data.containsKey('source_device_id')) {
      context.handle(
        _sourceDeviceIdMeta,
        sourceDeviceId.isAcceptableOrUnknown(
          data['source_device_id']!,
          _sourceDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceDeviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ImportBatche map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImportBatche(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
      importedRows: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}imported_rows'],
      )!,
      rejectedRows: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rejected_rows'],
      )!,
      importedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}imported_at_utc'],
      )!,
      sourceDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_device_id'],
      )!,
    );
  }

  @override
  $ImportBatchesTable createAlias(String alias) {
    return $ImportBatchesTable(attachedDatabase, alias);
  }
}

class ImportBatche extends DataClass implements Insertable<ImportBatche> {
  final String id;
  final String fileName;
  final String contentHash;
  final int importedRows;
  final int rejectedRows;
  final int importedAtUtc;
  final String sourceDeviceId;
  const ImportBatche({
    required this.id,
    required this.fileName,
    required this.contentHash,
    required this.importedRows,
    required this.rejectedRows,
    required this.importedAtUtc,
    required this.sourceDeviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['file_name'] = Variable<String>(fileName);
    map['content_hash'] = Variable<String>(contentHash);
    map['imported_rows'] = Variable<int>(importedRows);
    map['rejected_rows'] = Variable<int>(rejectedRows);
    map['imported_at_utc'] = Variable<int>(importedAtUtc);
    map['source_device_id'] = Variable<String>(sourceDeviceId);
    return map;
  }

  ImportBatchesCompanion toCompanion(bool nullToAbsent) {
    return ImportBatchesCompanion(
      id: Value(id),
      fileName: Value(fileName),
      contentHash: Value(contentHash),
      importedRows: Value(importedRows),
      rejectedRows: Value(rejectedRows),
      importedAtUtc: Value(importedAtUtc),
      sourceDeviceId: Value(sourceDeviceId),
    );
  }

  factory ImportBatche.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImportBatche(
      id: serializer.fromJson<String>(json['id']),
      fileName: serializer.fromJson<String>(json['fileName']),
      contentHash: serializer.fromJson<String>(json['contentHash']),
      importedRows: serializer.fromJson<int>(json['importedRows']),
      rejectedRows: serializer.fromJson<int>(json['rejectedRows']),
      importedAtUtc: serializer.fromJson<int>(json['importedAtUtc']),
      sourceDeviceId: serializer.fromJson<String>(json['sourceDeviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'fileName': serializer.toJson<String>(fileName),
      'contentHash': serializer.toJson<String>(contentHash),
      'importedRows': serializer.toJson<int>(importedRows),
      'rejectedRows': serializer.toJson<int>(rejectedRows),
      'importedAtUtc': serializer.toJson<int>(importedAtUtc),
      'sourceDeviceId': serializer.toJson<String>(sourceDeviceId),
    };
  }

  ImportBatche copyWith({
    String? id,
    String? fileName,
    String? contentHash,
    int? importedRows,
    int? rejectedRows,
    int? importedAtUtc,
    String? sourceDeviceId,
  }) => ImportBatche(
    id: id ?? this.id,
    fileName: fileName ?? this.fileName,
    contentHash: contentHash ?? this.contentHash,
    importedRows: importedRows ?? this.importedRows,
    rejectedRows: rejectedRows ?? this.rejectedRows,
    importedAtUtc: importedAtUtc ?? this.importedAtUtc,
    sourceDeviceId: sourceDeviceId ?? this.sourceDeviceId,
  );
  ImportBatche copyWithCompanion(ImportBatchesCompanion data) {
    return ImportBatche(
      id: data.id.present ? data.id.value : this.id,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      importedRows: data.importedRows.present
          ? data.importedRows.value
          : this.importedRows,
      rejectedRows: data.rejectedRows.present
          ? data.rejectedRows.value
          : this.rejectedRows,
      importedAtUtc: data.importedAtUtc.present
          ? data.importedAtUtc.value
          : this.importedAtUtc,
      sourceDeviceId: data.sourceDeviceId.present
          ? data.sourceDeviceId.value
          : this.sourceDeviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImportBatche(')
          ..write('id: $id, ')
          ..write('fileName: $fileName, ')
          ..write('contentHash: $contentHash, ')
          ..write('importedRows: $importedRows, ')
          ..write('rejectedRows: $rejectedRows, ')
          ..write('importedAtUtc: $importedAtUtc, ')
          ..write('sourceDeviceId: $sourceDeviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    fileName,
    contentHash,
    importedRows,
    rejectedRows,
    importedAtUtc,
    sourceDeviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImportBatche &&
          other.id == this.id &&
          other.fileName == this.fileName &&
          other.contentHash == this.contentHash &&
          other.importedRows == this.importedRows &&
          other.rejectedRows == this.rejectedRows &&
          other.importedAtUtc == this.importedAtUtc &&
          other.sourceDeviceId == this.sourceDeviceId);
}

class ImportBatchesCompanion extends UpdateCompanion<ImportBatche> {
  final Value<String> id;
  final Value<String> fileName;
  final Value<String> contentHash;
  final Value<int> importedRows;
  final Value<int> rejectedRows;
  final Value<int> importedAtUtc;
  final Value<String> sourceDeviceId;
  final Value<int> rowid;
  const ImportBatchesCompanion({
    this.id = const Value.absent(),
    this.fileName = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.importedRows = const Value.absent(),
    this.rejectedRows = const Value.absent(),
    this.importedAtUtc = const Value.absent(),
    this.sourceDeviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ImportBatchesCompanion.insert({
    required String id,
    required String fileName,
    required String contentHash,
    this.importedRows = const Value.absent(),
    this.rejectedRows = const Value.absent(),
    required int importedAtUtc,
    required String sourceDeviceId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       fileName = Value(fileName),
       contentHash = Value(contentHash),
       importedAtUtc = Value(importedAtUtc),
       sourceDeviceId = Value(sourceDeviceId);
  static Insertable<ImportBatche> custom({
    Expression<String>? id,
    Expression<String>? fileName,
    Expression<String>? contentHash,
    Expression<int>? importedRows,
    Expression<int>? rejectedRows,
    Expression<int>? importedAtUtc,
    Expression<String>? sourceDeviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fileName != null) 'file_name': fileName,
      if (contentHash != null) 'content_hash': contentHash,
      if (importedRows != null) 'imported_rows': importedRows,
      if (rejectedRows != null) 'rejected_rows': rejectedRows,
      if (importedAtUtc != null) 'imported_at_utc': importedAtUtc,
      if (sourceDeviceId != null) 'source_device_id': sourceDeviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ImportBatchesCompanion copyWith({
    Value<String>? id,
    Value<String>? fileName,
    Value<String>? contentHash,
    Value<int>? importedRows,
    Value<int>? rejectedRows,
    Value<int>? importedAtUtc,
    Value<String>? sourceDeviceId,
    Value<int>? rowid,
  }) {
    return ImportBatchesCompanion(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      contentHash: contentHash ?? this.contentHash,
      importedRows: importedRows ?? this.importedRows,
      rejectedRows: rejectedRows ?? this.rejectedRows,
      importedAtUtc: importedAtUtc ?? this.importedAtUtc,
      sourceDeviceId: sourceDeviceId ?? this.sourceDeviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (importedRows.present) {
      map['imported_rows'] = Variable<int>(importedRows.value);
    }
    if (rejectedRows.present) {
      map['rejected_rows'] = Variable<int>(rejectedRows.value);
    }
    if (importedAtUtc.present) {
      map['imported_at_utc'] = Variable<int>(importedAtUtc.value);
    }
    if (sourceDeviceId.present) {
      map['source_device_id'] = Variable<String>(sourceDeviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImportBatchesCompanion(')
          ..write('id: $id, ')
          ..write('fileName: $fileName, ')
          ..write('contentHash: $contentHash, ')
          ..write('importedRows: $importedRows, ')
          ..write('rejectedRows: $rejectedRows, ')
          ..write('importedAtUtc: $importedAtUtc, ')
          ..write('sourceDeviceId: $sourceDeviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BusinessSettingsTable extends BusinessSettings
    with TableInfo<$BusinessSettingsTable, BusinessSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BusinessSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _singletonIdMeta = const VerificationMeta(
    'singletonId',
  );
  @override
  late final GeneratedColumn<int> singletonId = GeneratedColumn<int>(
    'singleton_id',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('singleton_id = 1'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _businessRevisionMeta = const VerificationMeta(
    'businessRevision',
  );
  @override
  late final GeneratedColumn<int> businessRevision = GeneratedColumn<int>(
    'business_revision',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('business_revision >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [singletonId, businessRevision];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'business_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<BusinessSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('singleton_id')) {
      context.handle(
        _singletonIdMeta,
        singletonId.isAcceptableOrUnknown(
          data['singleton_id']!,
          _singletonIdMeta,
        ),
      );
    }
    if (data.containsKey('business_revision')) {
      context.handle(
        _businessRevisionMeta,
        businessRevision.isAcceptableOrUnknown(
          data['business_revision']!,
          _businessRevisionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {singletonId};
  @override
  BusinessSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BusinessSetting(
      singletonId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}singleton_id'],
      )!,
      businessRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}business_revision'],
      )!,
    );
  }

  @override
  $BusinessSettingsTable createAlias(String alias) {
    return $BusinessSettingsTable(attachedDatabase, alias);
  }
}

class BusinessSetting extends DataClass implements Insertable<BusinessSetting> {
  final int singletonId;
  final int businessRevision;
  const BusinessSetting({
    required this.singletonId,
    required this.businessRevision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['singleton_id'] = Variable<int>(singletonId);
    map['business_revision'] = Variable<int>(businessRevision);
    return map;
  }

  BusinessSettingsCompanion toCompanion(bool nullToAbsent) {
    return BusinessSettingsCompanion(
      singletonId: Value(singletonId),
      businessRevision: Value(businessRevision),
    );
  }

  factory BusinessSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BusinessSetting(
      singletonId: serializer.fromJson<int>(json['singletonId']),
      businessRevision: serializer.fromJson<int>(json['businessRevision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'singletonId': serializer.toJson<int>(singletonId),
      'businessRevision': serializer.toJson<int>(businessRevision),
    };
  }

  BusinessSetting copyWith({int? singletonId, int? businessRevision}) =>
      BusinessSetting(
        singletonId: singletonId ?? this.singletonId,
        businessRevision: businessRevision ?? this.businessRevision,
      );
  BusinessSetting copyWithCompanion(BusinessSettingsCompanion data) {
    return BusinessSetting(
      singletonId: data.singletonId.present
          ? data.singletonId.value
          : this.singletonId,
      businessRevision: data.businessRevision.present
          ? data.businessRevision.value
          : this.businessRevision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BusinessSetting(')
          ..write('singletonId: $singletonId, ')
          ..write('businessRevision: $businessRevision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(singletonId, businessRevision);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BusinessSetting &&
          other.singletonId == this.singletonId &&
          other.businessRevision == this.businessRevision);
}

class BusinessSettingsCompanion extends UpdateCompanion<BusinessSetting> {
  final Value<int> singletonId;
  final Value<int> businessRevision;
  const BusinessSettingsCompanion({
    this.singletonId = const Value.absent(),
    this.businessRevision = const Value.absent(),
  });
  BusinessSettingsCompanion.insert({
    this.singletonId = const Value.absent(),
    this.businessRevision = const Value.absent(),
  });
  static Insertable<BusinessSetting> custom({
    Expression<int>? singletonId,
    Expression<int>? businessRevision,
  }) {
    return RawValuesInsertable({
      if (singletonId != null) 'singleton_id': singletonId,
      if (businessRevision != null) 'business_revision': businessRevision,
    });
  }

  BusinessSettingsCompanion copyWith({
    Value<int>? singletonId,
    Value<int>? businessRevision,
  }) {
    return BusinessSettingsCompanion(
      singletonId: singletonId ?? this.singletonId,
      businessRevision: businessRevision ?? this.businessRevision,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (singletonId.present) {
      map['singleton_id'] = Variable<int>(singletonId.value);
    }
    if (businessRevision.present) {
      map['business_revision'] = Variable<int>(businessRevision.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BusinessSettingsCompanion(')
          ..write('singletonId: $singletonId, ')
          ..write('businessRevision: $businessRevision')
          ..write(')'))
        .toString();
  }
}

class $NotificationIdMappingsTable extends NotificationIdMappings
    with TableInfo<$NotificationIdMappingsTable, NotificationIdMapping> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotificationIdMappingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notificationIdMeta = const VerificationMeta(
    'notificationId',
  );
  @override
  late final GeneratedColumn<int> notificationId = GeneratedColumn<int>(
    'notification_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<int> createdAtUtc = GeneratedColumn<int>(
    'created_at_utc',
    aliasedName,
    false,
    check: () => utcEpochCheck('created_at_utc'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    entityId,
    notificationId,
    createdAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notification_id_mappings';
  @override
  VerificationContext validateIntegrity(
    Insertable<NotificationIdMapping> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('notification_id')) {
      context.handle(
        _notificationIdMeta,
        notificationId.isAcceptableOrUnknown(
          data['notification_id']!,
          _notificationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_notificationIdMeta);
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entityId};
  @override
  NotificationIdMapping map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotificationIdMapping(
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      notificationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}notification_id'],
      )!,
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc'],
      )!,
    );
  }

  @override
  $NotificationIdMappingsTable createAlias(String alias) {
    return $NotificationIdMappingsTable(attachedDatabase, alias);
  }
}

class NotificationIdMapping extends DataClass
    implements Insertable<NotificationIdMapping> {
  final String entityId;
  final int notificationId;
  final int createdAtUtc;
  const NotificationIdMapping({
    required this.entityId,
    required this.notificationId,
    required this.createdAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entity_id'] = Variable<String>(entityId);
    map['notification_id'] = Variable<int>(notificationId);
    map['created_at_utc'] = Variable<int>(createdAtUtc);
    return map;
  }

  NotificationIdMappingsCompanion toCompanion(bool nullToAbsent) {
    return NotificationIdMappingsCompanion(
      entityId: Value(entityId),
      notificationId: Value(notificationId),
      createdAtUtc: Value(createdAtUtc),
    );
  }

  factory NotificationIdMapping.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotificationIdMapping(
      entityId: serializer.fromJson<String>(json['entityId']),
      notificationId: serializer.fromJson<int>(json['notificationId']),
      createdAtUtc: serializer.fromJson<int>(json['createdAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entityId': serializer.toJson<String>(entityId),
      'notificationId': serializer.toJson<int>(notificationId),
      'createdAtUtc': serializer.toJson<int>(createdAtUtc),
    };
  }

  NotificationIdMapping copyWith({
    String? entityId,
    int? notificationId,
    int? createdAtUtc,
  }) => NotificationIdMapping(
    entityId: entityId ?? this.entityId,
    notificationId: notificationId ?? this.notificationId,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
  );
  NotificationIdMapping copyWithCompanion(
    NotificationIdMappingsCompanion data,
  ) {
    return NotificationIdMapping(
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      notificationId: data.notificationId.present
          ? data.notificationId.value
          : this.notificationId,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotificationIdMapping(')
          ..write('entityId: $entityId, ')
          ..write('notificationId: $notificationId, ')
          ..write('createdAtUtc: $createdAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entityId, notificationId, createdAtUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotificationIdMapping &&
          other.entityId == this.entityId &&
          other.notificationId == this.notificationId &&
          other.createdAtUtc == this.createdAtUtc);
}

class NotificationIdMappingsCompanion
    extends UpdateCompanion<NotificationIdMapping> {
  final Value<String> entityId;
  final Value<int> notificationId;
  final Value<int> createdAtUtc;
  final Value<int> rowid;
  const NotificationIdMappingsCompanion({
    this.entityId = const Value.absent(),
    this.notificationId = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotificationIdMappingsCompanion.insert({
    required String entityId,
    required int notificationId,
    required int createdAtUtc,
    this.rowid = const Value.absent(),
  }) : entityId = Value(entityId),
       notificationId = Value(notificationId),
       createdAtUtc = Value(createdAtUtc);
  static Insertable<NotificationIdMapping> custom({
    Expression<String>? entityId,
    Expression<int>? notificationId,
    Expression<int>? createdAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entityId != null) 'entity_id': entityId,
      if (notificationId != null) 'notification_id': notificationId,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotificationIdMappingsCompanion copyWith({
    Value<String>? entityId,
    Value<int>? notificationId,
    Value<int>? createdAtUtc,
    Value<int>? rowid,
  }) {
    return NotificationIdMappingsCompanion(
      entityId: entityId ?? this.entityId,
      notificationId: notificationId ?? this.notificationId,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (notificationId.present) {
      map['notification_id'] = Variable<int>(notificationId.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>(createdAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotificationIdMappingsCompanion(')
          ..write('entityId: $entityId, ')
          ..write('notificationId: $notificationId, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CustomersTable customers = $CustomersTable(this);
  late final $DepositsTable deposits = $DepositsTable(this);
  late final $RenewalsTable renewals = $RenewalsTable(this);
  late final $AuditHistoryTable auditHistory = $AuditHistoryTable(this);
  late final $MessageTemplatesTable messageTemplates = $MessageTemplatesTable(
    this,
  );
  late final $ImportBatchesTable importBatches = $ImportBatchesTable(this);
  late final $BusinessSettingsTable businessSettings = $BusinessSettingsTable(
    this,
  );
  late final $NotificationIdMappingsTable notificationIdMappings =
      $NotificationIdMappingsTable(this);
  late final Index customersNormalizedNameIdx = Index(
    'customers_normalized_name_idx',
    'CREATE INDEX customers_normalized_name_idx ON customers (normalized_name)',
  );
  late final Index customersFullPinyinIdx = Index(
    'customers_full_pinyin_idx',
    'CREATE INDEX customers_full_pinyin_idx ON customers (full_pinyin)',
  );
  late final Index customersInitialsIdx = Index(
    'customers_initials_idx',
    'CREATE INDEX customers_initials_idx ON customers (initials)',
  );
  late final Index customersNormalizedPhoneIdx = Index(
    'customers_normalized_phone_idx',
    'CREATE INDEX customers_normalized_phone_idx ON customers (normalized_phone)',
  );
  late final Index depositsBankNameIdx = Index(
    'deposits_bank_name_idx',
    'CREATE INDEX deposits_bank_name_idx ON deposits (bank_name COLLATE NOCASE)',
  );
  late final Index depositsExpiryLifecycleCustomerIdx = Index(
    'deposits_expiry_lifecycle_customer_idx',
    'CREATE INDEX deposits_expiry_lifecycle_customer_idx ON deposits (final_expiry_date, lifecycle, customer_id)',
  );
  late final Index importBatchesContentHashIdx = Index(
    'import_batches_content_hash_idx',
    'CREATE UNIQUE INDEX import_batches_content_hash_idx ON import_batches (content_hash)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    customers,
    deposits,
    renewals,
    auditHistory,
    messageTemplates,
    importBatches,
    businessSettings,
    notificationIdMappings,
    customersNormalizedNameIdx,
    customersFullPinyinIdx,
    customersInitialsIdx,
    customersNormalizedPhoneIdx,
    depositsBankNameIdx,
    depositsExpiryLifecycleCustomerIdx,
    importBatchesContentHashIdx,
  ];
}

typedef $$CustomersTableCreateCompanionBuilder =
    CustomersCompanion Function({
      required String id,
      required String name,
      Value<String?> phone,
      Value<String> normalizedName,
      Value<String> fullPinyin,
      Value<String> initials,
      Value<String> normalizedPhone,
      Value<bool> isActive,
      required int createdAtUtc,
      required int updatedAtUtc,
      Value<int> rowid,
    });
typedef $$CustomersTableUpdateCompanionBuilder =
    CustomersCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> phone,
      Value<String> normalizedName,
      Value<String> fullPinyin,
      Value<String> initials,
      Value<String> normalizedPhone,
      Value<bool> isActive,
      Value<int> createdAtUtc,
      Value<int> updatedAtUtc,
      Value<int> rowid,
    });

final class $$CustomersTableReferences
    extends BaseReferences<_$AppDatabase, $CustomersTable, Customer> {
  $$CustomersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$DepositsTable, List<Deposit>> _depositsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.deposits,
    aliasName: $_aliasNameGenerator(db.customers.id, db.deposits.customerId),
  );

  $$DepositsTableProcessedTableManager get depositsRefs {
    final manager = $$DepositsTableTableManager(
      $_db,
      $_db.deposits,
    ).filter((f) => f.customerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_depositsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CustomersTableFilterComposer
    extends Composer<_$AppDatabase, $CustomersTable> {
  $$CustomersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fullPinyin => $composableBuilder(
    column: $table.fullPinyin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get initials => $composableBuilder(
    column: $table.initials,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedPhone => $composableBuilder(
    column: $table.normalizedPhone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> depositsRefs(
    Expression<bool> Function($$DepositsTableFilterComposer f) f,
  ) {
    final $$DepositsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.deposits,
      getReferencedColumn: (t) => t.customerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DepositsTableFilterComposer(
            $db: $db,
            $table: $db.deposits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CustomersTableOrderingComposer
    extends Composer<_$AppDatabase, $CustomersTable> {
  $$CustomersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fullPinyin => $composableBuilder(
    column: $table.fullPinyin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get initials => $composableBuilder(
    column: $table.initials,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedPhone => $composableBuilder(
    column: $table.normalizedPhone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CustomersTableAnnotationComposer
    extends Composer<_$AppDatabase, $CustomersTable> {
  $$CustomersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fullPinyin => $composableBuilder(
    column: $table.fullPinyin,
    builder: (column) => column,
  );

  GeneratedColumn<String> get initials =>
      $composableBuilder(column: $table.initials, builder: (column) => column);

  GeneratedColumn<String> get normalizedPhone => $composableBuilder(
    column: $table.normalizedPhone,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );

  Expression<T> depositsRefs<T extends Object>(
    Expression<T> Function($$DepositsTableAnnotationComposer a) f,
  ) {
    final $$DepositsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.deposits,
      getReferencedColumn: (t) => t.customerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DepositsTableAnnotationComposer(
            $db: $db,
            $table: $db.deposits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CustomersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CustomersTable,
          Customer,
          $$CustomersTableFilterComposer,
          $$CustomersTableOrderingComposer,
          $$CustomersTableAnnotationComposer,
          $$CustomersTableCreateCompanionBuilder,
          $$CustomersTableUpdateCompanionBuilder,
          (Customer, $$CustomersTableReferences),
          Customer,
          PrefetchHooks Function({bool depositsRefs})
        > {
  $$CustomersTableTableManager(_$AppDatabase db, $CustomersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CustomersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CustomersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CustomersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String> normalizedName = const Value.absent(),
                Value<String> fullPinyin = const Value.absent(),
                Value<String> initials = const Value.absent(),
                Value<String> normalizedPhone = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> createdAtUtc = const Value.absent(),
                Value<int> updatedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomersCompanion(
                id: id,
                name: name,
                phone: phone,
                normalizedName: normalizedName,
                fullPinyin: fullPinyin,
                initials: initials,
                normalizedPhone: normalizedPhone,
                isActive: isActive,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> phone = const Value.absent(),
                Value<String> normalizedName = const Value.absent(),
                Value<String> fullPinyin = const Value.absent(),
                Value<String> initials = const Value.absent(),
                Value<String> normalizedPhone = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                required int createdAtUtc,
                required int updatedAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => CustomersCompanion.insert(
                id: id,
                name: name,
                phone: phone,
                normalizedName: normalizedName,
                fullPinyin: fullPinyin,
                initials: initials,
                normalizedPhone: normalizedPhone,
                isActive: isActive,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CustomersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({depositsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (depositsRefs) db.deposits],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (depositsRefs)
                    await $_getPrefetchedData<
                      Customer,
                      $CustomersTable,
                      Deposit
                    >(
                      currentTable: table,
                      referencedTable: $$CustomersTableReferences
                          ._depositsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CustomersTableReferences(
                            db,
                            table,
                            p0,
                          ).depositsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.customerId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CustomersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CustomersTable,
      Customer,
      $$CustomersTableFilterComposer,
      $$CustomersTableOrderingComposer,
      $$CustomersTableAnnotationComposer,
      $$CustomersTableCreateCompanionBuilder,
      $$CustomersTableUpdateCompanionBuilder,
      (Customer, $$CustomersTableReferences),
      Customer,
      PrefetchHooks Function({bool depositsRefs})
    >;
typedef $$DepositsTableCreateCompanionBuilder =
    DepositsCompanion Function({
      required String id,
      required String customerId,
      required int amountCents,
      Value<String> bankName,
      required int interestRateScaled,
      required int ratePrecision,
      required String startDate,
      Value<String?> calculatedExpiryDate,
      required String finalExpiryDate,
      required String lifecycle,
      required int createdAtUtc,
      required int updatedAtUtc,
      required String sourceDeviceId,
      Value<int> rowid,
    });
typedef $$DepositsTableUpdateCompanionBuilder =
    DepositsCompanion Function({
      Value<String> id,
      Value<String> customerId,
      Value<int> amountCents,
      Value<String> bankName,
      Value<int> interestRateScaled,
      Value<int> ratePrecision,
      Value<String> startDate,
      Value<String?> calculatedExpiryDate,
      Value<String> finalExpiryDate,
      Value<String> lifecycle,
      Value<int> createdAtUtc,
      Value<int> updatedAtUtc,
      Value<String> sourceDeviceId,
      Value<int> rowid,
    });

final class $$DepositsTableReferences
    extends BaseReferences<_$AppDatabase, $DepositsTable, Deposit> {
  $$DepositsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CustomersTable _customerIdTable(_$AppDatabase db) =>
      db.customers.createAlias(
        $_aliasNameGenerator(db.deposits.customerId, db.customers.id),
      );

  $$CustomersTableProcessedTableManager get customerId {
    final $_column = $_itemColumn<String>('customer_id')!;

    final manager = $$CustomersTableTableManager(
      $_db,
      $_db.customers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_customerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$RenewalsTable, List<Renewal>>
  _sourceRenewalsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.renewals,
    aliasName: $_aliasNameGenerator(
      db.deposits.id,
      db.renewals.sourceDepositId,
    ),
  );

  $$RenewalsTableProcessedTableManager get sourceRenewals {
    final manager = $$RenewalsTableTableManager($_db, $_db.renewals).filter(
      (f) => f.sourceDepositId.id.sqlEquals($_itemColumn<String>('id')!),
    );

    final cache = $_typedResult.readTableOrNull(_sourceRenewalsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RenewalsTable, List<Renewal>> _targetRenewalTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.renewals,
    aliasName: $_aliasNameGenerator(
      db.deposits.id,
      db.renewals.targetDepositId,
    ),
  );

  $$RenewalsTableProcessedTableManager get targetRenewal {
    final manager = $$RenewalsTableTableManager($_db, $_db.renewals).filter(
      (f) => f.targetDepositId.id.sqlEquals($_itemColumn<String>('id')!),
    );

    final cache = $_typedResult.readTableOrNull(_targetRenewalTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DepositsTableFilterComposer
    extends Composer<_$AppDatabase, $DepositsTable> {
  $$DepositsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bankName => $composableBuilder(
    column: $table.bankName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get interestRateScaled => $composableBuilder(
    column: $table.interestRateScaled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ratePrecision => $composableBuilder(
    column: $table.ratePrecision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get calculatedExpiryDate => $composableBuilder(
    column: $table.calculatedExpiryDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get finalExpiryDate => $composableBuilder(
    column: $table.finalExpiryDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lifecycle => $composableBuilder(
    column: $table.lifecycle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceDeviceId => $composableBuilder(
    column: $table.sourceDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  $$CustomersTableFilterComposer get customerId {
    final $$CustomersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.customerId,
      referencedTable: $db.customers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CustomersTableFilterComposer(
            $db: $db,
            $table: $db.customers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> sourceRenewals(
    Expression<bool> Function($$RenewalsTableFilterComposer f) f,
  ) {
    final $$RenewalsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.renewals,
      getReferencedColumn: (t) => t.sourceDepositId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RenewalsTableFilterComposer(
            $db: $db,
            $table: $db.renewals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> targetRenewal(
    Expression<bool> Function($$RenewalsTableFilterComposer f) f,
  ) {
    final $$RenewalsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.renewals,
      getReferencedColumn: (t) => t.targetDepositId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RenewalsTableFilterComposer(
            $db: $db,
            $table: $db.renewals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DepositsTableOrderingComposer
    extends Composer<_$AppDatabase, $DepositsTable> {
  $$DepositsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bankName => $composableBuilder(
    column: $table.bankName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get interestRateScaled => $composableBuilder(
    column: $table.interestRateScaled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ratePrecision => $composableBuilder(
    column: $table.ratePrecision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get calculatedExpiryDate => $composableBuilder(
    column: $table.calculatedExpiryDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get finalExpiryDate => $composableBuilder(
    column: $table.finalExpiryDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lifecycle => $composableBuilder(
    column: $table.lifecycle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceDeviceId => $composableBuilder(
    column: $table.sourceDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  $$CustomersTableOrderingComposer get customerId {
    final $$CustomersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.customerId,
      referencedTable: $db.customers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CustomersTableOrderingComposer(
            $db: $db,
            $table: $db.customers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DepositsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DepositsTable> {
  $$DepositsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bankName =>
      $composableBuilder(column: $table.bankName, builder: (column) => column);

  GeneratedColumn<int> get interestRateScaled => $composableBuilder(
    column: $table.interestRateScaled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get ratePrecision => $composableBuilder(
    column: $table.ratePrecision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<String> get calculatedExpiryDate => $composableBuilder(
    column: $table.calculatedExpiryDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get finalExpiryDate => $composableBuilder(
    column: $table.finalExpiryDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lifecycle =>
      $composableBuilder(column: $table.lifecycle, builder: (column) => column);

  GeneratedColumn<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceDeviceId => $composableBuilder(
    column: $table.sourceDeviceId,
    builder: (column) => column,
  );

  $$CustomersTableAnnotationComposer get customerId {
    final $$CustomersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.customerId,
      referencedTable: $db.customers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CustomersTableAnnotationComposer(
            $db: $db,
            $table: $db.customers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> sourceRenewals<T extends Object>(
    Expression<T> Function($$RenewalsTableAnnotationComposer a) f,
  ) {
    final $$RenewalsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.renewals,
      getReferencedColumn: (t) => t.sourceDepositId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RenewalsTableAnnotationComposer(
            $db: $db,
            $table: $db.renewals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> targetRenewal<T extends Object>(
    Expression<T> Function($$RenewalsTableAnnotationComposer a) f,
  ) {
    final $$RenewalsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.renewals,
      getReferencedColumn: (t) => t.targetDepositId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RenewalsTableAnnotationComposer(
            $db: $db,
            $table: $db.renewals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DepositsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DepositsTable,
          Deposit,
          $$DepositsTableFilterComposer,
          $$DepositsTableOrderingComposer,
          $$DepositsTableAnnotationComposer,
          $$DepositsTableCreateCompanionBuilder,
          $$DepositsTableUpdateCompanionBuilder,
          (Deposit, $$DepositsTableReferences),
          Deposit,
          PrefetchHooks Function({
            bool customerId,
            bool sourceRenewals,
            bool targetRenewal,
          })
        > {
  $$DepositsTableTableManager(_$AppDatabase db, $DepositsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DepositsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DepositsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DepositsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> customerId = const Value.absent(),
                Value<int> amountCents = const Value.absent(),
                Value<String> bankName = const Value.absent(),
                Value<int> interestRateScaled = const Value.absent(),
                Value<int> ratePrecision = const Value.absent(),
                Value<String> startDate = const Value.absent(),
                Value<String?> calculatedExpiryDate = const Value.absent(),
                Value<String> finalExpiryDate = const Value.absent(),
                Value<String> lifecycle = const Value.absent(),
                Value<int> createdAtUtc = const Value.absent(),
                Value<int> updatedAtUtc = const Value.absent(),
                Value<String> sourceDeviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DepositsCompanion(
                id: id,
                customerId: customerId,
                amountCents: amountCents,
                bankName: bankName,
                interestRateScaled: interestRateScaled,
                ratePrecision: ratePrecision,
                startDate: startDate,
                calculatedExpiryDate: calculatedExpiryDate,
                finalExpiryDate: finalExpiryDate,
                lifecycle: lifecycle,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                sourceDeviceId: sourceDeviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String customerId,
                required int amountCents,
                Value<String> bankName = const Value.absent(),
                required int interestRateScaled,
                required int ratePrecision,
                required String startDate,
                Value<String?> calculatedExpiryDate = const Value.absent(),
                required String finalExpiryDate,
                required String lifecycle,
                required int createdAtUtc,
                required int updatedAtUtc,
                required String sourceDeviceId,
                Value<int> rowid = const Value.absent(),
              }) => DepositsCompanion.insert(
                id: id,
                customerId: customerId,
                amountCents: amountCents,
                bankName: bankName,
                interestRateScaled: interestRateScaled,
                ratePrecision: ratePrecision,
                startDate: startDate,
                calculatedExpiryDate: calculatedExpiryDate,
                finalExpiryDate: finalExpiryDate,
                lifecycle: lifecycle,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                sourceDeviceId: sourceDeviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DepositsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                customerId = false,
                sourceRenewals = false,
                targetRenewal = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (sourceRenewals) db.renewals,
                    if (targetRenewal) db.renewals,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (customerId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.customerId,
                                    referencedTable: $$DepositsTableReferences
                                        ._customerIdTable(db),
                                    referencedColumn: $$DepositsTableReferences
                                        ._customerIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (sourceRenewals)
                        await $_getPrefetchedData<
                          Deposit,
                          $DepositsTable,
                          Renewal
                        >(
                          currentTable: table,
                          referencedTable: $$DepositsTableReferences
                              ._sourceRenewalsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DepositsTableReferences(
                                db,
                                table,
                                p0,
                              ).sourceRenewals,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceDepositId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (targetRenewal)
                        await $_getPrefetchedData<
                          Deposit,
                          $DepositsTable,
                          Renewal
                        >(
                          currentTable: table,
                          referencedTable: $$DepositsTableReferences
                              ._targetRenewalTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DepositsTableReferences(
                                db,
                                table,
                                p0,
                              ).targetRenewal,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.targetDepositId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$DepositsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DepositsTable,
      Deposit,
      $$DepositsTableFilterComposer,
      $$DepositsTableOrderingComposer,
      $$DepositsTableAnnotationComposer,
      $$DepositsTableCreateCompanionBuilder,
      $$DepositsTableUpdateCompanionBuilder,
      (Deposit, $$DepositsTableReferences),
      Deposit,
      PrefetchHooks Function({
        bool customerId,
        bool sourceRenewals,
        bool targetRenewal,
      })
    >;
typedef $$RenewalsTableCreateCompanionBuilder =
    RenewalsCompanion Function({
      required String id,
      required String sourceDepositId,
      required String targetDepositId,
      required int renewedAtUtc,
      required String sourceDeviceId,
      Value<int> rowid,
    });
typedef $$RenewalsTableUpdateCompanionBuilder =
    RenewalsCompanion Function({
      Value<String> id,
      Value<String> sourceDepositId,
      Value<String> targetDepositId,
      Value<int> renewedAtUtc,
      Value<String> sourceDeviceId,
      Value<int> rowid,
    });

final class $$RenewalsTableReferences
    extends BaseReferences<_$AppDatabase, $RenewalsTable, Renewal> {
  $$RenewalsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DepositsTable _sourceDepositIdTable(_$AppDatabase db) =>
      db.deposits.createAlias(
        $_aliasNameGenerator(db.renewals.sourceDepositId, db.deposits.id),
      );

  $$DepositsTableProcessedTableManager get sourceDepositId {
    final $_column = $_itemColumn<String>('source_deposit_id')!;

    final manager = $$DepositsTableTableManager(
      $_db,
      $_db.deposits,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceDepositIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $DepositsTable _targetDepositIdTable(_$AppDatabase db) =>
      db.deposits.createAlias(
        $_aliasNameGenerator(db.renewals.targetDepositId, db.deposits.id),
      );

  $$DepositsTableProcessedTableManager get targetDepositId {
    final $_column = $_itemColumn<String>('target_deposit_id')!;

    final manager = $$DepositsTableTableManager(
      $_db,
      $_db.deposits,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_targetDepositIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RenewalsTableFilterComposer
    extends Composer<_$AppDatabase, $RenewalsTable> {
  $$RenewalsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get renewedAtUtc => $composableBuilder(
    column: $table.renewedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceDeviceId => $composableBuilder(
    column: $table.sourceDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  $$DepositsTableFilterComposer get sourceDepositId {
    final $$DepositsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceDepositId,
      referencedTable: $db.deposits,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DepositsTableFilterComposer(
            $db: $db,
            $table: $db.deposits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DepositsTableFilterComposer get targetDepositId {
    final $$DepositsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.targetDepositId,
      referencedTable: $db.deposits,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DepositsTableFilterComposer(
            $db: $db,
            $table: $db.deposits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RenewalsTableOrderingComposer
    extends Composer<_$AppDatabase, $RenewalsTable> {
  $$RenewalsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get renewedAtUtc => $composableBuilder(
    column: $table.renewedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceDeviceId => $composableBuilder(
    column: $table.sourceDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  $$DepositsTableOrderingComposer get sourceDepositId {
    final $$DepositsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceDepositId,
      referencedTable: $db.deposits,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DepositsTableOrderingComposer(
            $db: $db,
            $table: $db.deposits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DepositsTableOrderingComposer get targetDepositId {
    final $$DepositsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.targetDepositId,
      referencedTable: $db.deposits,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DepositsTableOrderingComposer(
            $db: $db,
            $table: $db.deposits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RenewalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RenewalsTable> {
  $$RenewalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get renewedAtUtc => $composableBuilder(
    column: $table.renewedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceDeviceId => $composableBuilder(
    column: $table.sourceDeviceId,
    builder: (column) => column,
  );

  $$DepositsTableAnnotationComposer get sourceDepositId {
    final $$DepositsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceDepositId,
      referencedTable: $db.deposits,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DepositsTableAnnotationComposer(
            $db: $db,
            $table: $db.deposits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DepositsTableAnnotationComposer get targetDepositId {
    final $$DepositsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.targetDepositId,
      referencedTable: $db.deposits,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DepositsTableAnnotationComposer(
            $db: $db,
            $table: $db.deposits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RenewalsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RenewalsTable,
          Renewal,
          $$RenewalsTableFilterComposer,
          $$RenewalsTableOrderingComposer,
          $$RenewalsTableAnnotationComposer,
          $$RenewalsTableCreateCompanionBuilder,
          $$RenewalsTableUpdateCompanionBuilder,
          (Renewal, $$RenewalsTableReferences),
          Renewal,
          PrefetchHooks Function({bool sourceDepositId, bool targetDepositId})
        > {
  $$RenewalsTableTableManager(_$AppDatabase db, $RenewalsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RenewalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RenewalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RenewalsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sourceDepositId = const Value.absent(),
                Value<String> targetDepositId = const Value.absent(),
                Value<int> renewedAtUtc = const Value.absent(),
                Value<String> sourceDeviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RenewalsCompanion(
                id: id,
                sourceDepositId: sourceDepositId,
                targetDepositId: targetDepositId,
                renewedAtUtc: renewedAtUtc,
                sourceDeviceId: sourceDeviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sourceDepositId,
                required String targetDepositId,
                required int renewedAtUtc,
                required String sourceDeviceId,
                Value<int> rowid = const Value.absent(),
              }) => RenewalsCompanion.insert(
                id: id,
                sourceDepositId: sourceDepositId,
                targetDepositId: targetDepositId,
                renewedAtUtc: renewedAtUtc,
                sourceDeviceId: sourceDeviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RenewalsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({sourceDepositId = false, targetDepositId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (sourceDepositId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.sourceDepositId,
                                    referencedTable: $$RenewalsTableReferences
                                        ._sourceDepositIdTable(db),
                                    referencedColumn: $$RenewalsTableReferences
                                        ._sourceDepositIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (targetDepositId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.targetDepositId,
                                    referencedTable: $$RenewalsTableReferences
                                        ._targetDepositIdTable(db),
                                    referencedColumn: $$RenewalsTableReferences
                                        ._targetDepositIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$RenewalsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RenewalsTable,
      Renewal,
      $$RenewalsTableFilterComposer,
      $$RenewalsTableOrderingComposer,
      $$RenewalsTableAnnotationComposer,
      $$RenewalsTableCreateCompanionBuilder,
      $$RenewalsTableUpdateCompanionBuilder,
      (Renewal, $$RenewalsTableReferences),
      Renewal,
      PrefetchHooks Function({bool sourceDepositId, bool targetDepositId})
    >;
typedef $$AuditHistoryTableCreateCompanionBuilder =
    AuditHistoryCompanion Function({
      required String id,
      required String entityType,
      required String entityId,
      required String operation,
      Value<String?> beforeJson,
      Value<String?> afterJson,
      required int occurredAtUtc,
      required String sourceDeviceId,
      required int businessRevision,
      Value<int> rowid,
    });
typedef $$AuditHistoryTableUpdateCompanionBuilder =
    AuditHistoryCompanion Function({
      Value<String> id,
      Value<String> entityType,
      Value<String> entityId,
      Value<String> operation,
      Value<String?> beforeJson,
      Value<String?> afterJson,
      Value<int> occurredAtUtc,
      Value<String> sourceDeviceId,
      Value<int> businessRevision,
      Value<int> rowid,
    });

class $$AuditHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $AuditHistoryTable> {
  $$AuditHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get beforeJson => $composableBuilder(
    column: $table.beforeJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get afterJson => $composableBuilder(
    column: $table.afterJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get occurredAtUtc => $composableBuilder(
    column: $table.occurredAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceDeviceId => $composableBuilder(
    column: $table.sourceDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get businessRevision => $composableBuilder(
    column: $table.businessRevision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AuditHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $AuditHistoryTable> {
  $$AuditHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get beforeJson => $composableBuilder(
    column: $table.beforeJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get afterJson => $composableBuilder(
    column: $table.afterJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get occurredAtUtc => $composableBuilder(
    column: $table.occurredAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceDeviceId => $composableBuilder(
    column: $table.sourceDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get businessRevision => $composableBuilder(
    column: $table.businessRevision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AuditHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $AuditHistoryTable> {
  $$AuditHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get beforeJson => $composableBuilder(
    column: $table.beforeJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get afterJson =>
      $composableBuilder(column: $table.afterJson, builder: (column) => column);

  GeneratedColumn<int> get occurredAtUtc => $composableBuilder(
    column: $table.occurredAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceDeviceId => $composableBuilder(
    column: $table.sourceDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get businessRevision => $composableBuilder(
    column: $table.businessRevision,
    builder: (column) => column,
  );
}

class $$AuditHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AuditHistoryTable,
          AuditHistoryData,
          $$AuditHistoryTableFilterComposer,
          $$AuditHistoryTableOrderingComposer,
          $$AuditHistoryTableAnnotationComposer,
          $$AuditHistoryTableCreateCompanionBuilder,
          $$AuditHistoryTableUpdateCompanionBuilder,
          (
            AuditHistoryData,
            BaseReferences<_$AppDatabase, $AuditHistoryTable, AuditHistoryData>,
          ),
          AuditHistoryData,
          PrefetchHooks Function()
        > {
  $$AuditHistoryTableTableManager(_$AppDatabase db, $AuditHistoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AuditHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AuditHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AuditHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<String?> beforeJson = const Value.absent(),
                Value<String?> afterJson = const Value.absent(),
                Value<int> occurredAtUtc = const Value.absent(),
                Value<String> sourceDeviceId = const Value.absent(),
                Value<int> businessRevision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AuditHistoryCompanion(
                id: id,
                entityType: entityType,
                entityId: entityId,
                operation: operation,
                beforeJson: beforeJson,
                afterJson: afterJson,
                occurredAtUtc: occurredAtUtc,
                sourceDeviceId: sourceDeviceId,
                businessRevision: businessRevision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String entityType,
                required String entityId,
                required String operation,
                Value<String?> beforeJson = const Value.absent(),
                Value<String?> afterJson = const Value.absent(),
                required int occurredAtUtc,
                required String sourceDeviceId,
                required int businessRevision,
                Value<int> rowid = const Value.absent(),
              }) => AuditHistoryCompanion.insert(
                id: id,
                entityType: entityType,
                entityId: entityId,
                operation: operation,
                beforeJson: beforeJson,
                afterJson: afterJson,
                occurredAtUtc: occurredAtUtc,
                sourceDeviceId: sourceDeviceId,
                businessRevision: businessRevision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AuditHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AuditHistoryTable,
      AuditHistoryData,
      $$AuditHistoryTableFilterComposer,
      $$AuditHistoryTableOrderingComposer,
      $$AuditHistoryTableAnnotationComposer,
      $$AuditHistoryTableCreateCompanionBuilder,
      $$AuditHistoryTableUpdateCompanionBuilder,
      (
        AuditHistoryData,
        BaseReferences<_$AppDatabase, $AuditHistoryTable, AuditHistoryData>,
      ),
      AuditHistoryData,
      PrefetchHooks Function()
    >;
typedef $$MessageTemplatesTableCreateCompanionBuilder =
    MessageTemplatesCompanion Function({
      required String id,
      required String name,
      required String content,
      Value<bool> isActive,
      required int createdAtUtc,
      required int updatedAtUtc,
      Value<int> rowid,
    });
typedef $$MessageTemplatesTableUpdateCompanionBuilder =
    MessageTemplatesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> content,
      Value<bool> isActive,
      Value<int> createdAtUtc,
      Value<int> updatedAtUtc,
      Value<int> rowid,
    });

class $$MessageTemplatesTableFilterComposer
    extends Composer<_$AppDatabase, $MessageTemplatesTable> {
  $$MessageTemplatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MessageTemplatesTableOrderingComposer
    extends Composer<_$AppDatabase, $MessageTemplatesTable> {
  $$MessageTemplatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessageTemplatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessageTemplatesTable> {
  $$MessageTemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );
}

class $$MessageTemplatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessageTemplatesTable,
          MessageTemplate,
          $$MessageTemplatesTableFilterComposer,
          $$MessageTemplatesTableOrderingComposer,
          $$MessageTemplatesTableAnnotationComposer,
          $$MessageTemplatesTableCreateCompanionBuilder,
          $$MessageTemplatesTableUpdateCompanionBuilder,
          (
            MessageTemplate,
            BaseReferences<
              _$AppDatabase,
              $MessageTemplatesTable,
              MessageTemplate
            >,
          ),
          MessageTemplate,
          PrefetchHooks Function()
        > {
  $$MessageTemplatesTableTableManager(
    _$AppDatabase db,
    $MessageTemplatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessageTemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessageTemplatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessageTemplatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> createdAtUtc = const Value.absent(),
                Value<int> updatedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessageTemplatesCompanion(
                id: id,
                name: name,
                content: content,
                isActive: isActive,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String content,
                Value<bool> isActive = const Value.absent(),
                required int createdAtUtc,
                required int updatedAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => MessageTemplatesCompanion.insert(
                id: id,
                name: name,
                content: content,
                isActive: isActive,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MessageTemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessageTemplatesTable,
      MessageTemplate,
      $$MessageTemplatesTableFilterComposer,
      $$MessageTemplatesTableOrderingComposer,
      $$MessageTemplatesTableAnnotationComposer,
      $$MessageTemplatesTableCreateCompanionBuilder,
      $$MessageTemplatesTableUpdateCompanionBuilder,
      (
        MessageTemplate,
        BaseReferences<_$AppDatabase, $MessageTemplatesTable, MessageTemplate>,
      ),
      MessageTemplate,
      PrefetchHooks Function()
    >;
typedef $$ImportBatchesTableCreateCompanionBuilder =
    ImportBatchesCompanion Function({
      required String id,
      required String fileName,
      required String contentHash,
      Value<int> importedRows,
      Value<int> rejectedRows,
      required int importedAtUtc,
      required String sourceDeviceId,
      Value<int> rowid,
    });
typedef $$ImportBatchesTableUpdateCompanionBuilder =
    ImportBatchesCompanion Function({
      Value<String> id,
      Value<String> fileName,
      Value<String> contentHash,
      Value<int> importedRows,
      Value<int> rejectedRows,
      Value<int> importedAtUtc,
      Value<String> sourceDeviceId,
      Value<int> rowid,
    });

class $$ImportBatchesTableFilterComposer
    extends Composer<_$AppDatabase, $ImportBatchesTable> {
  $$ImportBatchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get importedRows => $composableBuilder(
    column: $table.importedRows,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rejectedRows => $composableBuilder(
    column: $table.rejectedRows,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get importedAtUtc => $composableBuilder(
    column: $table.importedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceDeviceId => $composableBuilder(
    column: $table.sourceDeviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ImportBatchesTableOrderingComposer
    extends Composer<_$AppDatabase, $ImportBatchesTable> {
  $$ImportBatchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get importedRows => $composableBuilder(
    column: $table.importedRows,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rejectedRows => $composableBuilder(
    column: $table.rejectedRows,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get importedAtUtc => $composableBuilder(
    column: $table.importedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceDeviceId => $composableBuilder(
    column: $table.sourceDeviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ImportBatchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ImportBatchesTable> {
  $$ImportBatchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get importedRows => $composableBuilder(
    column: $table.importedRows,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rejectedRows => $composableBuilder(
    column: $table.rejectedRows,
    builder: (column) => column,
  );

  GeneratedColumn<int> get importedAtUtc => $composableBuilder(
    column: $table.importedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceDeviceId => $composableBuilder(
    column: $table.sourceDeviceId,
    builder: (column) => column,
  );
}

class $$ImportBatchesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ImportBatchesTable,
          ImportBatche,
          $$ImportBatchesTableFilterComposer,
          $$ImportBatchesTableOrderingComposer,
          $$ImportBatchesTableAnnotationComposer,
          $$ImportBatchesTableCreateCompanionBuilder,
          $$ImportBatchesTableUpdateCompanionBuilder,
          (
            ImportBatche,
            BaseReferences<_$AppDatabase, $ImportBatchesTable, ImportBatche>,
          ),
          ImportBatche,
          PrefetchHooks Function()
        > {
  $$ImportBatchesTableTableManager(_$AppDatabase db, $ImportBatchesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImportBatchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImportBatchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImportBatchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<int> importedRows = const Value.absent(),
                Value<int> rejectedRows = const Value.absent(),
                Value<int> importedAtUtc = const Value.absent(),
                Value<String> sourceDeviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ImportBatchesCompanion(
                id: id,
                fileName: fileName,
                contentHash: contentHash,
                importedRows: importedRows,
                rejectedRows: rejectedRows,
                importedAtUtc: importedAtUtc,
                sourceDeviceId: sourceDeviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String fileName,
                required String contentHash,
                Value<int> importedRows = const Value.absent(),
                Value<int> rejectedRows = const Value.absent(),
                required int importedAtUtc,
                required String sourceDeviceId,
                Value<int> rowid = const Value.absent(),
              }) => ImportBatchesCompanion.insert(
                id: id,
                fileName: fileName,
                contentHash: contentHash,
                importedRows: importedRows,
                rejectedRows: rejectedRows,
                importedAtUtc: importedAtUtc,
                sourceDeviceId: sourceDeviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ImportBatchesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ImportBatchesTable,
      ImportBatche,
      $$ImportBatchesTableFilterComposer,
      $$ImportBatchesTableOrderingComposer,
      $$ImportBatchesTableAnnotationComposer,
      $$ImportBatchesTableCreateCompanionBuilder,
      $$ImportBatchesTableUpdateCompanionBuilder,
      (
        ImportBatche,
        BaseReferences<_$AppDatabase, $ImportBatchesTable, ImportBatche>,
      ),
      ImportBatche,
      PrefetchHooks Function()
    >;
typedef $$BusinessSettingsTableCreateCompanionBuilder =
    BusinessSettingsCompanion Function({
      Value<int> singletonId,
      Value<int> businessRevision,
    });
typedef $$BusinessSettingsTableUpdateCompanionBuilder =
    BusinessSettingsCompanion Function({
      Value<int> singletonId,
      Value<int> businessRevision,
    });

class $$BusinessSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $BusinessSettingsTable> {
  $$BusinessSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get singletonId => $composableBuilder(
    column: $table.singletonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get businessRevision => $composableBuilder(
    column: $table.businessRevision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BusinessSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $BusinessSettingsTable> {
  $$BusinessSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get singletonId => $composableBuilder(
    column: $table.singletonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get businessRevision => $composableBuilder(
    column: $table.businessRevision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BusinessSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BusinessSettingsTable> {
  $$BusinessSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get singletonId => $composableBuilder(
    column: $table.singletonId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get businessRevision => $composableBuilder(
    column: $table.businessRevision,
    builder: (column) => column,
  );
}

class $$BusinessSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BusinessSettingsTable,
          BusinessSetting,
          $$BusinessSettingsTableFilterComposer,
          $$BusinessSettingsTableOrderingComposer,
          $$BusinessSettingsTableAnnotationComposer,
          $$BusinessSettingsTableCreateCompanionBuilder,
          $$BusinessSettingsTableUpdateCompanionBuilder,
          (
            BusinessSetting,
            BaseReferences<
              _$AppDatabase,
              $BusinessSettingsTable,
              BusinessSetting
            >,
          ),
          BusinessSetting,
          PrefetchHooks Function()
        > {
  $$BusinessSettingsTableTableManager(
    _$AppDatabase db,
    $BusinessSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BusinessSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BusinessSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BusinessSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> singletonId = const Value.absent(),
                Value<int> businessRevision = const Value.absent(),
              }) => BusinessSettingsCompanion(
                singletonId: singletonId,
                businessRevision: businessRevision,
              ),
          createCompanionCallback:
              ({
                Value<int> singletonId = const Value.absent(),
                Value<int> businessRevision = const Value.absent(),
              }) => BusinessSettingsCompanion.insert(
                singletonId: singletonId,
                businessRevision: businessRevision,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BusinessSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BusinessSettingsTable,
      BusinessSetting,
      $$BusinessSettingsTableFilterComposer,
      $$BusinessSettingsTableOrderingComposer,
      $$BusinessSettingsTableAnnotationComposer,
      $$BusinessSettingsTableCreateCompanionBuilder,
      $$BusinessSettingsTableUpdateCompanionBuilder,
      (
        BusinessSetting,
        BaseReferences<_$AppDatabase, $BusinessSettingsTable, BusinessSetting>,
      ),
      BusinessSetting,
      PrefetchHooks Function()
    >;
typedef $$NotificationIdMappingsTableCreateCompanionBuilder =
    NotificationIdMappingsCompanion Function({
      required String entityId,
      required int notificationId,
      required int createdAtUtc,
      Value<int> rowid,
    });
typedef $$NotificationIdMappingsTableUpdateCompanionBuilder =
    NotificationIdMappingsCompanion Function({
      Value<String> entityId,
      Value<int> notificationId,
      Value<int> createdAtUtc,
      Value<int> rowid,
    });

class $$NotificationIdMappingsTableFilterComposer
    extends Composer<_$AppDatabase, $NotificationIdMappingsTable> {
  $$NotificationIdMappingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get notificationId => $composableBuilder(
    column: $table.notificationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotificationIdMappingsTableOrderingComposer
    extends Composer<_$AppDatabase, $NotificationIdMappingsTable> {
  $$NotificationIdMappingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get notificationId => $composableBuilder(
    column: $table.notificationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotificationIdMappingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotificationIdMappingsTable> {
  $$NotificationIdMappingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<int> get notificationId => $composableBuilder(
    column: $table.notificationId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );
}

class $$NotificationIdMappingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotificationIdMappingsTable,
          NotificationIdMapping,
          $$NotificationIdMappingsTableFilterComposer,
          $$NotificationIdMappingsTableOrderingComposer,
          $$NotificationIdMappingsTableAnnotationComposer,
          $$NotificationIdMappingsTableCreateCompanionBuilder,
          $$NotificationIdMappingsTableUpdateCompanionBuilder,
          (
            NotificationIdMapping,
            BaseReferences<
              _$AppDatabase,
              $NotificationIdMappingsTable,
              NotificationIdMapping
            >,
          ),
          NotificationIdMapping,
          PrefetchHooks Function()
        > {
  $$NotificationIdMappingsTableTableManager(
    _$AppDatabase db,
    $NotificationIdMappingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotificationIdMappingsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$NotificationIdMappingsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$NotificationIdMappingsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> entityId = const Value.absent(),
                Value<int> notificationId = const Value.absent(),
                Value<int> createdAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotificationIdMappingsCompanion(
                entityId: entityId,
                notificationId: notificationId,
                createdAtUtc: createdAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entityId,
                required int notificationId,
                required int createdAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => NotificationIdMappingsCompanion.insert(
                entityId: entityId,
                notificationId: notificationId,
                createdAtUtc: createdAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotificationIdMappingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotificationIdMappingsTable,
      NotificationIdMapping,
      $$NotificationIdMappingsTableFilterComposer,
      $$NotificationIdMappingsTableOrderingComposer,
      $$NotificationIdMappingsTableAnnotationComposer,
      $$NotificationIdMappingsTableCreateCompanionBuilder,
      $$NotificationIdMappingsTableUpdateCompanionBuilder,
      (
        NotificationIdMapping,
        BaseReferences<
          _$AppDatabase,
          $NotificationIdMappingsTable,
          NotificationIdMapping
        >,
      ),
      NotificationIdMapping,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CustomersTableTableManager get customers =>
      $$CustomersTableTableManager(_db, _db.customers);
  $$DepositsTableTableManager get deposits =>
      $$DepositsTableTableManager(_db, _db.deposits);
  $$RenewalsTableTableManager get renewals =>
      $$RenewalsTableTableManager(_db, _db.renewals);
  $$AuditHistoryTableTableManager get auditHistory =>
      $$AuditHistoryTableTableManager(_db, _db.auditHistory);
  $$MessageTemplatesTableTableManager get messageTemplates =>
      $$MessageTemplatesTableTableManager(_db, _db.messageTemplates);
  $$ImportBatchesTableTableManager get importBatches =>
      $$ImportBatchesTableTableManager(_db, _db.importBatches);
  $$BusinessSettingsTableTableManager get businessSettings =>
      $$BusinessSettingsTableTableManager(_db, _db.businessSettings);
  $$NotificationIdMappingsTableTableManager get notificationIdMappings =>
      $$NotificationIdMappingsTableTableManager(
        _db,
        _db.notificationIdMappings,
      );
}
