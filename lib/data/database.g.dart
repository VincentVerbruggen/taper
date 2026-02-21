// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $TrackablesTable extends Trackables
    with TableInfo<$TrackablesTable, Trackable> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrackablesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
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
  static const VerificationMeta _isMainMeta = const VerificationMeta('isMain');
  @override
  late final GeneratedColumn<bool> isMain = GeneratedColumn<bool>(
    'is_main',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_main" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isVisibleMeta = const VerificationMeta(
    'isVisible',
  );
  @override
  late final GeneratedColumn<bool> isVisible = GeneratedColumn<bool>(
    'is_visible',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_visible" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _halfLifeHoursMeta = const VerificationMeta(
    'halfLifeHours',
  );
  @override
  late final GeneratedColumn<double> halfLifeHours = GeneratedColumn<double>(
    'half_life_hours',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('mg'),
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _decayModelMeta = const VerificationMeta(
    'decayModel',
  );
  @override
  late final GeneratedColumn<String> decayModel = GeneratedColumn<String>(
    'decay_model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('none'),
  );
  static const VerificationMeta _eliminationRateMeta = const VerificationMeta(
    'eliminationRate',
  );
  @override
  late final GeneratedColumn<double> eliminationRate = GeneratedColumn<double>(
    'elimination_rate',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    isMain,
    isVisible,
    halfLifeHours,
    unit,
    color,
    sortOrder,
    decayModel,
    eliminationRate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trackables';
  @override
  VerificationContext validateIntegrity(
    Insertable<Trackable> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_main')) {
      context.handle(
        _isMainMeta,
        isMain.isAcceptableOrUnknown(data['is_main']!, _isMainMeta),
      );
    }
    if (data.containsKey('is_visible')) {
      context.handle(
        _isVisibleMeta,
        isVisible.isAcceptableOrUnknown(data['is_visible']!, _isVisibleMeta),
      );
    }
    if (data.containsKey('half_life_hours')) {
      context.handle(
        _halfLifeHoursMeta,
        halfLifeHours.isAcceptableOrUnknown(
          data['half_life_hours']!,
          _halfLifeHoursMeta,
        ),
      );
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('decay_model')) {
      context.handle(
        _decayModelMeta,
        decayModel.isAcceptableOrUnknown(data['decay_model']!, _decayModelMeta),
      );
    }
    if (data.containsKey('elimination_rate')) {
      context.handle(
        _eliminationRateMeta,
        eliminationRate.isAcceptableOrUnknown(
          data['elimination_rate']!,
          _eliminationRateMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Trackable map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Trackable(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      isMain: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_main'],
      )!,
      isVisible: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_visible'],
      )!,
      halfLifeHours: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}half_life_hours'],
      ),
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      decayModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}decay_model'],
      )!,
      eliminationRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}elimination_rate'],
      ),
    );
  }

  @override
  $TrackablesTable createAlias(String alias) {
    return $TrackablesTable(attachedDatabase, alias);
  }
}

class Trackable extends DataClass implements Insertable<Trackable> {
  final int id;
  final String name;
  final bool isMain;
  final bool isVisible;
  final double? halfLifeHours;
  final String unit;
  final int color;
  final int sortOrder;
  final String decayModel;
  final double? eliminationRate;
  const Trackable({
    required this.id,
    required this.name,
    required this.isMain,
    required this.isVisible,
    this.halfLifeHours,
    required this.unit,
    required this.color,
    required this.sortOrder,
    required this.decayModel,
    this.eliminationRate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['is_main'] = Variable<bool>(isMain);
    map['is_visible'] = Variable<bool>(isVisible);
    if (!nullToAbsent || halfLifeHours != null) {
      map['half_life_hours'] = Variable<double>(halfLifeHours);
    }
    map['unit'] = Variable<String>(unit);
    map['color'] = Variable<int>(color);
    map['sort_order'] = Variable<int>(sortOrder);
    map['decay_model'] = Variable<String>(decayModel);
    if (!nullToAbsent || eliminationRate != null) {
      map['elimination_rate'] = Variable<double>(eliminationRate);
    }
    return map;
  }

  TrackablesCompanion toCompanion(bool nullToAbsent) {
    return TrackablesCompanion(
      id: Value(id),
      name: Value(name),
      isMain: Value(isMain),
      isVisible: Value(isVisible),
      halfLifeHours: halfLifeHours == null && nullToAbsent
          ? const Value.absent()
          : Value(halfLifeHours),
      unit: Value(unit),
      color: Value(color),
      sortOrder: Value(sortOrder),
      decayModel: Value(decayModel),
      eliminationRate: eliminationRate == null && nullToAbsent
          ? const Value.absent()
          : Value(eliminationRate),
    );
  }

  factory Trackable.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Trackable(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      isMain: serializer.fromJson<bool>(json['isMain']),
      isVisible: serializer.fromJson<bool>(json['isVisible']),
      halfLifeHours: serializer.fromJson<double?>(json['halfLifeHours']),
      unit: serializer.fromJson<String>(json['unit']),
      color: serializer.fromJson<int>(json['color']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      decayModel: serializer.fromJson<String>(json['decayModel']),
      eliminationRate: serializer.fromJson<double?>(json['eliminationRate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'isMain': serializer.toJson<bool>(isMain),
      'isVisible': serializer.toJson<bool>(isVisible),
      'halfLifeHours': serializer.toJson<double?>(halfLifeHours),
      'unit': serializer.toJson<String>(unit),
      'color': serializer.toJson<int>(color),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'decayModel': serializer.toJson<String>(decayModel),
      'eliminationRate': serializer.toJson<double?>(eliminationRate),
    };
  }

  Trackable copyWith({
    int? id,
    String? name,
    bool? isMain,
    bool? isVisible,
    Value<double?> halfLifeHours = const Value.absent(),
    String? unit,
    int? color,
    int? sortOrder,
    String? decayModel,
    Value<double?> eliminationRate = const Value.absent(),
  }) => Trackable(
    id: id ?? this.id,
    name: name ?? this.name,
    isMain: isMain ?? this.isMain,
    isVisible: isVisible ?? this.isVisible,
    halfLifeHours: halfLifeHours.present
        ? halfLifeHours.value
        : this.halfLifeHours,
    unit: unit ?? this.unit,
    color: color ?? this.color,
    sortOrder: sortOrder ?? this.sortOrder,
    decayModel: decayModel ?? this.decayModel,
    eliminationRate: eliminationRate.present
        ? eliminationRate.value
        : this.eliminationRate,
  );
  Trackable copyWithCompanion(TrackablesCompanion data) {
    return Trackable(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      isMain: data.isMain.present ? data.isMain.value : this.isMain,
      isVisible: data.isVisible.present ? data.isVisible.value : this.isVisible,
      halfLifeHours: data.halfLifeHours.present
          ? data.halfLifeHours.value
          : this.halfLifeHours,
      unit: data.unit.present ? data.unit.value : this.unit,
      color: data.color.present ? data.color.value : this.color,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      decayModel: data.decayModel.present
          ? data.decayModel.value
          : this.decayModel,
      eliminationRate: data.eliminationRate.present
          ? data.eliminationRate.value
          : this.eliminationRate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Trackable(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('isMain: $isMain, ')
          ..write('isVisible: $isVisible, ')
          ..write('halfLifeHours: $halfLifeHours, ')
          ..write('unit: $unit, ')
          ..write('color: $color, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('decayModel: $decayModel, ')
          ..write('eliminationRate: $eliminationRate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    isMain,
    isVisible,
    halfLifeHours,
    unit,
    color,
    sortOrder,
    decayModel,
    eliminationRate,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Trackable &&
          other.id == this.id &&
          other.name == this.name &&
          other.isMain == this.isMain &&
          other.isVisible == this.isVisible &&
          other.halfLifeHours == this.halfLifeHours &&
          other.unit == this.unit &&
          other.color == this.color &&
          other.sortOrder == this.sortOrder &&
          other.decayModel == this.decayModel &&
          other.eliminationRate == this.eliminationRate);
}

class TrackablesCompanion extends UpdateCompanion<Trackable> {
  final Value<int> id;
  final Value<String> name;
  final Value<bool> isMain;
  final Value<bool> isVisible;
  final Value<double?> halfLifeHours;
  final Value<String> unit;
  final Value<int> color;
  final Value<int> sortOrder;
  final Value<String> decayModel;
  final Value<double?> eliminationRate;
  const TrackablesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.isMain = const Value.absent(),
    this.isVisible = const Value.absent(),
    this.halfLifeHours = const Value.absent(),
    this.unit = const Value.absent(),
    this.color = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.decayModel = const Value.absent(),
    this.eliminationRate = const Value.absent(),
  });
  TrackablesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.isMain = const Value.absent(),
    this.isVisible = const Value.absent(),
    this.halfLifeHours = const Value.absent(),
    this.unit = const Value.absent(),
    required int color,
    this.sortOrder = const Value.absent(),
    this.decayModel = const Value.absent(),
    this.eliminationRate = const Value.absent(),
  }) : name = Value(name),
       color = Value(color);
  static Insertable<Trackable> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<bool>? isMain,
    Expression<bool>? isVisible,
    Expression<double>? halfLifeHours,
    Expression<String>? unit,
    Expression<int>? color,
    Expression<int>? sortOrder,
    Expression<String>? decayModel,
    Expression<double>? eliminationRate,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (isMain != null) 'is_main': isMain,
      if (isVisible != null) 'is_visible': isVisible,
      if (halfLifeHours != null) 'half_life_hours': halfLifeHours,
      if (unit != null) 'unit': unit,
      if (color != null) 'color': color,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (decayModel != null) 'decay_model': decayModel,
      if (eliminationRate != null) 'elimination_rate': eliminationRate,
    });
  }

  TrackablesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<bool>? isMain,
    Value<bool>? isVisible,
    Value<double?>? halfLifeHours,
    Value<String>? unit,
    Value<int>? color,
    Value<int>? sortOrder,
    Value<String>? decayModel,
    Value<double?>? eliminationRate,
  }) {
    return TrackablesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      isMain: isMain ?? this.isMain,
      isVisible: isVisible ?? this.isVisible,
      halfLifeHours: halfLifeHours ?? this.halfLifeHours,
      unit: unit ?? this.unit,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      decayModel: decayModel ?? this.decayModel,
      eliminationRate: eliminationRate ?? this.eliminationRate,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isMain.present) {
      map['is_main'] = Variable<bool>(isMain.value);
    }
    if (isVisible.present) {
      map['is_visible'] = Variable<bool>(isVisible.value);
    }
    if (halfLifeHours.present) {
      map['half_life_hours'] = Variable<double>(halfLifeHours.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (decayModel.present) {
      map['decay_model'] = Variable<String>(decayModel.value);
    }
    if (eliminationRate.present) {
      map['elimination_rate'] = Variable<double>(eliminationRate.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrackablesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('isMain: $isMain, ')
          ..write('isVisible: $isVisible, ')
          ..write('halfLifeHours: $halfLifeHours, ')
          ..write('unit: $unit, ')
          ..write('color: $color, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('decayModel: $decayModel, ')
          ..write('eliminationRate: $eliminationRate')
          ..write(')'))
        .toString();
  }
}

class $DoseLogsTable extends DoseLogs with TableInfo<$DoseLogsTable, DoseLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DoseLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _trackableIdMeta = const VerificationMeta(
    'trackableId',
  );
  @override
  late final GeneratedColumn<int> trackableId = GeneratedColumn<int>(
    'trackable_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES trackables (id)',
    ),
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _loggedAtMeta = const VerificationMeta(
    'loggedAt',
  );
  @override
  late final GeneratedColumn<DateTime> loggedAt = GeneratedColumn<DateTime>(
    'logged_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, trackableId, amount, loggedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dose_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<DoseLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('trackable_id')) {
      context.handle(
        _trackableIdMeta,
        trackableId.isAcceptableOrUnknown(
          data['trackable_id']!,
          _trackableIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_trackableIdMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('logged_at')) {
      context.handle(
        _loggedAtMeta,
        loggedAt.isAcceptableOrUnknown(data['logged_at']!, _loggedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_loggedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DoseLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DoseLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      trackableId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trackable_id'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
      loggedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}logged_at'],
      )!,
    );
  }

  @override
  $DoseLogsTable createAlias(String alias) {
    return $DoseLogsTable(attachedDatabase, alias);
  }
}

class DoseLog extends DataClass implements Insertable<DoseLog> {
  final int id;
  final int trackableId;
  final double amount;
  final DateTime loggedAt;
  const DoseLog({
    required this.id,
    required this.trackableId,
    required this.amount,
    required this.loggedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['trackable_id'] = Variable<int>(trackableId);
    map['amount'] = Variable<double>(amount);
    map['logged_at'] = Variable<DateTime>(loggedAt);
    return map;
  }

  DoseLogsCompanion toCompanion(bool nullToAbsent) {
    return DoseLogsCompanion(
      id: Value(id),
      trackableId: Value(trackableId),
      amount: Value(amount),
      loggedAt: Value(loggedAt),
    );
  }

  factory DoseLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DoseLog(
      id: serializer.fromJson<int>(json['id']),
      trackableId: serializer.fromJson<int>(json['trackableId']),
      amount: serializer.fromJson<double>(json['amount']),
      loggedAt: serializer.fromJson<DateTime>(json['loggedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trackableId': serializer.toJson<int>(trackableId),
      'amount': serializer.toJson<double>(amount),
      'loggedAt': serializer.toJson<DateTime>(loggedAt),
    };
  }

  DoseLog copyWith({
    int? id,
    int? trackableId,
    double? amount,
    DateTime? loggedAt,
  }) => DoseLog(
    id: id ?? this.id,
    trackableId: trackableId ?? this.trackableId,
    amount: amount ?? this.amount,
    loggedAt: loggedAt ?? this.loggedAt,
  );
  DoseLog copyWithCompanion(DoseLogsCompanion data) {
    return DoseLog(
      id: data.id.present ? data.id.value : this.id,
      trackableId: data.trackableId.present
          ? data.trackableId.value
          : this.trackableId,
      amount: data.amount.present ? data.amount.value : this.amount,
      loggedAt: data.loggedAt.present ? data.loggedAt.value : this.loggedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DoseLog(')
          ..write('id: $id, ')
          ..write('trackableId: $trackableId, ')
          ..write('amount: $amount, ')
          ..write('loggedAt: $loggedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, trackableId, amount, loggedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DoseLog &&
          other.id == this.id &&
          other.trackableId == this.trackableId &&
          other.amount == this.amount &&
          other.loggedAt == this.loggedAt);
}

class DoseLogsCompanion extends UpdateCompanion<DoseLog> {
  final Value<int> id;
  final Value<int> trackableId;
  final Value<double> amount;
  final Value<DateTime> loggedAt;
  const DoseLogsCompanion({
    this.id = const Value.absent(),
    this.trackableId = const Value.absent(),
    this.amount = const Value.absent(),
    this.loggedAt = const Value.absent(),
  });
  DoseLogsCompanion.insert({
    this.id = const Value.absent(),
    required int trackableId,
    required double amount,
    required DateTime loggedAt,
  }) : trackableId = Value(trackableId),
       amount = Value(amount),
       loggedAt = Value(loggedAt);
  static Insertable<DoseLog> custom({
    Expression<int>? id,
    Expression<int>? trackableId,
    Expression<double>? amount,
    Expression<DateTime>? loggedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trackableId != null) 'trackable_id': trackableId,
      if (amount != null) 'amount': amount,
      if (loggedAt != null) 'logged_at': loggedAt,
    });
  }

  DoseLogsCompanion copyWith({
    Value<int>? id,
    Value<int>? trackableId,
    Value<double>? amount,
    Value<DateTime>? loggedAt,
  }) {
    return DoseLogsCompanion(
      id: id ?? this.id,
      trackableId: trackableId ?? this.trackableId,
      amount: amount ?? this.amount,
      loggedAt: loggedAt ?? this.loggedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (trackableId.present) {
      map['trackable_id'] = Variable<int>(trackableId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (loggedAt.present) {
      map['logged_at'] = Variable<DateTime>(loggedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DoseLogsCompanion(')
          ..write('id: $id, ')
          ..write('trackableId: $trackableId, ')
          ..write('amount: $amount, ')
          ..write('loggedAt: $loggedAt')
          ..write(')'))
        .toString();
  }
}

class $PresetsTable extends Presets with TableInfo<$PresetsTable, Preset> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PresetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _trackableIdMeta = const VerificationMeta(
    'trackableId',
  );
  @override
  late final GeneratedColumn<int> trackableId = GeneratedColumn<int>(
    'trackable_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES trackables (id)',
    ),
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
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    trackableId,
    name,
    amount,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'presets';
  @override
  VerificationContext validateIntegrity(
    Insertable<Preset> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('trackable_id')) {
      context.handle(
        _trackableIdMeta,
        trackableId.isAcceptableOrUnknown(
          data['trackable_id']!,
          _trackableIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_trackableIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Preset map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Preset(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      trackableId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trackable_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $PresetsTable createAlias(String alias) {
    return $PresetsTable(attachedDatabase, alias);
  }
}

class Preset extends DataClass implements Insertable<Preset> {
  final int id;
  final int trackableId;
  final String name;
  final double amount;
  final int sortOrder;
  const Preset({
    required this.id,
    required this.trackableId,
    required this.name,
    required this.amount,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['trackable_id'] = Variable<int>(trackableId);
    map['name'] = Variable<String>(name);
    map['amount'] = Variable<double>(amount);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  PresetsCompanion toCompanion(bool nullToAbsent) {
    return PresetsCompanion(
      id: Value(id),
      trackableId: Value(trackableId),
      name: Value(name),
      amount: Value(amount),
      sortOrder: Value(sortOrder),
    );
  }

  factory Preset.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Preset(
      id: serializer.fromJson<int>(json['id']),
      trackableId: serializer.fromJson<int>(json['trackableId']),
      name: serializer.fromJson<String>(json['name']),
      amount: serializer.fromJson<double>(json['amount']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trackableId': serializer.toJson<int>(trackableId),
      'name': serializer.toJson<String>(name),
      'amount': serializer.toJson<double>(amount),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  Preset copyWith({
    int? id,
    int? trackableId,
    String? name,
    double? amount,
    int? sortOrder,
  }) => Preset(
    id: id ?? this.id,
    trackableId: trackableId ?? this.trackableId,
    name: name ?? this.name,
    amount: amount ?? this.amount,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  Preset copyWithCompanion(PresetsCompanion data) {
    return Preset(
      id: data.id.present ? data.id.value : this.id,
      trackableId: data.trackableId.present
          ? data.trackableId.value
          : this.trackableId,
      name: data.name.present ? data.name.value : this.name,
      amount: data.amount.present ? data.amount.value : this.amount,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Preset(')
          ..write('id: $id, ')
          ..write('trackableId: $trackableId, ')
          ..write('name: $name, ')
          ..write('amount: $amount, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, trackableId, name, amount, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Preset &&
          other.id == this.id &&
          other.trackableId == this.trackableId &&
          other.name == this.name &&
          other.amount == this.amount &&
          other.sortOrder == this.sortOrder);
}

class PresetsCompanion extends UpdateCompanion<Preset> {
  final Value<int> id;
  final Value<int> trackableId;
  final Value<String> name;
  final Value<double> amount;
  final Value<int> sortOrder;
  const PresetsCompanion({
    this.id = const Value.absent(),
    this.trackableId = const Value.absent(),
    this.name = const Value.absent(),
    this.amount = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  PresetsCompanion.insert({
    this.id = const Value.absent(),
    required int trackableId,
    required String name,
    required double amount,
    this.sortOrder = const Value.absent(),
  }) : trackableId = Value(trackableId),
       name = Value(name),
       amount = Value(amount);
  static Insertable<Preset> custom({
    Expression<int>? id,
    Expression<int>? trackableId,
    Expression<String>? name,
    Expression<double>? amount,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trackableId != null) 'trackable_id': trackableId,
      if (name != null) 'name': name,
      if (amount != null) 'amount': amount,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  PresetsCompanion copyWith({
    Value<int>? id,
    Value<int>? trackableId,
    Value<String>? name,
    Value<double>? amount,
    Value<int>? sortOrder,
  }) {
    return PresetsCompanion(
      id: id ?? this.id,
      trackableId: trackableId ?? this.trackableId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (trackableId.present) {
      map['trackable_id'] = Variable<int>(trackableId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PresetsCompanion(')
          ..write('id: $id, ')
          ..write('trackableId: $trackableId, ')
          ..write('name: $name, ')
          ..write('amount: $amount, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TrackablesTable trackables = $TrackablesTable(this);
  late final $DoseLogsTable doseLogs = $DoseLogsTable(this);
  late final $PresetsTable presets = $PresetsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    trackables,
    doseLogs,
    presets,
  ];
}

typedef $$TrackablesTableCreateCompanionBuilder =
    TrackablesCompanion Function({
      Value<int> id,
      required String name,
      Value<bool> isMain,
      Value<bool> isVisible,
      Value<double?> halfLifeHours,
      Value<String> unit,
      required int color,
      Value<int> sortOrder,
      Value<String> decayModel,
      Value<double?> eliminationRate,
    });
typedef $$TrackablesTableUpdateCompanionBuilder =
    TrackablesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<bool> isMain,
      Value<bool> isVisible,
      Value<double?> halfLifeHours,
      Value<String> unit,
      Value<int> color,
      Value<int> sortOrder,
      Value<String> decayModel,
      Value<double?> eliminationRate,
    });

final class $$TrackablesTableReferences
    extends BaseReferences<_$AppDatabase, $TrackablesTable, Trackable> {
  $$TrackablesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$DoseLogsTable, List<DoseLog>> _doseLogsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.doseLogs,
    aliasName: $_aliasNameGenerator(db.trackables.id, db.doseLogs.trackableId),
  );

  $$DoseLogsTableProcessedTableManager get doseLogsRefs {
    final manager = $$DoseLogsTableTableManager(
      $_db,
      $_db.doseLogs,
    ).filter((f) => f.trackableId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_doseLogsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PresetsTable, List<Preset>> _presetsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.presets,
    aliasName: $_aliasNameGenerator(db.trackables.id, db.presets.trackableId),
  );

  $$PresetsTableProcessedTableManager get presetsRefs {
    final manager = $$PresetsTableTableManager(
      $_db,
      $_db.presets,
    ).filter((f) => f.trackableId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_presetsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TrackablesTableFilterComposer
    extends Composer<_$AppDatabase, $TrackablesTable> {
  $$TrackablesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isMain => $composableBuilder(
    column: $table.isMain,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isVisible => $composableBuilder(
    column: $table.isVisible,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get halfLifeHours => $composableBuilder(
    column: $table.halfLifeHours,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get decayModel => $composableBuilder(
    column: $table.decayModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get eliminationRate => $composableBuilder(
    column: $table.eliminationRate,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> doseLogsRefs(
    Expression<bool> Function($$DoseLogsTableFilterComposer f) f,
  ) {
    final $$DoseLogsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.doseLogs,
      getReferencedColumn: (t) => t.trackableId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DoseLogsTableFilterComposer(
            $db: $db,
            $table: $db.doseLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> presetsRefs(
    Expression<bool> Function($$PresetsTableFilterComposer f) f,
  ) {
    final $$PresetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.presets,
      getReferencedColumn: (t) => t.trackableId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PresetsTableFilterComposer(
            $db: $db,
            $table: $db.presets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TrackablesTableOrderingComposer
    extends Composer<_$AppDatabase, $TrackablesTable> {
  $$TrackablesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isMain => $composableBuilder(
    column: $table.isMain,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isVisible => $composableBuilder(
    column: $table.isVisible,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get halfLifeHours => $composableBuilder(
    column: $table.halfLifeHours,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get decayModel => $composableBuilder(
    column: $table.decayModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get eliminationRate => $composableBuilder(
    column: $table.eliminationRate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TrackablesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrackablesTable> {
  $$TrackablesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isMain =>
      $composableBuilder(column: $table.isMain, builder: (column) => column);

  GeneratedColumn<bool> get isVisible =>
      $composableBuilder(column: $table.isVisible, builder: (column) => column);

  GeneratedColumn<double> get halfLifeHours => $composableBuilder(
    column: $table.halfLifeHours,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get decayModel => $composableBuilder(
    column: $table.decayModel,
    builder: (column) => column,
  );

  GeneratedColumn<double> get eliminationRate => $composableBuilder(
    column: $table.eliminationRate,
    builder: (column) => column,
  );

  Expression<T> doseLogsRefs<T extends Object>(
    Expression<T> Function($$DoseLogsTableAnnotationComposer a) f,
  ) {
    final $$DoseLogsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.doseLogs,
      getReferencedColumn: (t) => t.trackableId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DoseLogsTableAnnotationComposer(
            $db: $db,
            $table: $db.doseLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> presetsRefs<T extends Object>(
    Expression<T> Function($$PresetsTableAnnotationComposer a) f,
  ) {
    final $$PresetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.presets,
      getReferencedColumn: (t) => t.trackableId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PresetsTableAnnotationComposer(
            $db: $db,
            $table: $db.presets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TrackablesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TrackablesTable,
          Trackable,
          $$TrackablesTableFilterComposer,
          $$TrackablesTableOrderingComposer,
          $$TrackablesTableAnnotationComposer,
          $$TrackablesTableCreateCompanionBuilder,
          $$TrackablesTableUpdateCompanionBuilder,
          (Trackable, $$TrackablesTableReferences),
          Trackable,
          PrefetchHooks Function({bool doseLogsRefs, bool presetsRefs})
        > {
  $$TrackablesTableTableManager(_$AppDatabase db, $TrackablesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrackablesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrackablesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrackablesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> isMain = const Value.absent(),
                Value<bool> isVisible = const Value.absent(),
                Value<double?> halfLifeHours = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> decayModel = const Value.absent(),
                Value<double?> eliminationRate = const Value.absent(),
              }) => TrackablesCompanion(
                id: id,
                name: name,
                isMain: isMain,
                isVisible: isVisible,
                halfLifeHours: halfLifeHours,
                unit: unit,
                color: color,
                sortOrder: sortOrder,
                decayModel: decayModel,
                eliminationRate: eliminationRate,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<bool> isMain = const Value.absent(),
                Value<bool> isVisible = const Value.absent(),
                Value<double?> halfLifeHours = const Value.absent(),
                Value<String> unit = const Value.absent(),
                required int color,
                Value<int> sortOrder = const Value.absent(),
                Value<String> decayModel = const Value.absent(),
                Value<double?> eliminationRate = const Value.absent(),
              }) => TrackablesCompanion.insert(
                id: id,
                name: name,
                isMain: isMain,
                isVisible: isVisible,
                halfLifeHours: halfLifeHours,
                unit: unit,
                color: color,
                sortOrder: sortOrder,
                decayModel: decayModel,
                eliminationRate: eliminationRate,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TrackablesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({doseLogsRefs = false, presetsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (doseLogsRefs) db.doseLogs,
                if (presetsRefs) db.presets,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (doseLogsRefs)
                    await $_getPrefetchedData<
                      Trackable,
                      $TrackablesTable,
                      DoseLog
                    >(
                      currentTable: table,
                      referencedTable: $$TrackablesTableReferences
                          ._doseLogsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TrackablesTableReferences(
                            db,
                            table,
                            p0,
                          ).doseLogsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.trackableId == item.id,
                          ),
                      typedResults: items,
                    ),
                  if (presetsRefs)
                    await $_getPrefetchedData<
                      Trackable,
                      $TrackablesTable,
                      Preset
                    >(
                      currentTable: table,
                      referencedTable: $$TrackablesTableReferences
                          ._presetsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TrackablesTableReferences(
                            db,
                            table,
                            p0,
                          ).presetsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.trackableId == item.id,
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

typedef $$TrackablesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TrackablesTable,
      Trackable,
      $$TrackablesTableFilterComposer,
      $$TrackablesTableOrderingComposer,
      $$TrackablesTableAnnotationComposer,
      $$TrackablesTableCreateCompanionBuilder,
      $$TrackablesTableUpdateCompanionBuilder,
      (Trackable, $$TrackablesTableReferences),
      Trackable,
      PrefetchHooks Function({bool doseLogsRefs, bool presetsRefs})
    >;
typedef $$DoseLogsTableCreateCompanionBuilder =
    DoseLogsCompanion Function({
      Value<int> id,
      required int trackableId,
      required double amount,
      required DateTime loggedAt,
    });
typedef $$DoseLogsTableUpdateCompanionBuilder =
    DoseLogsCompanion Function({
      Value<int> id,
      Value<int> trackableId,
      Value<double> amount,
      Value<DateTime> loggedAt,
    });

final class $$DoseLogsTableReferences
    extends BaseReferences<_$AppDatabase, $DoseLogsTable, DoseLog> {
  $$DoseLogsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TrackablesTable _trackableIdTable(_$AppDatabase db) =>
      db.trackables.createAlias(
        $_aliasNameGenerator(db.doseLogs.trackableId, db.trackables.id),
      );

  $$TrackablesTableProcessedTableManager get trackableId {
    final $_column = $_itemColumn<int>('trackable_id')!;

    final manager = $$TrackablesTableTableManager(
      $_db,
      $_db.trackables,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackableIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DoseLogsTableFilterComposer
    extends Composer<_$AppDatabase, $DoseLogsTable> {
  $$DoseLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get loggedAt => $composableBuilder(
    column: $table.loggedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TrackablesTableFilterComposer get trackableId {
    final $$TrackablesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackableId,
      referencedTable: $db.trackables,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackablesTableFilterComposer(
            $db: $db,
            $table: $db.trackables,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DoseLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $DoseLogsTable> {
  $$DoseLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get loggedAt => $composableBuilder(
    column: $table.loggedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TrackablesTableOrderingComposer get trackableId {
    final $$TrackablesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackableId,
      referencedTable: $db.trackables,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackablesTableOrderingComposer(
            $db: $db,
            $table: $db.trackables,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DoseLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DoseLogsTable> {
  $$DoseLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<DateTime> get loggedAt =>
      $composableBuilder(column: $table.loggedAt, builder: (column) => column);

  $$TrackablesTableAnnotationComposer get trackableId {
    final $$TrackablesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackableId,
      referencedTable: $db.trackables,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackablesTableAnnotationComposer(
            $db: $db,
            $table: $db.trackables,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DoseLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DoseLogsTable,
          DoseLog,
          $$DoseLogsTableFilterComposer,
          $$DoseLogsTableOrderingComposer,
          $$DoseLogsTableAnnotationComposer,
          $$DoseLogsTableCreateCompanionBuilder,
          $$DoseLogsTableUpdateCompanionBuilder,
          (DoseLog, $$DoseLogsTableReferences),
          DoseLog,
          PrefetchHooks Function({bool trackableId})
        > {
  $$DoseLogsTableTableManager(_$AppDatabase db, $DoseLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DoseLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DoseLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DoseLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> trackableId = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<DateTime> loggedAt = const Value.absent(),
              }) => DoseLogsCompanion(
                id: id,
                trackableId: trackableId,
                amount: amount,
                loggedAt: loggedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int trackableId,
                required double amount,
                required DateTime loggedAt,
              }) => DoseLogsCompanion.insert(
                id: id,
                trackableId: trackableId,
                amount: amount,
                loggedAt: loggedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DoseLogsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackableId = false}) {
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
                    if (trackableId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.trackableId,
                                referencedTable: $$DoseLogsTableReferences
                                    ._trackableIdTable(db),
                                referencedColumn: $$DoseLogsTableReferences
                                    ._trackableIdTable(db)
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

typedef $$DoseLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DoseLogsTable,
      DoseLog,
      $$DoseLogsTableFilterComposer,
      $$DoseLogsTableOrderingComposer,
      $$DoseLogsTableAnnotationComposer,
      $$DoseLogsTableCreateCompanionBuilder,
      $$DoseLogsTableUpdateCompanionBuilder,
      (DoseLog, $$DoseLogsTableReferences),
      DoseLog,
      PrefetchHooks Function({bool trackableId})
    >;
typedef $$PresetsTableCreateCompanionBuilder =
    PresetsCompanion Function({
      Value<int> id,
      required int trackableId,
      required String name,
      required double amount,
      Value<int> sortOrder,
    });
typedef $$PresetsTableUpdateCompanionBuilder =
    PresetsCompanion Function({
      Value<int> id,
      Value<int> trackableId,
      Value<String> name,
      Value<double> amount,
      Value<int> sortOrder,
    });

final class $$PresetsTableReferences
    extends BaseReferences<_$AppDatabase, $PresetsTable, Preset> {
  $$PresetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TrackablesTable _trackableIdTable(_$AppDatabase db) =>
      db.trackables.createAlias(
        $_aliasNameGenerator(db.presets.trackableId, db.trackables.id),
      );

  $$TrackablesTableProcessedTableManager get trackableId {
    final $_column = $_itemColumn<int>('trackable_id')!;

    final manager = $$TrackablesTableTableManager(
      $_db,
      $_db.trackables,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackableIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PresetsTableFilterComposer
    extends Composer<_$AppDatabase, $PresetsTable> {
  $$PresetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$TrackablesTableFilterComposer get trackableId {
    final $$TrackablesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackableId,
      referencedTable: $db.trackables,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackablesTableFilterComposer(
            $db: $db,
            $table: $db.trackables,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PresetsTableOrderingComposer
    extends Composer<_$AppDatabase, $PresetsTable> {
  $$PresetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$TrackablesTableOrderingComposer get trackableId {
    final $$TrackablesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackableId,
      referencedTable: $db.trackables,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackablesTableOrderingComposer(
            $db: $db,
            $table: $db.trackables,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PresetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PresetsTable> {
  $$PresetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$TrackablesTableAnnotationComposer get trackableId {
    final $$TrackablesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackableId,
      referencedTable: $db.trackables,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackablesTableAnnotationComposer(
            $db: $db,
            $table: $db.trackables,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PresetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PresetsTable,
          Preset,
          $$PresetsTableFilterComposer,
          $$PresetsTableOrderingComposer,
          $$PresetsTableAnnotationComposer,
          $$PresetsTableCreateCompanionBuilder,
          $$PresetsTableUpdateCompanionBuilder,
          (Preset, $$PresetsTableReferences),
          Preset,
          PrefetchHooks Function({bool trackableId})
        > {
  $$PresetsTableTableManager(_$AppDatabase db, $PresetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PresetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PresetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PresetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> trackableId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => PresetsCompanion(
                id: id,
                trackableId: trackableId,
                name: name,
                amount: amount,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int trackableId,
                required String name,
                required double amount,
                Value<int> sortOrder = const Value.absent(),
              }) => PresetsCompanion.insert(
                id: id,
                trackableId: trackableId,
                name: name,
                amount: amount,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PresetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackableId = false}) {
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
                    if (trackableId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.trackableId,
                                referencedTable: $$PresetsTableReferences
                                    ._trackableIdTable(db),
                                referencedColumn: $$PresetsTableReferences
                                    ._trackableIdTable(db)
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

typedef $$PresetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PresetsTable,
      Preset,
      $$PresetsTableFilterComposer,
      $$PresetsTableOrderingComposer,
      $$PresetsTableAnnotationComposer,
      $$PresetsTableCreateCompanionBuilder,
      $$PresetsTableUpdateCompanionBuilder,
      (Preset, $$PresetsTableReferences),
      Preset,
      PrefetchHooks Function({bool trackableId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TrackablesTableTableManager get trackables =>
      $$TrackablesTableTableManager(_db, _db.trackables);
  $$DoseLogsTableTableManager get doseLogs =>
      $$DoseLogsTableTableManager(_db, _db.doseLogs);
  $$PresetsTableTableManager get presets =>
      $$PresetsTableTableManager(_db, _db.presets);
}
