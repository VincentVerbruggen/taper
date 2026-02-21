// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SubstancesTable extends Substances
    with TableInfo<$SubstancesTable, Substance> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubstancesTable(this.attachedDatabase, [this._alias]);
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
  @override
  List<GeneratedColumn> get $columns => [id, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'substances';
  @override
  VerificationContext validateIntegrity(
    Insertable<Substance> instance, {
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Substance map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Substance(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $SubstancesTable createAlias(String alias) {
    return $SubstancesTable(attachedDatabase, alias);
  }
}

class Substance extends DataClass implements Insertable<Substance> {
  final int id;
  final String name;
  const Substance({required this.id, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  SubstancesCompanion toCompanion(bool nullToAbsent) {
    return SubstancesCompanion(id: Value(id), name: Value(name));
  }

  factory Substance.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Substance(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
    };
  }

  Substance copyWith({int? id, String? name}) =>
      Substance(id: id ?? this.id, name: name ?? this.name);
  Substance copyWithCompanion(SubstancesCompanion data) {
    return Substance(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Substance(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Substance && other.id == this.id && other.name == this.name);
}

class SubstancesCompanion extends UpdateCompanion<Substance> {
  final Value<int> id;
  final Value<String> name;
  const SubstancesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
  });
  SubstancesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
  }) : name = Value(name);
  static Insertable<Substance> custom({
    Expression<int>? id,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
    });
  }

  SubstancesCompanion copyWith({Value<int>? id, Value<String>? name}) {
    return SubstancesCompanion(id: id ?? this.id, name: name ?? this.name);
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
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubstancesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name')
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
  static const VerificationMeta _substanceIdMeta = const VerificationMeta(
    'substanceId',
  );
  @override
  late final GeneratedColumn<int> substanceId = GeneratedColumn<int>(
    'substance_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES substances (id)',
    ),
  );
  static const VerificationMeta _amountMgMeta = const VerificationMeta(
    'amountMg',
  );
  @override
  late final GeneratedColumn<double> amountMg = GeneratedColumn<double>(
    'amount_mg',
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
  List<GeneratedColumn> get $columns => [id, substanceId, amountMg, loggedAt];
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
    if (data.containsKey('substance_id')) {
      context.handle(
        _substanceIdMeta,
        substanceId.isAcceptableOrUnknown(
          data['substance_id']!,
          _substanceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_substanceIdMeta);
    }
    if (data.containsKey('amount_mg')) {
      context.handle(
        _amountMgMeta,
        amountMg.isAcceptableOrUnknown(data['amount_mg']!, _amountMgMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMgMeta);
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
      substanceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}substance_id'],
      )!,
      amountMg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount_mg'],
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
  final int substanceId;
  final double amountMg;
  final DateTime loggedAt;
  const DoseLog({
    required this.id,
    required this.substanceId,
    required this.amountMg,
    required this.loggedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['substance_id'] = Variable<int>(substanceId);
    map['amount_mg'] = Variable<double>(amountMg);
    map['logged_at'] = Variable<DateTime>(loggedAt);
    return map;
  }

  DoseLogsCompanion toCompanion(bool nullToAbsent) {
    return DoseLogsCompanion(
      id: Value(id),
      substanceId: Value(substanceId),
      amountMg: Value(amountMg),
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
      substanceId: serializer.fromJson<int>(json['substanceId']),
      amountMg: serializer.fromJson<double>(json['amountMg']),
      loggedAt: serializer.fromJson<DateTime>(json['loggedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'substanceId': serializer.toJson<int>(substanceId),
      'amountMg': serializer.toJson<double>(amountMg),
      'loggedAt': serializer.toJson<DateTime>(loggedAt),
    };
  }

  DoseLog copyWith({
    int? id,
    int? substanceId,
    double? amountMg,
    DateTime? loggedAt,
  }) => DoseLog(
    id: id ?? this.id,
    substanceId: substanceId ?? this.substanceId,
    amountMg: amountMg ?? this.amountMg,
    loggedAt: loggedAt ?? this.loggedAt,
  );
  DoseLog copyWithCompanion(DoseLogsCompanion data) {
    return DoseLog(
      id: data.id.present ? data.id.value : this.id,
      substanceId: data.substanceId.present
          ? data.substanceId.value
          : this.substanceId,
      amountMg: data.amountMg.present ? data.amountMg.value : this.amountMg,
      loggedAt: data.loggedAt.present ? data.loggedAt.value : this.loggedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DoseLog(')
          ..write('id: $id, ')
          ..write('substanceId: $substanceId, ')
          ..write('amountMg: $amountMg, ')
          ..write('loggedAt: $loggedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, substanceId, amountMg, loggedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DoseLog &&
          other.id == this.id &&
          other.substanceId == this.substanceId &&
          other.amountMg == this.amountMg &&
          other.loggedAt == this.loggedAt);
}

class DoseLogsCompanion extends UpdateCompanion<DoseLog> {
  final Value<int> id;
  final Value<int> substanceId;
  final Value<double> amountMg;
  final Value<DateTime> loggedAt;
  const DoseLogsCompanion({
    this.id = const Value.absent(),
    this.substanceId = const Value.absent(),
    this.amountMg = const Value.absent(),
    this.loggedAt = const Value.absent(),
  });
  DoseLogsCompanion.insert({
    this.id = const Value.absent(),
    required int substanceId,
    required double amountMg,
    required DateTime loggedAt,
  }) : substanceId = Value(substanceId),
       amountMg = Value(amountMg),
       loggedAt = Value(loggedAt);
  static Insertable<DoseLog> custom({
    Expression<int>? id,
    Expression<int>? substanceId,
    Expression<double>? amountMg,
    Expression<DateTime>? loggedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (substanceId != null) 'substance_id': substanceId,
      if (amountMg != null) 'amount_mg': amountMg,
      if (loggedAt != null) 'logged_at': loggedAt,
    });
  }

  DoseLogsCompanion copyWith({
    Value<int>? id,
    Value<int>? substanceId,
    Value<double>? amountMg,
    Value<DateTime>? loggedAt,
  }) {
    return DoseLogsCompanion(
      id: id ?? this.id,
      substanceId: substanceId ?? this.substanceId,
      amountMg: amountMg ?? this.amountMg,
      loggedAt: loggedAt ?? this.loggedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (substanceId.present) {
      map['substance_id'] = Variable<int>(substanceId.value);
    }
    if (amountMg.present) {
      map['amount_mg'] = Variable<double>(amountMg.value);
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
          ..write('substanceId: $substanceId, ')
          ..write('amountMg: $amountMg, ')
          ..write('loggedAt: $loggedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SubstancesTable substances = $SubstancesTable(this);
  late final $DoseLogsTable doseLogs = $DoseLogsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [substances, doseLogs];
}

typedef $$SubstancesTableCreateCompanionBuilder =
    SubstancesCompanion Function({Value<int> id, required String name});
typedef $$SubstancesTableUpdateCompanionBuilder =
    SubstancesCompanion Function({Value<int> id, Value<String> name});

final class $$SubstancesTableReferences
    extends BaseReferences<_$AppDatabase, $SubstancesTable, Substance> {
  $$SubstancesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$DoseLogsTable, List<DoseLog>> _doseLogsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.doseLogs,
    aliasName: $_aliasNameGenerator(db.substances.id, db.doseLogs.substanceId),
  );

  $$DoseLogsTableProcessedTableManager get doseLogsRefs {
    final manager = $$DoseLogsTableTableManager(
      $_db,
      $_db.doseLogs,
    ).filter((f) => f.substanceId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_doseLogsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SubstancesTableFilterComposer
    extends Composer<_$AppDatabase, $SubstancesTable> {
  $$SubstancesTableFilterComposer({
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

  Expression<bool> doseLogsRefs(
    Expression<bool> Function($$DoseLogsTableFilterComposer f) f,
  ) {
    final $$DoseLogsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.doseLogs,
      getReferencedColumn: (t) => t.substanceId,
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
}

class $$SubstancesTableOrderingComposer
    extends Composer<_$AppDatabase, $SubstancesTable> {
  $$SubstancesTableOrderingComposer({
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
}

class $$SubstancesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SubstancesTable> {
  $$SubstancesTableAnnotationComposer({
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

  Expression<T> doseLogsRefs<T extends Object>(
    Expression<T> Function($$DoseLogsTableAnnotationComposer a) f,
  ) {
    final $$DoseLogsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.doseLogs,
      getReferencedColumn: (t) => t.substanceId,
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
}

class $$SubstancesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SubstancesTable,
          Substance,
          $$SubstancesTableFilterComposer,
          $$SubstancesTableOrderingComposer,
          $$SubstancesTableAnnotationComposer,
          $$SubstancesTableCreateCompanionBuilder,
          $$SubstancesTableUpdateCompanionBuilder,
          (Substance, $$SubstancesTableReferences),
          Substance,
          PrefetchHooks Function({bool doseLogsRefs})
        > {
  $$SubstancesTableTableManager(_$AppDatabase db, $SubstancesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubstancesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubstancesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubstancesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
              }) => SubstancesCompanion(id: id, name: name),
          createCompanionCallback:
              ({Value<int> id = const Value.absent(), required String name}) =>
                  SubstancesCompanion.insert(id: id, name: name),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SubstancesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({doseLogsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (doseLogsRefs) db.doseLogs],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (doseLogsRefs)
                    await $_getPrefetchedData<
                      Substance,
                      $SubstancesTable,
                      DoseLog
                    >(
                      currentTable: table,
                      referencedTable: $$SubstancesTableReferences
                          ._doseLogsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SubstancesTableReferences(
                            db,
                            table,
                            p0,
                          ).doseLogsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.substanceId == item.id,
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

typedef $$SubstancesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SubstancesTable,
      Substance,
      $$SubstancesTableFilterComposer,
      $$SubstancesTableOrderingComposer,
      $$SubstancesTableAnnotationComposer,
      $$SubstancesTableCreateCompanionBuilder,
      $$SubstancesTableUpdateCompanionBuilder,
      (Substance, $$SubstancesTableReferences),
      Substance,
      PrefetchHooks Function({bool doseLogsRefs})
    >;
typedef $$DoseLogsTableCreateCompanionBuilder =
    DoseLogsCompanion Function({
      Value<int> id,
      required int substanceId,
      required double amountMg,
      required DateTime loggedAt,
    });
typedef $$DoseLogsTableUpdateCompanionBuilder =
    DoseLogsCompanion Function({
      Value<int> id,
      Value<int> substanceId,
      Value<double> amountMg,
      Value<DateTime> loggedAt,
    });

final class $$DoseLogsTableReferences
    extends BaseReferences<_$AppDatabase, $DoseLogsTable, DoseLog> {
  $$DoseLogsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SubstancesTable _substanceIdTable(_$AppDatabase db) =>
      db.substances.createAlias(
        $_aliasNameGenerator(db.doseLogs.substanceId, db.substances.id),
      );

  $$SubstancesTableProcessedTableManager get substanceId {
    final $_column = $_itemColumn<int>('substance_id')!;

    final manager = $$SubstancesTableTableManager(
      $_db,
      $_db.substances,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_substanceIdTable($_db));
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

  ColumnFilters<double> get amountMg => $composableBuilder(
    column: $table.amountMg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get loggedAt => $composableBuilder(
    column: $table.loggedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SubstancesTableFilterComposer get substanceId {
    final $$SubstancesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.substanceId,
      referencedTable: $db.substances,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubstancesTableFilterComposer(
            $db: $db,
            $table: $db.substances,
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

  ColumnOrderings<double> get amountMg => $composableBuilder(
    column: $table.amountMg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get loggedAt => $composableBuilder(
    column: $table.loggedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SubstancesTableOrderingComposer get substanceId {
    final $$SubstancesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.substanceId,
      referencedTable: $db.substances,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubstancesTableOrderingComposer(
            $db: $db,
            $table: $db.substances,
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

  GeneratedColumn<double> get amountMg =>
      $composableBuilder(column: $table.amountMg, builder: (column) => column);

  GeneratedColumn<DateTime> get loggedAt =>
      $composableBuilder(column: $table.loggedAt, builder: (column) => column);

  $$SubstancesTableAnnotationComposer get substanceId {
    final $$SubstancesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.substanceId,
      referencedTable: $db.substances,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubstancesTableAnnotationComposer(
            $db: $db,
            $table: $db.substances,
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
          PrefetchHooks Function({bool substanceId})
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
                Value<int> substanceId = const Value.absent(),
                Value<double> amountMg = const Value.absent(),
                Value<DateTime> loggedAt = const Value.absent(),
              }) => DoseLogsCompanion(
                id: id,
                substanceId: substanceId,
                amountMg: amountMg,
                loggedAt: loggedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int substanceId,
                required double amountMg,
                required DateTime loggedAt,
              }) => DoseLogsCompanion.insert(
                id: id,
                substanceId: substanceId,
                amountMg: amountMg,
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
          prefetchHooksCallback: ({substanceId = false}) {
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
                    if (substanceId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.substanceId,
                                referencedTable: $$DoseLogsTableReferences
                                    ._substanceIdTable(db),
                                referencedColumn: $$DoseLogsTableReferences
                                    ._substanceIdTable(db)
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
      PrefetchHooks Function({bool substanceId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SubstancesTableTableManager get substances =>
      $$SubstancesTableTableManager(_db, _db.substances);
  $$DoseLogsTableTableManager get doseLogs =>
      $$DoseLogsTableTableManager(_db, _db.doseLogs);
}
