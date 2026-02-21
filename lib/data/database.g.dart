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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SubstancesTable substances = $SubstancesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [substances];
}

typedef $$SubstancesTableCreateCompanionBuilder =
    SubstancesCompanion Function({Value<int> id, required String name});
typedef $$SubstancesTableUpdateCompanionBuilder =
    SubstancesCompanion Function({Value<int> id, Value<String> name});

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
          (
            Substance,
            BaseReferences<_$AppDatabase, $SubstancesTable, Substance>,
          ),
          Substance,
          PrefetchHooks Function()
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
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
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
      (Substance, BaseReferences<_$AppDatabase, $SubstancesTable, Substance>),
      Substance,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SubstancesTableTableManager get substances =>
      $$SubstancesTableTableManager(_db, _db.substances);
}
