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
  static const VerificationMeta _absorptionMinutesMeta = const VerificationMeta(
    'absorptionMinutes',
  );
  @override
  late final GeneratedColumn<double> absorptionMinutes =
      GeneratedColumn<double>(
        'absorption_minutes',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _showCumulativeLineMeta =
      const VerificationMeta('showCumulativeLine');
  @override
  late final GeneratedColumn<bool> showCumulativeLine = GeneratedColumn<bool>(
    'show_cumulative_line',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_cumulative_line" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    absorptionMinutes,
    showCumulativeLine,
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
    if (data.containsKey('absorption_minutes')) {
      context.handle(
        _absorptionMinutesMeta,
        absorptionMinutes.isAcceptableOrUnknown(
          data['absorption_minutes']!,
          _absorptionMinutesMeta,
        ),
      );
    }
    if (data.containsKey('show_cumulative_line')) {
      context.handle(
        _showCumulativeLineMeta,
        showCumulativeLine.isAcceptableOrUnknown(
          data['show_cumulative_line']!,
          _showCumulativeLineMeta,
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
      absorptionMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}absorption_minutes'],
      ),
      showCumulativeLine: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_cumulative_line'],
      )!,
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
  final double? absorptionMinutes;
  final bool showCumulativeLine;
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
    this.absorptionMinutes,
    required this.showCumulativeLine,
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
    if (!nullToAbsent || absorptionMinutes != null) {
      map['absorption_minutes'] = Variable<double>(absorptionMinutes);
    }
    map['show_cumulative_line'] = Variable<bool>(showCumulativeLine);
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
      absorptionMinutes: absorptionMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(absorptionMinutes),
      showCumulativeLine: Value(showCumulativeLine),
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
      absorptionMinutes: serializer.fromJson<double?>(
        json['absorptionMinutes'],
      ),
      showCumulativeLine: serializer.fromJson<bool>(json['showCumulativeLine']),
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
      'absorptionMinutes': serializer.toJson<double?>(absorptionMinutes),
      'showCumulativeLine': serializer.toJson<bool>(showCumulativeLine),
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
    Value<double?> absorptionMinutes = const Value.absent(),
    bool? showCumulativeLine,
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
    absorptionMinutes: absorptionMinutes.present
        ? absorptionMinutes.value
        : this.absorptionMinutes,
    showCumulativeLine: showCumulativeLine ?? this.showCumulativeLine,
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
      absorptionMinutes: data.absorptionMinutes.present
          ? data.absorptionMinutes.value
          : this.absorptionMinutes,
      showCumulativeLine: data.showCumulativeLine.present
          ? data.showCumulativeLine.value
          : this.showCumulativeLine,
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
          ..write('eliminationRate: $eliminationRate, ')
          ..write('absorptionMinutes: $absorptionMinutes, ')
          ..write('showCumulativeLine: $showCumulativeLine')
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
    absorptionMinutes,
    showCumulativeLine,
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
          other.eliminationRate == this.eliminationRate &&
          other.absorptionMinutes == this.absorptionMinutes &&
          other.showCumulativeLine == this.showCumulativeLine);
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
  final Value<double?> absorptionMinutes;
  final Value<bool> showCumulativeLine;
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
    this.absorptionMinutes = const Value.absent(),
    this.showCumulativeLine = const Value.absent(),
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
    this.absorptionMinutes = const Value.absent(),
    this.showCumulativeLine = const Value.absent(),
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
    Expression<double>? absorptionMinutes,
    Expression<bool>? showCumulativeLine,
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
      if (absorptionMinutes != null) 'absorption_minutes': absorptionMinutes,
      if (showCumulativeLine != null)
        'show_cumulative_line': showCumulativeLine,
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
    Value<double?>? absorptionMinutes,
    Value<bool>? showCumulativeLine,
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
      absorptionMinutes: absorptionMinutes ?? this.absorptionMinutes,
      showCumulativeLine: showCumulativeLine ?? this.showCumulativeLine,
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
    if (absorptionMinutes.present) {
      map['absorption_minutes'] = Variable<double>(absorptionMinutes.value);
    }
    if (showCumulativeLine.present) {
      map['show_cumulative_line'] = Variable<bool>(showCumulativeLine.value);
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
          ..write('eliminationRate: $eliminationRate, ')
          ..write('absorptionMinutes: $absorptionMinutes, ')
          ..write('showCumulativeLine: $showCumulativeLine')
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    trackableId,
    amount,
    loggedAt,
    name,
  ];
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
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
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
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
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
  final String? name;
  const DoseLog({
    required this.id,
    required this.trackableId,
    required this.amount,
    required this.loggedAt,
    this.name,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['trackable_id'] = Variable<int>(trackableId);
    map['amount'] = Variable<double>(amount);
    map['logged_at'] = Variable<DateTime>(loggedAt);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    return map;
  }

  DoseLogsCompanion toCompanion(bool nullToAbsent) {
    return DoseLogsCompanion(
      id: Value(id),
      trackableId: Value(trackableId),
      amount: Value(amount),
      loggedAt: Value(loggedAt),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
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
      name: serializer.fromJson<String?>(json['name']),
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
      'name': serializer.toJson<String?>(name),
    };
  }

  DoseLog copyWith({
    int? id,
    int? trackableId,
    double? amount,
    DateTime? loggedAt,
    Value<String?> name = const Value.absent(),
  }) => DoseLog(
    id: id ?? this.id,
    trackableId: trackableId ?? this.trackableId,
    amount: amount ?? this.amount,
    loggedAt: loggedAt ?? this.loggedAt,
    name: name.present ? name.value : this.name,
  );
  DoseLog copyWithCompanion(DoseLogsCompanion data) {
    return DoseLog(
      id: data.id.present ? data.id.value : this.id,
      trackableId: data.trackableId.present
          ? data.trackableId.value
          : this.trackableId,
      amount: data.amount.present ? data.amount.value : this.amount,
      loggedAt: data.loggedAt.present ? data.loggedAt.value : this.loggedAt,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DoseLog(')
          ..write('id: $id, ')
          ..write('trackableId: $trackableId, ')
          ..write('amount: $amount, ')
          ..write('loggedAt: $loggedAt, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, trackableId, amount, loggedAt, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DoseLog &&
          other.id == this.id &&
          other.trackableId == this.trackableId &&
          other.amount == this.amount &&
          other.loggedAt == this.loggedAt &&
          other.name == this.name);
}

class DoseLogsCompanion extends UpdateCompanion<DoseLog> {
  final Value<int> id;
  final Value<int> trackableId;
  final Value<double> amount;
  final Value<DateTime> loggedAt;
  final Value<String?> name;
  const DoseLogsCompanion({
    this.id = const Value.absent(),
    this.trackableId = const Value.absent(),
    this.amount = const Value.absent(),
    this.loggedAt = const Value.absent(),
    this.name = const Value.absent(),
  });
  DoseLogsCompanion.insert({
    this.id = const Value.absent(),
    required int trackableId,
    required double amount,
    required DateTime loggedAt,
    this.name = const Value.absent(),
  }) : trackableId = Value(trackableId),
       amount = Value(amount),
       loggedAt = Value(loggedAt);
  static Insertable<DoseLog> custom({
    Expression<int>? id,
    Expression<int>? trackableId,
    Expression<double>? amount,
    Expression<DateTime>? loggedAt,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trackableId != null) 'trackable_id': trackableId,
      if (amount != null) 'amount': amount,
      if (loggedAt != null) 'logged_at': loggedAt,
      if (name != null) 'name': name,
    });
  }

  DoseLogsCompanion copyWith({
    Value<int>? id,
    Value<int>? trackableId,
    Value<double>? amount,
    Value<DateTime>? loggedAt,
    Value<String?>? name,
  }) {
    return DoseLogsCompanion(
      id: id ?? this.id,
      trackableId: trackableId ?? this.trackableId,
      amount: amount ?? this.amount,
      loggedAt: loggedAt ?? this.loggedAt,
      name: name ?? this.name,
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
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DoseLogsCompanion(')
          ..write('id: $id, ')
          ..write('trackableId: $trackableId, ')
          ..write('amount: $amount, ')
          ..write('loggedAt: $loggedAt, ')
          ..write('name: $name')
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

class $ThresholdsTable extends Thresholds
    with TableInfo<$ThresholdsTable, Threshold> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ThresholdsTable(this.attachedDatabase, [this._alias]);
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
  @override
  List<GeneratedColumn> get $columns => [id, trackableId, name, amount];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'thresholds';
  @override
  VerificationContext validateIntegrity(
    Insertable<Threshold> instance, {
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Threshold map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Threshold(
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
    );
  }

  @override
  $ThresholdsTable createAlias(String alias) {
    return $ThresholdsTable(attachedDatabase, alias);
  }
}

class Threshold extends DataClass implements Insertable<Threshold> {
  final int id;
  final int trackableId;
  final String name;
  final double amount;
  const Threshold({
    required this.id,
    required this.trackableId,
    required this.name,
    required this.amount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['trackable_id'] = Variable<int>(trackableId);
    map['name'] = Variable<String>(name);
    map['amount'] = Variable<double>(amount);
    return map;
  }

  ThresholdsCompanion toCompanion(bool nullToAbsent) {
    return ThresholdsCompanion(
      id: Value(id),
      trackableId: Value(trackableId),
      name: Value(name),
      amount: Value(amount),
    );
  }

  factory Threshold.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Threshold(
      id: serializer.fromJson<int>(json['id']),
      trackableId: serializer.fromJson<int>(json['trackableId']),
      name: serializer.fromJson<String>(json['name']),
      amount: serializer.fromJson<double>(json['amount']),
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
    };
  }

  Threshold copyWith({
    int? id,
    int? trackableId,
    String? name,
    double? amount,
  }) => Threshold(
    id: id ?? this.id,
    trackableId: trackableId ?? this.trackableId,
    name: name ?? this.name,
    amount: amount ?? this.amount,
  );
  Threshold copyWithCompanion(ThresholdsCompanion data) {
    return Threshold(
      id: data.id.present ? data.id.value : this.id,
      trackableId: data.trackableId.present
          ? data.trackableId.value
          : this.trackableId,
      name: data.name.present ? data.name.value : this.name,
      amount: data.amount.present ? data.amount.value : this.amount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Threshold(')
          ..write('id: $id, ')
          ..write('trackableId: $trackableId, ')
          ..write('name: $name, ')
          ..write('amount: $amount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, trackableId, name, amount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Threshold &&
          other.id == this.id &&
          other.trackableId == this.trackableId &&
          other.name == this.name &&
          other.amount == this.amount);
}

class ThresholdsCompanion extends UpdateCompanion<Threshold> {
  final Value<int> id;
  final Value<int> trackableId;
  final Value<String> name;
  final Value<double> amount;
  const ThresholdsCompanion({
    this.id = const Value.absent(),
    this.trackableId = const Value.absent(),
    this.name = const Value.absent(),
    this.amount = const Value.absent(),
  });
  ThresholdsCompanion.insert({
    this.id = const Value.absent(),
    required int trackableId,
    required String name,
    required double amount,
  }) : trackableId = Value(trackableId),
       name = Value(name),
       amount = Value(amount);
  static Insertable<Threshold> custom({
    Expression<int>? id,
    Expression<int>? trackableId,
    Expression<String>? name,
    Expression<double>? amount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trackableId != null) 'trackable_id': trackableId,
      if (name != null) 'name': name,
      if (amount != null) 'amount': amount,
    });
  }

  ThresholdsCompanion copyWith({
    Value<int>? id,
    Value<int>? trackableId,
    Value<String>? name,
    Value<double>? amount,
  }) {
    return ThresholdsCompanion(
      id: id ?? this.id,
      trackableId: trackableId ?? this.trackableId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
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
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ThresholdsCompanion(')
          ..write('id: $id, ')
          ..write('trackableId: $trackableId, ')
          ..write('name: $name, ')
          ..write('amount: $amount')
          ..write(')'))
        .toString();
  }
}

class $TaperPlansTable extends TaperPlans
    with TableInfo<$TaperPlansTable, TaperPlan> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaperPlansTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _startAmountMeta = const VerificationMeta(
    'startAmount',
  );
  @override
  late final GeneratedColumn<double> startAmount = GeneratedColumn<double>(
    'start_amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetAmountMeta = const VerificationMeta(
    'targetAmount',
  );
  @override
  late final GeneratedColumn<double> targetAmount = GeneratedColumn<double>(
    'target_amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
    'end_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    trackableId,
    startAmount,
    targetAmount,
    startDate,
    endDate,
    isActive,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'taper_plans';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaperPlan> instance, {
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
    if (data.containsKey('start_amount')) {
      context.handle(
        _startAmountMeta,
        startAmount.isAcceptableOrUnknown(
          data['start_amount']!,
          _startAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startAmountMeta);
    }
    if (data.containsKey('target_amount')) {
      context.handle(
        _targetAmountMeta,
        targetAmount.isAcceptableOrUnknown(
          data['target_amount']!,
          _targetAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetAmountMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    } else if (isInserting) {
      context.missing(_endDateMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaperPlan map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaperPlan(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      trackableId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trackable_id'],
      )!,
      startAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}start_amount'],
      )!,
      targetAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}target_amount'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_date'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
    );
  }

  @override
  $TaperPlansTable createAlias(String alias) {
    return $TaperPlansTable(attachedDatabase, alias);
  }
}

class TaperPlan extends DataClass implements Insertable<TaperPlan> {
  final int id;
  final int trackableId;
  final double startAmount;
  final double targetAmount;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  const TaperPlan({
    required this.id,
    required this.trackableId,
    required this.startAmount,
    required this.targetAmount,
    required this.startDate,
    required this.endDate,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['trackable_id'] = Variable<int>(trackableId);
    map['start_amount'] = Variable<double>(startAmount);
    map['target_amount'] = Variable<double>(targetAmount);
    map['start_date'] = Variable<DateTime>(startDate);
    map['end_date'] = Variable<DateTime>(endDate);
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  TaperPlansCompanion toCompanion(bool nullToAbsent) {
    return TaperPlansCompanion(
      id: Value(id),
      trackableId: Value(trackableId),
      startAmount: Value(startAmount),
      targetAmount: Value(targetAmount),
      startDate: Value(startDate),
      endDate: Value(endDate),
      isActive: Value(isActive),
    );
  }

  factory TaperPlan.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaperPlan(
      id: serializer.fromJson<int>(json['id']),
      trackableId: serializer.fromJson<int>(json['trackableId']),
      startAmount: serializer.fromJson<double>(json['startAmount']),
      targetAmount: serializer.fromJson<double>(json['targetAmount']),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      endDate: serializer.fromJson<DateTime>(json['endDate']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trackableId': serializer.toJson<int>(trackableId),
      'startAmount': serializer.toJson<double>(startAmount),
      'targetAmount': serializer.toJson<double>(targetAmount),
      'startDate': serializer.toJson<DateTime>(startDate),
      'endDate': serializer.toJson<DateTime>(endDate),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  TaperPlan copyWith({
    int? id,
    int? trackableId,
    double? startAmount,
    double? targetAmount,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
  }) => TaperPlan(
    id: id ?? this.id,
    trackableId: trackableId ?? this.trackableId,
    startAmount: startAmount ?? this.startAmount,
    targetAmount: targetAmount ?? this.targetAmount,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    isActive: isActive ?? this.isActive,
  );
  TaperPlan copyWithCompanion(TaperPlansCompanion data) {
    return TaperPlan(
      id: data.id.present ? data.id.value : this.id,
      trackableId: data.trackableId.present
          ? data.trackableId.value
          : this.trackableId,
      startAmount: data.startAmount.present
          ? data.startAmount.value
          : this.startAmount,
      targetAmount: data.targetAmount.present
          ? data.targetAmount.value
          : this.targetAmount,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaperPlan(')
          ..write('id: $id, ')
          ..write('trackableId: $trackableId, ')
          ..write('startAmount: $startAmount, ')
          ..write('targetAmount: $targetAmount, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    trackableId,
    startAmount,
    targetAmount,
    startDate,
    endDate,
    isActive,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaperPlan &&
          other.id == this.id &&
          other.trackableId == this.trackableId &&
          other.startAmount == this.startAmount &&
          other.targetAmount == this.targetAmount &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.isActive == this.isActive);
}

class TaperPlansCompanion extends UpdateCompanion<TaperPlan> {
  final Value<int> id;
  final Value<int> trackableId;
  final Value<double> startAmount;
  final Value<double> targetAmount;
  final Value<DateTime> startDate;
  final Value<DateTime> endDate;
  final Value<bool> isActive;
  const TaperPlansCompanion({
    this.id = const Value.absent(),
    this.trackableId = const Value.absent(),
    this.startAmount = const Value.absent(),
    this.targetAmount = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.isActive = const Value.absent(),
  });
  TaperPlansCompanion.insert({
    this.id = const Value.absent(),
    required int trackableId,
    required double startAmount,
    required double targetAmount,
    required DateTime startDate,
    required DateTime endDate,
    this.isActive = const Value.absent(),
  }) : trackableId = Value(trackableId),
       startAmount = Value(startAmount),
       targetAmount = Value(targetAmount),
       startDate = Value(startDate),
       endDate = Value(endDate);
  static Insertable<TaperPlan> custom({
    Expression<int>? id,
    Expression<int>? trackableId,
    Expression<double>? startAmount,
    Expression<double>? targetAmount,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<bool>? isActive,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trackableId != null) 'trackable_id': trackableId,
      if (startAmount != null) 'start_amount': startAmount,
      if (targetAmount != null) 'target_amount': targetAmount,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (isActive != null) 'is_active': isActive,
    });
  }

  TaperPlansCompanion copyWith({
    Value<int>? id,
    Value<int>? trackableId,
    Value<double>? startAmount,
    Value<double>? targetAmount,
    Value<DateTime>? startDate,
    Value<DateTime>? endDate,
    Value<bool>? isActive,
  }) {
    return TaperPlansCompanion(
      id: id ?? this.id,
      trackableId: trackableId ?? this.trackableId,
      startAmount: startAmount ?? this.startAmount,
      targetAmount: targetAmount ?? this.targetAmount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
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
    if (startAmount.present) {
      map['start_amount'] = Variable<double>(startAmount.value);
    }
    if (targetAmount.present) {
      map['target_amount'] = Variable<double>(targetAmount.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaperPlansCompanion(')
          ..write('id: $id, ')
          ..write('trackableId: $trackableId, ')
          ..write('startAmount: $startAmount, ')
          ..write('targetAmount: $targetAmount, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }
}

class $DashboardWidgetsTable extends DashboardWidgets
    with TableInfo<$DashboardWidgetsTable, DashboardWidget> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DashboardWidgetsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackableIdMeta = const VerificationMeta(
    'trackableId',
  );
  @override
  late final GeneratedColumn<int> trackableId = GeneratedColumn<int>(
    'trackable_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES trackables (id)',
    ),
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
  static const VerificationMeta _configMeta = const VerificationMeta('config');
  @override
  late final GeneratedColumn<String> config = GeneratedColumn<String>(
    'config',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    trackableId,
    sortOrder,
    config,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dashboard_widgets';
  @override
  VerificationContext validateIntegrity(
    Insertable<DashboardWidget> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('trackable_id')) {
      context.handle(
        _trackableIdMeta,
        trackableId.isAcceptableOrUnknown(
          data['trackable_id']!,
          _trackableIdMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('config')) {
      context.handle(
        _configMeta,
        config.isAcceptableOrUnknown(data['config']!, _configMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DashboardWidget map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DashboardWidget(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      trackableId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trackable_id'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      config: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}config'],
      )!,
    );
  }

  @override
  $DashboardWidgetsTable createAlias(String alias) {
    return $DashboardWidgetsTable(attachedDatabase, alias);
  }
}

class DashboardWidget extends DataClass implements Insertable<DashboardWidget> {
  final int id;
  final String type;
  final int? trackableId;
  final int sortOrder;
  final String config;
  const DashboardWidget({
    required this.id,
    required this.type,
    this.trackableId,
    required this.sortOrder,
    required this.config,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || trackableId != null) {
      map['trackable_id'] = Variable<int>(trackableId);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['config'] = Variable<String>(config);
    return map;
  }

  DashboardWidgetsCompanion toCompanion(bool nullToAbsent) {
    return DashboardWidgetsCompanion(
      id: Value(id),
      type: Value(type),
      trackableId: trackableId == null && nullToAbsent
          ? const Value.absent()
          : Value(trackableId),
      sortOrder: Value(sortOrder),
      config: Value(config),
    );
  }

  factory DashboardWidget.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DashboardWidget(
      id: serializer.fromJson<int>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      trackableId: serializer.fromJson<int?>(json['trackableId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      config: serializer.fromJson<String>(json['config']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'type': serializer.toJson<String>(type),
      'trackableId': serializer.toJson<int?>(trackableId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'config': serializer.toJson<String>(config),
    };
  }

  DashboardWidget copyWith({
    int? id,
    String? type,
    Value<int?> trackableId = const Value.absent(),
    int? sortOrder,
    String? config,
  }) => DashboardWidget(
    id: id ?? this.id,
    type: type ?? this.type,
    trackableId: trackableId.present ? trackableId.value : this.trackableId,
    sortOrder: sortOrder ?? this.sortOrder,
    config: config ?? this.config,
  );
  DashboardWidget copyWithCompanion(DashboardWidgetsCompanion data) {
    return DashboardWidget(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      trackableId: data.trackableId.present
          ? data.trackableId.value
          : this.trackableId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      config: data.config.present ? data.config.value : this.config,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DashboardWidget(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('trackableId: $trackableId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('config: $config')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, type, trackableId, sortOrder, config);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DashboardWidget &&
          other.id == this.id &&
          other.type == this.type &&
          other.trackableId == this.trackableId &&
          other.sortOrder == this.sortOrder &&
          other.config == this.config);
}

class DashboardWidgetsCompanion extends UpdateCompanion<DashboardWidget> {
  final Value<int> id;
  final Value<String> type;
  final Value<int?> trackableId;
  final Value<int> sortOrder;
  final Value<String> config;
  const DashboardWidgetsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.trackableId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.config = const Value.absent(),
  });
  DashboardWidgetsCompanion.insert({
    this.id = const Value.absent(),
    required String type,
    this.trackableId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.config = const Value.absent(),
  }) : type = Value(type);
  static Insertable<DashboardWidget> custom({
    Expression<int>? id,
    Expression<String>? type,
    Expression<int>? trackableId,
    Expression<int>? sortOrder,
    Expression<String>? config,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (trackableId != null) 'trackable_id': trackableId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (config != null) 'config': config,
    });
  }

  DashboardWidgetsCompanion copyWith({
    Value<int>? id,
    Value<String>? type,
    Value<int?>? trackableId,
    Value<int>? sortOrder,
    Value<String>? config,
  }) {
    return DashboardWidgetsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      trackableId: trackableId ?? this.trackableId,
      sortOrder: sortOrder ?? this.sortOrder,
      config: config ?? this.config,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (trackableId.present) {
      map['trackable_id'] = Variable<int>(trackableId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (config.present) {
      map['config'] = Variable<String>(config.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DashboardWidgetsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('trackableId: $trackableId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('config: $config')
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
  late final $ThresholdsTable thresholds = $ThresholdsTable(this);
  late final $TaperPlansTable taperPlans = $TaperPlansTable(this);
  late final $DashboardWidgetsTable dashboardWidgets = $DashboardWidgetsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    trackables,
    doseLogs,
    presets,
    thresholds,
    taperPlans,
    dashboardWidgets,
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
      Value<double?> absorptionMinutes,
      Value<bool> showCumulativeLine,
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
      Value<double?> absorptionMinutes,
      Value<bool> showCumulativeLine,
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

  static MultiTypedResultKey<$ThresholdsTable, List<Threshold>>
  _thresholdsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.thresholds,
    aliasName: $_aliasNameGenerator(
      db.trackables.id,
      db.thresholds.trackableId,
    ),
  );

  $$ThresholdsTableProcessedTableManager get thresholdsRefs {
    final manager = $$ThresholdsTableTableManager(
      $_db,
      $_db.thresholds,
    ).filter((f) => f.trackableId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_thresholdsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TaperPlansTable, List<TaperPlan>>
  _taperPlansRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.taperPlans,
    aliasName: $_aliasNameGenerator(
      db.trackables.id,
      db.taperPlans.trackableId,
    ),
  );

  $$TaperPlansTableProcessedTableManager get taperPlansRefs {
    final manager = $$TaperPlansTableTableManager(
      $_db,
      $_db.taperPlans,
    ).filter((f) => f.trackableId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_taperPlansRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DashboardWidgetsTable, List<DashboardWidget>>
  _dashboardWidgetsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.dashboardWidgets,
    aliasName: $_aliasNameGenerator(
      db.trackables.id,
      db.dashboardWidgets.trackableId,
    ),
  );

  $$DashboardWidgetsTableProcessedTableManager get dashboardWidgetsRefs {
    final manager = $$DashboardWidgetsTableTableManager(
      $_db,
      $_db.dashboardWidgets,
    ).filter((f) => f.trackableId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _dashboardWidgetsRefsTable($_db),
    );
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

  ColumnFilters<double> get absorptionMinutes => $composableBuilder(
    column: $table.absorptionMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showCumulativeLine => $composableBuilder(
    column: $table.showCumulativeLine,
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

  Expression<bool> thresholdsRefs(
    Expression<bool> Function($$ThresholdsTableFilterComposer f) f,
  ) {
    final $$ThresholdsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.thresholds,
      getReferencedColumn: (t) => t.trackableId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ThresholdsTableFilterComposer(
            $db: $db,
            $table: $db.thresholds,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> taperPlansRefs(
    Expression<bool> Function($$TaperPlansTableFilterComposer f) f,
  ) {
    final $$TaperPlansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taperPlans,
      getReferencedColumn: (t) => t.trackableId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaperPlansTableFilterComposer(
            $db: $db,
            $table: $db.taperPlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> dashboardWidgetsRefs(
    Expression<bool> Function($$DashboardWidgetsTableFilterComposer f) f,
  ) {
    final $$DashboardWidgetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dashboardWidgets,
      getReferencedColumn: (t) => t.trackableId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DashboardWidgetsTableFilterComposer(
            $db: $db,
            $table: $db.dashboardWidgets,
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

  ColumnOrderings<double> get absorptionMinutes => $composableBuilder(
    column: $table.absorptionMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showCumulativeLine => $composableBuilder(
    column: $table.showCumulativeLine,
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

  GeneratedColumn<double> get absorptionMinutes => $composableBuilder(
    column: $table.absorptionMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get showCumulativeLine => $composableBuilder(
    column: $table.showCumulativeLine,
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

  Expression<T> thresholdsRefs<T extends Object>(
    Expression<T> Function($$ThresholdsTableAnnotationComposer a) f,
  ) {
    final $$ThresholdsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.thresholds,
      getReferencedColumn: (t) => t.trackableId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ThresholdsTableAnnotationComposer(
            $db: $db,
            $table: $db.thresholds,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> taperPlansRefs<T extends Object>(
    Expression<T> Function($$TaperPlansTableAnnotationComposer a) f,
  ) {
    final $$TaperPlansTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taperPlans,
      getReferencedColumn: (t) => t.trackableId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaperPlansTableAnnotationComposer(
            $db: $db,
            $table: $db.taperPlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> dashboardWidgetsRefs<T extends Object>(
    Expression<T> Function($$DashboardWidgetsTableAnnotationComposer a) f,
  ) {
    final $$DashboardWidgetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dashboardWidgets,
      getReferencedColumn: (t) => t.trackableId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DashboardWidgetsTableAnnotationComposer(
            $db: $db,
            $table: $db.dashboardWidgets,
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
          PrefetchHooks Function({
            bool doseLogsRefs,
            bool presetsRefs,
            bool thresholdsRefs,
            bool taperPlansRefs,
            bool dashboardWidgetsRefs,
          })
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
                Value<double?> absorptionMinutes = const Value.absent(),
                Value<bool> showCumulativeLine = const Value.absent(),
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
                absorptionMinutes: absorptionMinutes,
                showCumulativeLine: showCumulativeLine,
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
                Value<double?> absorptionMinutes = const Value.absent(),
                Value<bool> showCumulativeLine = const Value.absent(),
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
                absorptionMinutes: absorptionMinutes,
                showCumulativeLine: showCumulativeLine,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TrackablesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                doseLogsRefs = false,
                presetsRefs = false,
                thresholdsRefs = false,
                taperPlansRefs = false,
                dashboardWidgetsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (doseLogsRefs) db.doseLogs,
                    if (presetsRefs) db.presets,
                    if (thresholdsRefs) db.thresholds,
                    if (taperPlansRefs) db.taperPlans,
                    if (dashboardWidgetsRefs) db.dashboardWidgets,
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
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
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
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trackableId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (thresholdsRefs)
                        await $_getPrefetchedData<
                          Trackable,
                          $TrackablesTable,
                          Threshold
                        >(
                          currentTable: table,
                          referencedTable: $$TrackablesTableReferences
                              ._thresholdsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TrackablesTableReferences(
                                db,
                                table,
                                p0,
                              ).thresholdsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trackableId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (taperPlansRefs)
                        await $_getPrefetchedData<
                          Trackable,
                          $TrackablesTable,
                          TaperPlan
                        >(
                          currentTable: table,
                          referencedTable: $$TrackablesTableReferences
                              ._taperPlansRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TrackablesTableReferences(
                                db,
                                table,
                                p0,
                              ).taperPlansRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trackableId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (dashboardWidgetsRefs)
                        await $_getPrefetchedData<
                          Trackable,
                          $TrackablesTable,
                          DashboardWidget
                        >(
                          currentTable: table,
                          referencedTable: $$TrackablesTableReferences
                              ._dashboardWidgetsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TrackablesTableReferences(
                                db,
                                table,
                                p0,
                              ).dashboardWidgetsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
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
      PrefetchHooks Function({
        bool doseLogsRefs,
        bool presetsRefs,
        bool thresholdsRefs,
        bool taperPlansRefs,
        bool dashboardWidgetsRefs,
      })
    >;
typedef $$DoseLogsTableCreateCompanionBuilder =
    DoseLogsCompanion Function({
      Value<int> id,
      required int trackableId,
      required double amount,
      required DateTime loggedAt,
      Value<String?> name,
    });
typedef $$DoseLogsTableUpdateCompanionBuilder =
    DoseLogsCompanion Function({
      Value<int> id,
      Value<int> trackableId,
      Value<double> amount,
      Value<DateTime> loggedAt,
      Value<String?> name,
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
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

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

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
                Value<String?> name = const Value.absent(),
              }) => DoseLogsCompanion(
                id: id,
                trackableId: trackableId,
                amount: amount,
                loggedAt: loggedAt,
                name: name,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int trackableId,
                required double amount,
                required DateTime loggedAt,
                Value<String?> name = const Value.absent(),
              }) => DoseLogsCompanion.insert(
                id: id,
                trackableId: trackableId,
                amount: amount,
                loggedAt: loggedAt,
                name: name,
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
typedef $$ThresholdsTableCreateCompanionBuilder =
    ThresholdsCompanion Function({
      Value<int> id,
      required int trackableId,
      required String name,
      required double amount,
    });
typedef $$ThresholdsTableUpdateCompanionBuilder =
    ThresholdsCompanion Function({
      Value<int> id,
      Value<int> trackableId,
      Value<String> name,
      Value<double> amount,
    });

final class $$ThresholdsTableReferences
    extends BaseReferences<_$AppDatabase, $ThresholdsTable, Threshold> {
  $$ThresholdsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TrackablesTable _trackableIdTable(_$AppDatabase db) =>
      db.trackables.createAlias(
        $_aliasNameGenerator(db.thresholds.trackableId, db.trackables.id),
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

class $$ThresholdsTableFilterComposer
    extends Composer<_$AppDatabase, $ThresholdsTable> {
  $$ThresholdsTableFilterComposer({
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

class $$ThresholdsTableOrderingComposer
    extends Composer<_$AppDatabase, $ThresholdsTable> {
  $$ThresholdsTableOrderingComposer({
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

class $$ThresholdsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ThresholdsTable> {
  $$ThresholdsTableAnnotationComposer({
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

class $$ThresholdsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ThresholdsTable,
          Threshold,
          $$ThresholdsTableFilterComposer,
          $$ThresholdsTableOrderingComposer,
          $$ThresholdsTableAnnotationComposer,
          $$ThresholdsTableCreateCompanionBuilder,
          $$ThresholdsTableUpdateCompanionBuilder,
          (Threshold, $$ThresholdsTableReferences),
          Threshold,
          PrefetchHooks Function({bool trackableId})
        > {
  $$ThresholdsTableTableManager(_$AppDatabase db, $ThresholdsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ThresholdsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ThresholdsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ThresholdsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> trackableId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> amount = const Value.absent(),
              }) => ThresholdsCompanion(
                id: id,
                trackableId: trackableId,
                name: name,
                amount: amount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int trackableId,
                required String name,
                required double amount,
              }) => ThresholdsCompanion.insert(
                id: id,
                trackableId: trackableId,
                name: name,
                amount: amount,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ThresholdsTableReferences(db, table, e),
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
                                referencedTable: $$ThresholdsTableReferences
                                    ._trackableIdTable(db),
                                referencedColumn: $$ThresholdsTableReferences
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

typedef $$ThresholdsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ThresholdsTable,
      Threshold,
      $$ThresholdsTableFilterComposer,
      $$ThresholdsTableOrderingComposer,
      $$ThresholdsTableAnnotationComposer,
      $$ThresholdsTableCreateCompanionBuilder,
      $$ThresholdsTableUpdateCompanionBuilder,
      (Threshold, $$ThresholdsTableReferences),
      Threshold,
      PrefetchHooks Function({bool trackableId})
    >;
typedef $$TaperPlansTableCreateCompanionBuilder =
    TaperPlansCompanion Function({
      Value<int> id,
      required int trackableId,
      required double startAmount,
      required double targetAmount,
      required DateTime startDate,
      required DateTime endDate,
      Value<bool> isActive,
    });
typedef $$TaperPlansTableUpdateCompanionBuilder =
    TaperPlansCompanion Function({
      Value<int> id,
      Value<int> trackableId,
      Value<double> startAmount,
      Value<double> targetAmount,
      Value<DateTime> startDate,
      Value<DateTime> endDate,
      Value<bool> isActive,
    });

final class $$TaperPlansTableReferences
    extends BaseReferences<_$AppDatabase, $TaperPlansTable, TaperPlan> {
  $$TaperPlansTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TrackablesTable _trackableIdTable(_$AppDatabase db) =>
      db.trackables.createAlias(
        $_aliasNameGenerator(db.taperPlans.trackableId, db.trackables.id),
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

class $$TaperPlansTableFilterComposer
    extends Composer<_$AppDatabase, $TaperPlansTable> {
  $$TaperPlansTableFilterComposer({
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

  ColumnFilters<double> get startAmount => $composableBuilder(
    column: $table.startAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get targetAmount => $composableBuilder(
    column: $table.targetAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
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

class $$TaperPlansTableOrderingComposer
    extends Composer<_$AppDatabase, $TaperPlansTable> {
  $$TaperPlansTableOrderingComposer({
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

  ColumnOrderings<double> get startAmount => $composableBuilder(
    column: $table.startAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get targetAmount => $composableBuilder(
    column: $table.targetAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
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

class $$TaperPlansTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaperPlansTable> {
  $$TaperPlansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get startAmount => $composableBuilder(
    column: $table.startAmount,
    builder: (column) => column,
  );

  GeneratedColumn<double> get targetAmount => $composableBuilder(
    column: $table.targetAmount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

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

class $$TaperPlansTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaperPlansTable,
          TaperPlan,
          $$TaperPlansTableFilterComposer,
          $$TaperPlansTableOrderingComposer,
          $$TaperPlansTableAnnotationComposer,
          $$TaperPlansTableCreateCompanionBuilder,
          $$TaperPlansTableUpdateCompanionBuilder,
          (TaperPlan, $$TaperPlansTableReferences),
          TaperPlan,
          PrefetchHooks Function({bool trackableId})
        > {
  $$TaperPlansTableTableManager(_$AppDatabase db, $TaperPlansTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaperPlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaperPlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaperPlansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> trackableId = const Value.absent(),
                Value<double> startAmount = const Value.absent(),
                Value<double> targetAmount = const Value.absent(),
                Value<DateTime> startDate = const Value.absent(),
                Value<DateTime> endDate = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
              }) => TaperPlansCompanion(
                id: id,
                trackableId: trackableId,
                startAmount: startAmount,
                targetAmount: targetAmount,
                startDate: startDate,
                endDate: endDate,
                isActive: isActive,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int trackableId,
                required double startAmount,
                required double targetAmount,
                required DateTime startDate,
                required DateTime endDate,
                Value<bool> isActive = const Value.absent(),
              }) => TaperPlansCompanion.insert(
                id: id,
                trackableId: trackableId,
                startAmount: startAmount,
                targetAmount: targetAmount,
                startDate: startDate,
                endDate: endDate,
                isActive: isActive,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TaperPlansTableReferences(db, table, e),
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
                                referencedTable: $$TaperPlansTableReferences
                                    ._trackableIdTable(db),
                                referencedColumn: $$TaperPlansTableReferences
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

typedef $$TaperPlansTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaperPlansTable,
      TaperPlan,
      $$TaperPlansTableFilterComposer,
      $$TaperPlansTableOrderingComposer,
      $$TaperPlansTableAnnotationComposer,
      $$TaperPlansTableCreateCompanionBuilder,
      $$TaperPlansTableUpdateCompanionBuilder,
      (TaperPlan, $$TaperPlansTableReferences),
      TaperPlan,
      PrefetchHooks Function({bool trackableId})
    >;
typedef $$DashboardWidgetsTableCreateCompanionBuilder =
    DashboardWidgetsCompanion Function({
      Value<int> id,
      required String type,
      Value<int?> trackableId,
      Value<int> sortOrder,
      Value<String> config,
    });
typedef $$DashboardWidgetsTableUpdateCompanionBuilder =
    DashboardWidgetsCompanion Function({
      Value<int> id,
      Value<String> type,
      Value<int?> trackableId,
      Value<int> sortOrder,
      Value<String> config,
    });

final class $$DashboardWidgetsTableReferences
    extends
        BaseReferences<_$AppDatabase, $DashboardWidgetsTable, DashboardWidget> {
  $$DashboardWidgetsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TrackablesTable _trackableIdTable(_$AppDatabase db) =>
      db.trackables.createAlias(
        $_aliasNameGenerator(db.dashboardWidgets.trackableId, db.trackables.id),
      );

  $$TrackablesTableProcessedTableManager? get trackableId {
    final $_column = $_itemColumn<int>('trackable_id');
    if ($_column == null) return null;
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

class $$DashboardWidgetsTableFilterComposer
    extends Composer<_$AppDatabase, $DashboardWidgetsTable> {
  $$DashboardWidgetsTableFilterComposer({
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

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get config => $composableBuilder(
    column: $table.config,
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

class $$DashboardWidgetsTableOrderingComposer
    extends Composer<_$AppDatabase, $DashboardWidgetsTable> {
  $$DashboardWidgetsTableOrderingComposer({
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

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get config => $composableBuilder(
    column: $table.config,
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

class $$DashboardWidgetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DashboardWidgetsTable> {
  $$DashboardWidgetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get config =>
      $composableBuilder(column: $table.config, builder: (column) => column);

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

class $$DashboardWidgetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DashboardWidgetsTable,
          DashboardWidget,
          $$DashboardWidgetsTableFilterComposer,
          $$DashboardWidgetsTableOrderingComposer,
          $$DashboardWidgetsTableAnnotationComposer,
          $$DashboardWidgetsTableCreateCompanionBuilder,
          $$DashboardWidgetsTableUpdateCompanionBuilder,
          (DashboardWidget, $$DashboardWidgetsTableReferences),
          DashboardWidget,
          PrefetchHooks Function({bool trackableId})
        > {
  $$DashboardWidgetsTableTableManager(
    _$AppDatabase db,
    $DashboardWidgetsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DashboardWidgetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DashboardWidgetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DashboardWidgetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int?> trackableId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> config = const Value.absent(),
              }) => DashboardWidgetsCompanion(
                id: id,
                type: type,
                trackableId: trackableId,
                sortOrder: sortOrder,
                config: config,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String type,
                Value<int?> trackableId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> config = const Value.absent(),
              }) => DashboardWidgetsCompanion.insert(
                id: id,
                type: type,
                trackableId: trackableId,
                sortOrder: sortOrder,
                config: config,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DashboardWidgetsTableReferences(db, table, e),
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
                                referencedTable:
                                    $$DashboardWidgetsTableReferences
                                        ._trackableIdTable(db),
                                referencedColumn:
                                    $$DashboardWidgetsTableReferences
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

typedef $$DashboardWidgetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DashboardWidgetsTable,
      DashboardWidget,
      $$DashboardWidgetsTableFilterComposer,
      $$DashboardWidgetsTableOrderingComposer,
      $$DashboardWidgetsTableAnnotationComposer,
      $$DashboardWidgetsTableCreateCompanionBuilder,
      $$DashboardWidgetsTableUpdateCompanionBuilder,
      (DashboardWidget, $$DashboardWidgetsTableReferences),
      DashboardWidget,
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
  $$ThresholdsTableTableManager get thresholds =>
      $$ThresholdsTableTableManager(_db, _db.thresholds);
  $$TaperPlansTableTableManager get taperPlans =>
      $$TaperPlansTableTableManager(_db, _db.taperPlans);
  $$DashboardWidgetsTableTableManager get dashboardWidgets =>
      $$DashboardWidgetsTableTableManager(_db, _db.dashboardWidgets);
}
