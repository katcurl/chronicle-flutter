// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chronicle_database.dart';

// ignore_for_file: type=lint
class $AppStateRecordsTable extends AppStateRecords
    with TableInfo<$AppStateRecordsTable, AppStateRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppStateRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppStateRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppStateRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppStateRecord(
      key:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}key'],
          )!,
      value:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}value'],
          )!,
    );
  }

  @override
  $AppStateRecordsTable createAlias(String alias) {
    return $AppStateRecordsTable(attachedDatabase, alias);
  }
}

class AppStateRecord extends DataClass implements Insertable<AppStateRecord> {
  final String key;
  final String value;
  const AppStateRecord({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppStateRecordsCompanion toCompanion(bool nullToAbsent) {
    return AppStateRecordsCompanion(key: Value(key), value: Value(value));
  }

  factory AppStateRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppStateRecord(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppStateRecord copyWith({String? key, String? value}) =>
      AppStateRecord(key: key ?? this.key, value: value ?? this.value);
  AppStateRecord copyWithCompanion(AppStateRecordsCompanion data) {
    return AppStateRecord(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppStateRecord(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppStateRecord &&
          other.key == this.key &&
          other.value == this.value);
}

class AppStateRecordsCompanion extends UpdateCompanion<AppStateRecord> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppStateRecordsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppStateRecordsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppStateRecord> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppStateRecordsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppStateRecordsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppStateRecordsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProjectRecordsTable extends ProjectRecords
    with TableInfo<$ProjectRecordsTable, ProjectRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emojiMeta = const VerificationMeta('emoji');
  @override
  late final GeneratedColumn<String> emoji = GeneratedColumn<String>(
    'emoji',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('📁'),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0xFF6750A4),
  );
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<String> dueAt = GeneratedColumn<String>(
    'due_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _budgetMinutesMeta = const VerificationMeta(
    'budgetMinutes',
  );
  @override
  late final GeneratedColumn<int> budgetMinutes = GeneratedColumn<int>(
    'budget_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    emoji,
    description,
    colorValue,
    dueAt,
    budgetMinutes,
    archived,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'projects';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProjectRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('emoji')) {
      context.handle(
        _emojiMeta,
        emoji.isAcceptableOrUnknown(data['emoji']!, _emojiMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    }
    if (data.containsKey('due_at')) {
      context.handle(
        _dueAtMeta,
        dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta),
      );
    }
    if (data.containsKey('budget_minutes')) {
      context.handle(
        _budgetMinutesMeta,
        budgetMinutes.isAcceptableOrUnknown(
          data['budget_minutes']!,
          _budgetMinutesMeta,
        ),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProjectRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectRecord(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      title:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}title'],
          )!,
      emoji:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}emoji'],
          )!,
      description:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}description'],
          )!,
      colorValue:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}color_value'],
          )!,
      dueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due_at'],
      ),
      budgetMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}budget_minutes'],
      ),
      archived:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}archived'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}created_at'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $ProjectRecordsTable createAlias(String alias) {
    return $ProjectRecordsTable(attachedDatabase, alias);
  }
}

class ProjectRecord extends DataClass implements Insertable<ProjectRecord> {
  final String id;
  final String title;
  final String emoji;
  final String description;
  final int colorValue;
  final String? dueAt;
  final int? budgetMinutes;
  final bool archived;
  final String createdAt;
  final String updatedAt;
  const ProjectRecord({
    required this.id,
    required this.title,
    required this.emoji,
    required this.description,
    required this.colorValue,
    this.dueAt,
    this.budgetMinutes,
    required this.archived,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['emoji'] = Variable<String>(emoji);
    map['description'] = Variable<String>(description);
    map['color_value'] = Variable<int>(colorValue);
    if (!nullToAbsent || dueAt != null) {
      map['due_at'] = Variable<String>(dueAt);
    }
    if (!nullToAbsent || budgetMinutes != null) {
      map['budget_minutes'] = Variable<int>(budgetMinutes);
    }
    map['archived'] = Variable<bool>(archived);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  ProjectRecordsCompanion toCompanion(bool nullToAbsent) {
    return ProjectRecordsCompanion(
      id: Value(id),
      title: Value(title),
      emoji: Value(emoji),
      description: Value(description),
      colorValue: Value(colorValue),
      dueAt:
          dueAt == null && nullToAbsent ? const Value.absent() : Value(dueAt),
      budgetMinutes:
          budgetMinutes == null && nullToAbsent
              ? const Value.absent()
              : Value(budgetMinutes),
      archived: Value(archived),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ProjectRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProjectRecord(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      emoji: serializer.fromJson<String>(json['emoji']),
      description: serializer.fromJson<String>(json['description']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      dueAt: serializer.fromJson<String?>(json['dueAt']),
      budgetMinutes: serializer.fromJson<int?>(json['budgetMinutes']),
      archived: serializer.fromJson<bool>(json['archived']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'emoji': serializer.toJson<String>(emoji),
      'description': serializer.toJson<String>(description),
      'colorValue': serializer.toJson<int>(colorValue),
      'dueAt': serializer.toJson<String?>(dueAt),
      'budgetMinutes': serializer.toJson<int?>(budgetMinutes),
      'archived': serializer.toJson<bool>(archived),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  ProjectRecord copyWith({
    String? id,
    String? title,
    String? emoji,
    String? description,
    int? colorValue,
    Value<String?> dueAt = const Value.absent(),
    Value<int?> budgetMinutes = const Value.absent(),
    bool? archived,
    String? createdAt,
    String? updatedAt,
  }) => ProjectRecord(
    id: id ?? this.id,
    title: title ?? this.title,
    emoji: emoji ?? this.emoji,
    description: description ?? this.description,
    colorValue: colorValue ?? this.colorValue,
    dueAt: dueAt.present ? dueAt.value : this.dueAt,
    budgetMinutes:
        budgetMinutes.present ? budgetMinutes.value : this.budgetMinutes,
    archived: archived ?? this.archived,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ProjectRecord copyWithCompanion(ProjectRecordsCompanion data) {
    return ProjectRecord(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      emoji: data.emoji.present ? data.emoji.value : this.emoji,
      description:
          data.description.present ? data.description.value : this.description,
      colorValue:
          data.colorValue.present ? data.colorValue.value : this.colorValue,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      budgetMinutes:
          data.budgetMinutes.present
              ? data.budgetMinutes.value
              : this.budgetMinutes,
      archived: data.archived.present ? data.archived.value : this.archived,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjectRecord(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('emoji: $emoji, ')
          ..write('description: $description, ')
          ..write('colorValue: $colorValue, ')
          ..write('dueAt: $dueAt, ')
          ..write('budgetMinutes: $budgetMinutes, ')
          ..write('archived: $archived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    emoji,
    description,
    colorValue,
    dueAt,
    budgetMinutes,
    archived,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectRecord &&
          other.id == this.id &&
          other.title == this.title &&
          other.emoji == this.emoji &&
          other.description == this.description &&
          other.colorValue == this.colorValue &&
          other.dueAt == this.dueAt &&
          other.budgetMinutes == this.budgetMinutes &&
          other.archived == this.archived &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ProjectRecordsCompanion extends UpdateCompanion<ProjectRecord> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> emoji;
  final Value<String> description;
  final Value<int> colorValue;
  final Value<String?> dueAt;
  final Value<int?> budgetMinutes;
  final Value<bool> archived;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const ProjectRecordsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.emoji = const Value.absent(),
    this.description = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.budgetMinutes = const Value.absent(),
    this.archived = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectRecordsCompanion.insert({
    required String id,
    required String title,
    this.emoji = const Value.absent(),
    this.description = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.budgetMinutes = const Value.absent(),
    this.archived = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ProjectRecord> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? emoji,
    Expression<String>? description,
    Expression<int>? colorValue,
    Expression<String>? dueAt,
    Expression<int>? budgetMinutes,
    Expression<bool>? archived,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (emoji != null) 'emoji': emoji,
      if (description != null) 'description': description,
      if (colorValue != null) 'color_value': colorValue,
      if (dueAt != null) 'due_at': dueAt,
      if (budgetMinutes != null) 'budget_minutes': budgetMinutes,
      if (archived != null) 'archived': archived,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? emoji,
    Value<String>? description,
    Value<int>? colorValue,
    Value<String?>? dueAt,
    Value<int?>? budgetMinutes,
    Value<bool>? archived,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return ProjectRecordsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      emoji: emoji ?? this.emoji,
      description: description ?? this.description,
      colorValue: colorValue ?? this.colorValue,
      dueAt: dueAt ?? this.dueAt,
      budgetMinutes: budgetMinutes ?? this.budgetMinutes,
      archived: archived ?? this.archived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (emoji.present) {
      map['emoji'] = Variable<String>(emoji.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<String>(dueAt.value);
    }
    if (budgetMinutes.present) {
      map['budget_minutes'] = Variable<int>(budgetMinutes.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectRecordsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('emoji: $emoji, ')
          ..write('description: $description, ')
          ..write('colorValue: $colorValue, ')
          ..write('dueAt: $dueAt, ')
          ..write('budgetMinutes: $budgetMinutes, ')
          ..write('archived: $archived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NoteRecordsTable extends NoteRecords
    with TableInfo<$NoteRecordsTable, NoteRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _tagsJsonMeta = const VerificationMeta(
    'tagsJson',
  );
  @override
  late final GeneratedColumn<String> tagsJson = GeneratedColumn<String>(
    'tags_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('draft'),
  );
  static const VerificationMeta _folderPathMeta = const VerificationMeta(
    'folderPath',
  );
  @override
  late final GeneratedColumn<String> folderPath = GeneratedColumn<String>(
    'folder_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _noteTypeMeta = const VerificationMeta(
    'noteType',
  );
  @override
  late final GeneratedColumn<String> noteType = GeneratedColumn<String>(
    'note_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('note'),
  );
  static const VerificationMeta _propertiesJsonMeta = const VerificationMeta(
    'propertiesJson',
  );
  @override
  late final GeneratedColumn<String> propertiesJson = GeneratedColumn<String>(
    'properties_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<bool> pinned = GeneratedColumn<bool>(
    'pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    title,
    body,
    tagsJson,
    status,
    folderPath,
    noteType,
    propertiesJson,
    pinned,
    revision,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('tags_json')) {
      context.handle(
        _tagsJsonMeta,
        tagsJson.isAcceptableOrUnknown(data['tags_json']!, _tagsJsonMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('folder_path')) {
      context.handle(
        _folderPathMeta,
        folderPath.isAcceptableOrUnknown(data['folder_path']!, _folderPathMeta),
      );
    }
    if (data.containsKey('note_type')) {
      context.handle(
        _noteTypeMeta,
        noteType.isAcceptableOrUnknown(data['note_type']!, _noteTypeMeta),
      );
    }
    if (data.containsKey('properties_json')) {
      context.handle(
        _propertiesJsonMeta,
        propertiesJson.isAcceptableOrUnknown(
          data['properties_json']!,
          _propertiesJsonMeta,
        ),
      );
    }
    if (data.containsKey('pinned')) {
      context.handle(
        _pinnedMeta,
        pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NoteRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteRecord(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      projectId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}project_id'],
          )!,
      title:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}title'],
          )!,
      body:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}body'],
          )!,
      tagsJson:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}tags_json'],
          )!,
      status:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}status'],
          )!,
      folderPath:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}folder_path'],
          )!,
      noteType:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}note_type'],
          )!,
      propertiesJson:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}properties_json'],
          )!,
      pinned:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}pinned'],
          )!,
      revision:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}revision'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}created_at'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}updated_at'],
          )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $NoteRecordsTable createAlias(String alias) {
    return $NoteRecordsTable(attachedDatabase, alias);
  }
}

class NoteRecord extends DataClass implements Insertable<NoteRecord> {
  final String id;
  final String projectId;
  final String title;
  final String body;
  final String tagsJson;
  final String status;
  final String folderPath;
  final String noteType;
  final String propertiesJson;
  final bool pinned;
  final int revision;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  const NoteRecord({
    required this.id,
    required this.projectId,
    required this.title,
    required this.body,
    required this.tagsJson,
    required this.status,
    required this.folderPath,
    required this.noteType,
    required this.propertiesJson,
    required this.pinned,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    map['tags_json'] = Variable<String>(tagsJson);
    map['status'] = Variable<String>(status);
    map['folder_path'] = Variable<String>(folderPath);
    map['note_type'] = Variable<String>(noteType);
    map['properties_json'] = Variable<String>(propertiesJson);
    map['pinned'] = Variable<bool>(pinned);
    map['revision'] = Variable<int>(revision);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  NoteRecordsCompanion toCompanion(bool nullToAbsent) {
    return NoteRecordsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      title: Value(title),
      body: Value(body),
      tagsJson: Value(tagsJson),
      status: Value(status),
      folderPath: Value(folderPath),
      noteType: Value(noteType),
      propertiesJson: Value(propertiesJson),
      pinned: Value(pinned),
      revision: Value(revision),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt:
          deletedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(deletedAt),
    );
  }

  factory NoteRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteRecord(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      tagsJson: serializer.fromJson<String>(json['tagsJson']),
      status: serializer.fromJson<String>(json['status']),
      folderPath: serializer.fromJson<String>(json['folderPath']),
      noteType: serializer.fromJson<String>(json['noteType']),
      propertiesJson: serializer.fromJson<String>(json['propertiesJson']),
      pinned: serializer.fromJson<bool>(json['pinned']),
      revision: serializer.fromJson<int>(json['revision']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'tagsJson': serializer.toJson<String>(tagsJson),
      'status': serializer.toJson<String>(status),
      'folderPath': serializer.toJson<String>(folderPath),
      'noteType': serializer.toJson<String>(noteType),
      'propertiesJson': serializer.toJson<String>(propertiesJson),
      'pinned': serializer.toJson<bool>(pinned),
      'revision': serializer.toJson<int>(revision),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  NoteRecord copyWith({
    String? id,
    String? projectId,
    String? title,
    String? body,
    String? tagsJson,
    String? status,
    String? folderPath,
    String? noteType,
    String? propertiesJson,
    bool? pinned,
    int? revision,
    String? createdAt,
    String? updatedAt,
    Value<String?> deletedAt = const Value.absent(),
  }) => NoteRecord(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    title: title ?? this.title,
    body: body ?? this.body,
    tagsJson: tagsJson ?? this.tagsJson,
    status: status ?? this.status,
    folderPath: folderPath ?? this.folderPath,
    noteType: noteType ?? this.noteType,
    propertiesJson: propertiesJson ?? this.propertiesJson,
    pinned: pinned ?? this.pinned,
    revision: revision ?? this.revision,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  NoteRecord copyWithCompanion(NoteRecordsCompanion data) {
    return NoteRecord(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      tagsJson: data.tagsJson.present ? data.tagsJson.value : this.tagsJson,
      status: data.status.present ? data.status.value : this.status,
      folderPath:
          data.folderPath.present ? data.folderPath.value : this.folderPath,
      noteType: data.noteType.present ? data.noteType.value : this.noteType,
      propertiesJson:
          data.propertiesJson.present
              ? data.propertiesJson.value
              : this.propertiesJson,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
      revision: data.revision.present ? data.revision.value : this.revision,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteRecord(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('status: $status, ')
          ..write('folderPath: $folderPath, ')
          ..write('noteType: $noteType, ')
          ..write('propertiesJson: $propertiesJson, ')
          ..write('pinned: $pinned, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    title,
    body,
    tagsJson,
    status,
    folderPath,
    noteType,
    propertiesJson,
    pinned,
    revision,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteRecord &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.title == this.title &&
          other.body == this.body &&
          other.tagsJson == this.tagsJson &&
          other.status == this.status &&
          other.folderPath == this.folderPath &&
          other.noteType == this.noteType &&
          other.propertiesJson == this.propertiesJson &&
          other.pinned == this.pinned &&
          other.revision == this.revision &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class NoteRecordsCompanion extends UpdateCompanion<NoteRecord> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> title;
  final Value<String> body;
  final Value<String> tagsJson;
  final Value<String> status;
  final Value<String> folderPath;
  final Value<String> noteType;
  final Value<String> propertiesJson;
  final Value<bool> pinned;
  final Value<int> revision;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const NoteRecordsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.status = const Value.absent(),
    this.folderPath = const Value.absent(),
    this.noteType = const Value.absent(),
    this.propertiesJson = const Value.absent(),
    this.pinned = const Value.absent(),
    this.revision = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteRecordsCompanion.insert({
    required String id,
    required String projectId,
    required String title,
    this.body = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.status = const Value.absent(),
    this.folderPath = const Value.absent(),
    this.noteType = const Value.absent(),
    this.propertiesJson = const Value.absent(),
    this.pinned = const Value.absent(),
    this.revision = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<NoteRecord> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? title,
    Expression<String>? body,
    Expression<String>? tagsJson,
    Expression<String>? status,
    Expression<String>? folderPath,
    Expression<String>? noteType,
    Expression<String>? propertiesJson,
    Expression<bool>? pinned,
    Expression<int>? revision,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (tagsJson != null) 'tags_json': tagsJson,
      if (status != null) 'status': status,
      if (folderPath != null) 'folder_path': folderPath,
      if (noteType != null) 'note_type': noteType,
      if (propertiesJson != null) 'properties_json': propertiesJson,
      if (pinned != null) 'pinned': pinned,
      if (revision != null) 'revision': revision,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<String>? title,
    Value<String>? body,
    Value<String>? tagsJson,
    Value<String>? status,
    Value<String>? folderPath,
    Value<String>? noteType,
    Value<String>? propertiesJson,
    Value<bool>? pinned,
    Value<int>? revision,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return NoteRecordsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      body: body ?? this.body,
      tagsJson: tagsJson ?? this.tagsJson,
      status: status ?? this.status,
      folderPath: folderPath ?? this.folderPath,
      noteType: noteType ?? this.noteType,
      propertiesJson: propertiesJson ?? this.propertiesJson,
      pinned: pinned ?? this.pinned,
      revision: revision ?? this.revision,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (tagsJson.present) {
      map['tags_json'] = Variable<String>(tagsJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (folderPath.present) {
      map['folder_path'] = Variable<String>(folderPath.value);
    }
    if (noteType.present) {
      map['note_type'] = Variable<String>(noteType.value);
    }
    if (propertiesJson.present) {
      map['properties_json'] = Variable<String>(propertiesJson.value);
    }
    if (pinned.present) {
      map['pinned'] = Variable<bool>(pinned.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteRecordsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('status: $status, ')
          ..write('folderPath: $folderPath, ')
          ..write('noteType: $noteType, ')
          ..write('propertiesJson: $propertiesJson, ')
          ..write('pinned: $pinned, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NoteLinkRecordsTable extends NoteLinkRecords
    with TableInfo<$NoteLinkRecordsTable, NoteLinkRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteLinkRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceNoteIdMeta = const VerificationMeta(
    'sourceNoteId',
  );
  @override
  late final GeneratedColumn<String> sourceNoteId = GeneratedColumn<String>(
    'source_note_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES notes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _targetTitleMeta = const VerificationMeta(
    'targetTitle',
  );
  @override
  late final GeneratedColumn<String> targetTitle = GeneratedColumn<String>(
    'target_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetNoteIdMeta = const VerificationMeta(
    'targetNoteId',
  );
  @override
  late final GeneratedColumn<String> targetNoteId = GeneratedColumn<String>(
    'target_note_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES notes (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceNoteId,
    targetTitle,
    targetNoteId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_links';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteLinkRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_note_id')) {
      context.handle(
        _sourceNoteIdMeta,
        sourceNoteId.isAcceptableOrUnknown(
          data['source_note_id']!,
          _sourceNoteIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceNoteIdMeta);
    }
    if (data.containsKey('target_title')) {
      context.handle(
        _targetTitleMeta,
        targetTitle.isAcceptableOrUnknown(
          data['target_title']!,
          _targetTitleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetTitleMeta);
    }
    if (data.containsKey('target_note_id')) {
      context.handle(
        _targetNoteIdMeta,
        targetNoteId.isAcceptableOrUnknown(
          data['target_note_id']!,
          _targetNoteIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NoteLinkRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteLinkRecord(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      sourceNoteId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}source_note_id'],
          )!,
      targetTitle:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}target_title'],
          )!,
      targetNoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_note_id'],
      ),
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}created_at'],
          )!,
    );
  }

  @override
  $NoteLinkRecordsTable createAlias(String alias) {
    return $NoteLinkRecordsTable(attachedDatabase, alias);
  }
}

class NoteLinkRecord extends DataClass implements Insertable<NoteLinkRecord> {
  final String id;
  final String sourceNoteId;
  final String targetTitle;
  final String? targetNoteId;
  final String createdAt;
  const NoteLinkRecord({
    required this.id,
    required this.sourceNoteId,
    required this.targetTitle,
    this.targetNoteId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source_note_id'] = Variable<String>(sourceNoteId);
    map['target_title'] = Variable<String>(targetTitle);
    if (!nullToAbsent || targetNoteId != null) {
      map['target_note_id'] = Variable<String>(targetNoteId);
    }
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  NoteLinkRecordsCompanion toCompanion(bool nullToAbsent) {
    return NoteLinkRecordsCompanion(
      id: Value(id),
      sourceNoteId: Value(sourceNoteId),
      targetTitle: Value(targetTitle),
      targetNoteId:
          targetNoteId == null && nullToAbsent
              ? const Value.absent()
              : Value(targetNoteId),
      createdAt: Value(createdAt),
    );
  }

  factory NoteLinkRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteLinkRecord(
      id: serializer.fromJson<String>(json['id']),
      sourceNoteId: serializer.fromJson<String>(json['sourceNoteId']),
      targetTitle: serializer.fromJson<String>(json['targetTitle']),
      targetNoteId: serializer.fromJson<String?>(json['targetNoteId']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourceNoteId': serializer.toJson<String>(sourceNoteId),
      'targetTitle': serializer.toJson<String>(targetTitle),
      'targetNoteId': serializer.toJson<String?>(targetNoteId),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  NoteLinkRecord copyWith({
    String? id,
    String? sourceNoteId,
    String? targetTitle,
    Value<String?> targetNoteId = const Value.absent(),
    String? createdAt,
  }) => NoteLinkRecord(
    id: id ?? this.id,
    sourceNoteId: sourceNoteId ?? this.sourceNoteId,
    targetTitle: targetTitle ?? this.targetTitle,
    targetNoteId: targetNoteId.present ? targetNoteId.value : this.targetNoteId,
    createdAt: createdAt ?? this.createdAt,
  );
  NoteLinkRecord copyWithCompanion(NoteLinkRecordsCompanion data) {
    return NoteLinkRecord(
      id: data.id.present ? data.id.value : this.id,
      sourceNoteId:
          data.sourceNoteId.present
              ? data.sourceNoteId.value
              : this.sourceNoteId,
      targetTitle:
          data.targetTitle.present ? data.targetTitle.value : this.targetTitle,
      targetNoteId:
          data.targetNoteId.present
              ? data.targetNoteId.value
              : this.targetNoteId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteLinkRecord(')
          ..write('id: $id, ')
          ..write('sourceNoteId: $sourceNoteId, ')
          ..write('targetTitle: $targetTitle, ')
          ..write('targetNoteId: $targetNoteId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, sourceNoteId, targetTitle, targetNoteId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteLinkRecord &&
          other.id == this.id &&
          other.sourceNoteId == this.sourceNoteId &&
          other.targetTitle == this.targetTitle &&
          other.targetNoteId == this.targetNoteId &&
          other.createdAt == this.createdAt);
}

class NoteLinkRecordsCompanion extends UpdateCompanion<NoteLinkRecord> {
  final Value<String> id;
  final Value<String> sourceNoteId;
  final Value<String> targetTitle;
  final Value<String?> targetNoteId;
  final Value<String> createdAt;
  final Value<int> rowid;
  const NoteLinkRecordsCompanion({
    this.id = const Value.absent(),
    this.sourceNoteId = const Value.absent(),
    this.targetTitle = const Value.absent(),
    this.targetNoteId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteLinkRecordsCompanion.insert({
    required String id,
    required String sourceNoteId,
    required String targetTitle,
    this.targetNoteId = const Value.absent(),
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sourceNoteId = Value(sourceNoteId),
       targetTitle = Value(targetTitle),
       createdAt = Value(createdAt);
  static Insertable<NoteLinkRecord> custom({
    Expression<String>? id,
    Expression<String>? sourceNoteId,
    Expression<String>? targetTitle,
    Expression<String>? targetNoteId,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceNoteId != null) 'source_note_id': sourceNoteId,
      if (targetTitle != null) 'target_title': targetTitle,
      if (targetNoteId != null) 'target_note_id': targetNoteId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteLinkRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? sourceNoteId,
    Value<String>? targetTitle,
    Value<String?>? targetNoteId,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return NoteLinkRecordsCompanion(
      id: id ?? this.id,
      sourceNoteId: sourceNoteId ?? this.sourceNoteId,
      targetTitle: targetTitle ?? this.targetTitle,
      targetNoteId: targetNoteId ?? this.targetNoteId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourceNoteId.present) {
      map['source_note_id'] = Variable<String>(sourceNoteId.value);
    }
    if (targetTitle.present) {
      map['target_title'] = Variable<String>(targetTitle.value);
    }
    if (targetNoteId.present) {
      map['target_note_id'] = Variable<String>(targetNoteId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteLinkRecordsCompanion(')
          ..write('id: $id, ')
          ..write('sourceNoteId: $sourceNoteId, ')
          ..write('targetTitle: $targetTitle, ')
          ..write('targetNoteId: $targetNoteId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NoteVersionRecordsTable extends NoteVersionRecords
    with TableInfo<$NoteVersionRecordsTable, NoteVersionRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteVersionRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
    'note_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES notes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _tagsJsonMeta = const VerificationMeta(
    'tagsJson',
  );
  @override
  late final GeneratedColumn<String> tagsJson = GeneratedColumn<String>(
    'tags_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('draft'),
  );
  static const VerificationMeta _folderPathMeta = const VerificationMeta(
    'folderPath',
  );
  @override
  late final GeneratedColumn<String> folderPath = GeneratedColumn<String>(
    'folder_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _noteTypeMeta = const VerificationMeta(
    'noteType',
  );
  @override
  late final GeneratedColumn<String> noteType = GeneratedColumn<String>(
    'note_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('note'),
  );
  static const VerificationMeta _propertiesJsonMeta = const VerificationMeta(
    'propertiesJson',
  );
  @override
  late final GeneratedColumn<String> propertiesJson = GeneratedColumn<String>(
    'properties_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    noteId,
    title,
    body,
    tagsJson,
    status,
    folderPath,
    noteType,
    propertiesJson,
    reason,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_versions';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteVersionRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_noteIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('tags_json')) {
      context.handle(
        _tagsJsonMeta,
        tagsJson.isAcceptableOrUnknown(data['tags_json']!, _tagsJsonMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('folder_path')) {
      context.handle(
        _folderPathMeta,
        folderPath.isAcceptableOrUnknown(data['folder_path']!, _folderPathMeta),
      );
    }
    if (data.containsKey('note_type')) {
      context.handle(
        _noteTypeMeta,
        noteType.isAcceptableOrUnknown(data['note_type']!, _noteTypeMeta),
      );
    }
    if (data.containsKey('properties_json')) {
      context.handle(
        _propertiesJsonMeta,
        propertiesJson.isAcceptableOrUnknown(
          data['properties_json']!,
          _propertiesJsonMeta,
        ),
      );
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NoteVersionRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteVersionRecord(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      noteId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}note_id'],
          )!,
      title:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}title'],
          )!,
      body:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}body'],
          )!,
      tagsJson:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}tags_json'],
          )!,
      status:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}status'],
          )!,
      folderPath:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}folder_path'],
          )!,
      noteType:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}note_type'],
          )!,
      propertiesJson:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}properties_json'],
          )!,
      reason:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}reason'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}created_at'],
          )!,
    );
  }

  @override
  $NoteVersionRecordsTable createAlias(String alias) {
    return $NoteVersionRecordsTable(attachedDatabase, alias);
  }
}

class NoteVersionRecord extends DataClass
    implements Insertable<NoteVersionRecord> {
  final String id;
  final String noteId;
  final String title;
  final String body;
  final String tagsJson;
  final String status;
  final String folderPath;
  final String noteType;
  final String propertiesJson;
  final String reason;
  final String createdAt;
  const NoteVersionRecord({
    required this.id,
    required this.noteId,
    required this.title,
    required this.body,
    required this.tagsJson,
    required this.status,
    required this.folderPath,
    required this.noteType,
    required this.propertiesJson,
    required this.reason,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['note_id'] = Variable<String>(noteId);
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    map['tags_json'] = Variable<String>(tagsJson);
    map['status'] = Variable<String>(status);
    map['folder_path'] = Variable<String>(folderPath);
    map['note_type'] = Variable<String>(noteType);
    map['properties_json'] = Variable<String>(propertiesJson);
    map['reason'] = Variable<String>(reason);
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  NoteVersionRecordsCompanion toCompanion(bool nullToAbsent) {
    return NoteVersionRecordsCompanion(
      id: Value(id),
      noteId: Value(noteId),
      title: Value(title),
      body: Value(body),
      tagsJson: Value(tagsJson),
      status: Value(status),
      folderPath: Value(folderPath),
      noteType: Value(noteType),
      propertiesJson: Value(propertiesJson),
      reason: Value(reason),
      createdAt: Value(createdAt),
    );
  }

  factory NoteVersionRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteVersionRecord(
      id: serializer.fromJson<String>(json['id']),
      noteId: serializer.fromJson<String>(json['noteId']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      tagsJson: serializer.fromJson<String>(json['tagsJson']),
      status: serializer.fromJson<String>(json['status']),
      folderPath: serializer.fromJson<String>(json['folderPath']),
      noteType: serializer.fromJson<String>(json['noteType']),
      propertiesJson: serializer.fromJson<String>(json['propertiesJson']),
      reason: serializer.fromJson<String>(json['reason']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'noteId': serializer.toJson<String>(noteId),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'tagsJson': serializer.toJson<String>(tagsJson),
      'status': serializer.toJson<String>(status),
      'folderPath': serializer.toJson<String>(folderPath),
      'noteType': serializer.toJson<String>(noteType),
      'propertiesJson': serializer.toJson<String>(propertiesJson),
      'reason': serializer.toJson<String>(reason),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  NoteVersionRecord copyWith({
    String? id,
    String? noteId,
    String? title,
    String? body,
    String? tagsJson,
    String? status,
    String? folderPath,
    String? noteType,
    String? propertiesJson,
    String? reason,
    String? createdAt,
  }) => NoteVersionRecord(
    id: id ?? this.id,
    noteId: noteId ?? this.noteId,
    title: title ?? this.title,
    body: body ?? this.body,
    tagsJson: tagsJson ?? this.tagsJson,
    status: status ?? this.status,
    folderPath: folderPath ?? this.folderPath,
    noteType: noteType ?? this.noteType,
    propertiesJson: propertiesJson ?? this.propertiesJson,
    reason: reason ?? this.reason,
    createdAt: createdAt ?? this.createdAt,
  );
  NoteVersionRecord copyWithCompanion(NoteVersionRecordsCompanion data) {
    return NoteVersionRecord(
      id: data.id.present ? data.id.value : this.id,
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      tagsJson: data.tagsJson.present ? data.tagsJson.value : this.tagsJson,
      status: data.status.present ? data.status.value : this.status,
      folderPath:
          data.folderPath.present ? data.folderPath.value : this.folderPath,
      noteType: data.noteType.present ? data.noteType.value : this.noteType,
      propertiesJson:
          data.propertiesJson.present
              ? data.propertiesJson.value
              : this.propertiesJson,
      reason: data.reason.present ? data.reason.value : this.reason,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteVersionRecord(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('status: $status, ')
          ..write('folderPath: $folderPath, ')
          ..write('noteType: $noteType, ')
          ..write('propertiesJson: $propertiesJson, ')
          ..write('reason: $reason, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    noteId,
    title,
    body,
    tagsJson,
    status,
    folderPath,
    noteType,
    propertiesJson,
    reason,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteVersionRecord &&
          other.id == this.id &&
          other.noteId == this.noteId &&
          other.title == this.title &&
          other.body == this.body &&
          other.tagsJson == this.tagsJson &&
          other.status == this.status &&
          other.folderPath == this.folderPath &&
          other.noteType == this.noteType &&
          other.propertiesJson == this.propertiesJson &&
          other.reason == this.reason &&
          other.createdAt == this.createdAt);
}

class NoteVersionRecordsCompanion extends UpdateCompanion<NoteVersionRecord> {
  final Value<String> id;
  final Value<String> noteId;
  final Value<String> title;
  final Value<String> body;
  final Value<String> tagsJson;
  final Value<String> status;
  final Value<String> folderPath;
  final Value<String> noteType;
  final Value<String> propertiesJson;
  final Value<String> reason;
  final Value<String> createdAt;
  final Value<int> rowid;
  const NoteVersionRecordsCompanion({
    this.id = const Value.absent(),
    this.noteId = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.status = const Value.absent(),
    this.folderPath = const Value.absent(),
    this.noteType = const Value.absent(),
    this.propertiesJson = const Value.absent(),
    this.reason = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteVersionRecordsCompanion.insert({
    required String id,
    required String noteId,
    required String title,
    this.body = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.status = const Value.absent(),
    this.folderPath = const Value.absent(),
    this.noteType = const Value.absent(),
    this.propertiesJson = const Value.absent(),
    this.reason = const Value.absent(),
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       noteId = Value(noteId),
       title = Value(title),
       createdAt = Value(createdAt);
  static Insertable<NoteVersionRecord> custom({
    Expression<String>? id,
    Expression<String>? noteId,
    Expression<String>? title,
    Expression<String>? body,
    Expression<String>? tagsJson,
    Expression<String>? status,
    Expression<String>? folderPath,
    Expression<String>? noteType,
    Expression<String>? propertiesJson,
    Expression<String>? reason,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (noteId != null) 'note_id': noteId,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (tagsJson != null) 'tags_json': tagsJson,
      if (status != null) 'status': status,
      if (folderPath != null) 'folder_path': folderPath,
      if (noteType != null) 'note_type': noteType,
      if (propertiesJson != null) 'properties_json': propertiesJson,
      if (reason != null) 'reason': reason,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteVersionRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? noteId,
    Value<String>? title,
    Value<String>? body,
    Value<String>? tagsJson,
    Value<String>? status,
    Value<String>? folderPath,
    Value<String>? noteType,
    Value<String>? propertiesJson,
    Value<String>? reason,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return NoteVersionRecordsCompanion(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      title: title ?? this.title,
      body: body ?? this.body,
      tagsJson: tagsJson ?? this.tagsJson,
      status: status ?? this.status,
      folderPath: folderPath ?? this.folderPath,
      noteType: noteType ?? this.noteType,
      propertiesJson: propertiesJson ?? this.propertiesJson,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (tagsJson.present) {
      map['tags_json'] = Variable<String>(tagsJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (folderPath.present) {
      map['folder_path'] = Variable<String>(folderPath.value);
    }
    if (noteType.present) {
      map['note_type'] = Variable<String>(noteType.value);
    }
    if (propertiesJson.present) {
      map['properties_json'] = Variable<String>(propertiesJson.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteVersionRecordsCompanion(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('status: $status, ')
          ..write('folderPath: $folderPath, ')
          ..write('noteType: $noteType, ')
          ..write('propertiesJson: $propertiesJson, ')
          ..write('reason: $reason, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TaskRecordsTable extends TaskRecords
    with TableInfo<$TaskRecordsTable, TaskRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _parentTaskIdMeta = const VerificationMeta(
    'parentTaskId',
  );
  @override
  late final GeneratedColumn<String> parentTaskId = GeneratedColumn<String>(
    'parent_task_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
    'note_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES notes (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('next'),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _estimateMinutesMeta = const VerificationMeta(
    'estimateMinutes',
  );
  @override
  late final GeneratedColumn<int> estimateMinutes = GeneratedColumn<int>(
    'estimate_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(30),
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
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<String> dueAt = GeneratedColumn<String>(
    'due_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<String> completedAt = GeneratedColumn<String>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    parentTaskId,
    noteId,
    title,
    description,
    status,
    priority,
    estimateMinutes,
    sortOrder,
    dueAt,
    createdAt,
    updatedAt,
    completedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('parent_task_id')) {
      context.handle(
        _parentTaskIdMeta,
        parentTaskId.isAcceptableOrUnknown(
          data['parent_task_id']!,
          _parentTaskIdMeta,
        ),
      );
    }
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('estimate_minutes')) {
      context.handle(
        _estimateMinutesMeta,
        estimateMinutes.isAcceptableOrUnknown(
          data['estimate_minutes']!,
          _estimateMinutesMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('due_at')) {
      context.handle(
        _dueAtMeta,
        dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskRecord(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      projectId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}project_id'],
          )!,
      parentTaskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_task_id'],
      ),
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_id'],
      ),
      title:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}title'],
          )!,
      description:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}description'],
          )!,
      status:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}status'],
          )!,
      priority:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}priority'],
          )!,
      estimateMinutes:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}estimate_minutes'],
          )!,
      sortOrder:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}sort_order'],
          )!,
      dueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due_at'],
      ),
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}created_at'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}updated_at'],
          )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}completed_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $TaskRecordsTable createAlias(String alias) {
    return $TaskRecordsTable(attachedDatabase, alias);
  }
}

class TaskRecord extends DataClass implements Insertable<TaskRecord> {
  final String id;
  final String projectId;
  final String? parentTaskId;
  final String? noteId;
  final String title;
  final String description;
  final String status;
  final int priority;
  final int estimateMinutes;
  final int sortOrder;
  final String? dueAt;
  final String createdAt;
  final String updatedAt;
  final String? completedAt;
  final String? deletedAt;
  const TaskRecord({
    required this.id,
    required this.projectId,
    this.parentTaskId,
    this.noteId,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.estimateMinutes,
    required this.sortOrder,
    this.dueAt,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    if (!nullToAbsent || parentTaskId != null) {
      map['parent_task_id'] = Variable<String>(parentTaskId);
    }
    if (!nullToAbsent || noteId != null) {
      map['note_id'] = Variable<String>(noteId);
    }
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['status'] = Variable<String>(status);
    map['priority'] = Variable<int>(priority);
    map['estimate_minutes'] = Variable<int>(estimateMinutes);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || dueAt != null) {
      map['due_at'] = Variable<String>(dueAt);
    }
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<String>(completedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  TaskRecordsCompanion toCompanion(bool nullToAbsent) {
    return TaskRecordsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      parentTaskId:
          parentTaskId == null && nullToAbsent
              ? const Value.absent()
              : Value(parentTaskId),
      noteId:
          noteId == null && nullToAbsent ? const Value.absent() : Value(noteId),
      title: Value(title),
      description: Value(description),
      status: Value(status),
      priority: Value(priority),
      estimateMinutes: Value(estimateMinutes),
      sortOrder: Value(sortOrder),
      dueAt:
          dueAt == null && nullToAbsent ? const Value.absent() : Value(dueAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      completedAt:
          completedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(completedAt),
      deletedAt:
          deletedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(deletedAt),
    );
  }

  factory TaskRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskRecord(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      parentTaskId: serializer.fromJson<String?>(json['parentTaskId']),
      noteId: serializer.fromJson<String?>(json['noteId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      status: serializer.fromJson<String>(json['status']),
      priority: serializer.fromJson<int>(json['priority']),
      estimateMinutes: serializer.fromJson<int>(json['estimateMinutes']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      dueAt: serializer.fromJson<String?>(json['dueAt']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      completedAt: serializer.fromJson<String?>(json['completedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'parentTaskId': serializer.toJson<String?>(parentTaskId),
      'noteId': serializer.toJson<String?>(noteId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'status': serializer.toJson<String>(status),
      'priority': serializer.toJson<int>(priority),
      'estimateMinutes': serializer.toJson<int>(estimateMinutes),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'dueAt': serializer.toJson<String?>(dueAt),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'completedAt': serializer.toJson<String?>(completedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  TaskRecord copyWith({
    String? id,
    String? projectId,
    Value<String?> parentTaskId = const Value.absent(),
    Value<String?> noteId = const Value.absent(),
    String? title,
    String? description,
    String? status,
    int? priority,
    int? estimateMinutes,
    int? sortOrder,
    Value<String?> dueAt = const Value.absent(),
    String? createdAt,
    String? updatedAt,
    Value<String?> completedAt = const Value.absent(),
    Value<String?> deletedAt = const Value.absent(),
  }) => TaskRecord(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    parentTaskId: parentTaskId.present ? parentTaskId.value : this.parentTaskId,
    noteId: noteId.present ? noteId.value : this.noteId,
    title: title ?? this.title,
    description: description ?? this.description,
    status: status ?? this.status,
    priority: priority ?? this.priority,
    estimateMinutes: estimateMinutes ?? this.estimateMinutes,
    sortOrder: sortOrder ?? this.sortOrder,
    dueAt: dueAt.present ? dueAt.value : this.dueAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  TaskRecord copyWithCompanion(TaskRecordsCompanion data) {
    return TaskRecord(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      parentTaskId:
          data.parentTaskId.present
              ? data.parentTaskId.value
              : this.parentTaskId,
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      title: data.title.present ? data.title.value : this.title,
      description:
          data.description.present ? data.description.value : this.description,
      status: data.status.present ? data.status.value : this.status,
      priority: data.priority.present ? data.priority.value : this.priority,
      estimateMinutes:
          data.estimateMinutes.present
              ? data.estimateMinutes.value
              : this.estimateMinutes,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      completedAt:
          data.completedAt.present ? data.completedAt.value : this.completedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskRecord(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('parentTaskId: $parentTaskId, ')
          ..write('noteId: $noteId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('status: $status, ')
          ..write('priority: $priority, ')
          ..write('estimateMinutes: $estimateMinutes, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('dueAt: $dueAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    parentTaskId,
    noteId,
    title,
    description,
    status,
    priority,
    estimateMinutes,
    sortOrder,
    dueAt,
    createdAt,
    updatedAt,
    completedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskRecord &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.parentTaskId == this.parentTaskId &&
          other.noteId == this.noteId &&
          other.title == this.title &&
          other.description == this.description &&
          other.status == this.status &&
          other.priority == this.priority &&
          other.estimateMinutes == this.estimateMinutes &&
          other.sortOrder == this.sortOrder &&
          other.dueAt == this.dueAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.completedAt == this.completedAt &&
          other.deletedAt == this.deletedAt);
}

class TaskRecordsCompanion extends UpdateCompanion<TaskRecord> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String?> parentTaskId;
  final Value<String?> noteId;
  final Value<String> title;
  final Value<String> description;
  final Value<String> status;
  final Value<int> priority;
  final Value<int> estimateMinutes;
  final Value<int> sortOrder;
  final Value<String?> dueAt;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<String?> completedAt;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const TaskRecordsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.parentTaskId = const Value.absent(),
    this.noteId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.status = const Value.absent(),
    this.priority = const Value.absent(),
    this.estimateMinutes = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskRecordsCompanion.insert({
    required String id,
    required String projectId,
    this.parentTaskId = const Value.absent(),
    this.noteId = const Value.absent(),
    required String title,
    this.description = const Value.absent(),
    this.status = const Value.absent(),
    this.priority = const Value.absent(),
    this.estimateMinutes = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.dueAt = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.completedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TaskRecord> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? parentTaskId,
    Expression<String>? noteId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? status,
    Expression<int>? priority,
    Expression<int>? estimateMinutes,
    Expression<int>? sortOrder,
    Expression<String>? dueAt,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? completedAt,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (parentTaskId != null) 'parent_task_id': parentTaskId,
      if (noteId != null) 'note_id': noteId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (status != null) 'status': status,
      if (priority != null) 'priority': priority,
      if (estimateMinutes != null) 'estimate_minutes': estimateMinutes,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (dueAt != null) 'due_at': dueAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<String?>? parentTaskId,
    Value<String?>? noteId,
    Value<String>? title,
    Value<String>? description,
    Value<String>? status,
    Value<int>? priority,
    Value<int>? estimateMinutes,
    Value<int>? sortOrder,
    Value<String?>? dueAt,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<String?>? completedAt,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return TaskRecordsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      noteId: noteId ?? this.noteId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      estimateMinutes: estimateMinutes ?? this.estimateMinutes,
      sortOrder: sortOrder ?? this.sortOrder,
      dueAt: dueAt ?? this.dueAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (parentTaskId.present) {
      map['parent_task_id'] = Variable<String>(parentTaskId.value);
    }
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (estimateMinutes.present) {
      map['estimate_minutes'] = Variable<int>(estimateMinutes.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<String>(dueAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<String>(completedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskRecordsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('parentTaskId: $parentTaskId, ')
          ..write('noteId: $noteId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('status: $status, ')
          ..write('priority: $priority, ')
          ..write('estimateMinutes: $estimateMinutes, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('dueAt: $dueAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TimeEntryRecordsTable extends TimeEntryRecords
    with TableInfo<$TimeEntryRecordsTable, TimeEntryRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TimeEntryRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tasks (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
    'note_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES notes (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<String> startedAt = GeneratedColumn<String>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    taskId,
    noteId,
    description,
    startedAt,
    durationSeconds,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'time_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<TimeEntryRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    }
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_durationSecondsMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TimeEntryRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TimeEntryRecord(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      projectId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}project_id'],
          )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      ),
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_id'],
      ),
      description:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}description'],
          )!,
      startedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}started_at'],
          )!,
      durationSeconds:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}duration_seconds'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}created_at'],
          )!,
    );
  }

  @override
  $TimeEntryRecordsTable createAlias(String alias) {
    return $TimeEntryRecordsTable(attachedDatabase, alias);
  }
}

class TimeEntryRecord extends DataClass implements Insertable<TimeEntryRecord> {
  final String id;
  final String projectId;
  final String? taskId;
  final String? noteId;
  final String description;
  final String startedAt;
  final int durationSeconds;
  final String createdAt;
  const TimeEntryRecord({
    required this.id,
    required this.projectId,
    this.taskId,
    this.noteId,
    required this.description,
    required this.startedAt,
    required this.durationSeconds,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    if (!nullToAbsent || taskId != null) {
      map['task_id'] = Variable<String>(taskId);
    }
    if (!nullToAbsent || noteId != null) {
      map['note_id'] = Variable<String>(noteId);
    }
    map['description'] = Variable<String>(description);
    map['started_at'] = Variable<String>(startedAt);
    map['duration_seconds'] = Variable<int>(durationSeconds);
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  TimeEntryRecordsCompanion toCompanion(bool nullToAbsent) {
    return TimeEntryRecordsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      taskId:
          taskId == null && nullToAbsent ? const Value.absent() : Value(taskId),
      noteId:
          noteId == null && nullToAbsent ? const Value.absent() : Value(noteId),
      description: Value(description),
      startedAt: Value(startedAt),
      durationSeconds: Value(durationSeconds),
      createdAt: Value(createdAt),
    );
  }

  factory TimeEntryRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TimeEntryRecord(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      taskId: serializer.fromJson<String?>(json['taskId']),
      noteId: serializer.fromJson<String?>(json['noteId']),
      description: serializer.fromJson<String>(json['description']),
      startedAt: serializer.fromJson<String>(json['startedAt']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'taskId': serializer.toJson<String?>(taskId),
      'noteId': serializer.toJson<String?>(noteId),
      'description': serializer.toJson<String>(description),
      'startedAt': serializer.toJson<String>(startedAt),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  TimeEntryRecord copyWith({
    String? id,
    String? projectId,
    Value<String?> taskId = const Value.absent(),
    Value<String?> noteId = const Value.absent(),
    String? description,
    String? startedAt,
    int? durationSeconds,
    String? createdAt,
  }) => TimeEntryRecord(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    taskId: taskId.present ? taskId.value : this.taskId,
    noteId: noteId.present ? noteId.value : this.noteId,
    description: description ?? this.description,
    startedAt: startedAt ?? this.startedAt,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    createdAt: createdAt ?? this.createdAt,
  );
  TimeEntryRecord copyWithCompanion(TimeEntryRecordsCompanion data) {
    return TimeEntryRecord(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      description:
          data.description.present ? data.description.value : this.description,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      durationSeconds:
          data.durationSeconds.present
              ? data.durationSeconds.value
              : this.durationSeconds,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TimeEntryRecord(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('taskId: $taskId, ')
          ..write('noteId: $noteId, ')
          ..write('description: $description, ')
          ..write('startedAt: $startedAt, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    taskId,
    noteId,
    description,
    startedAt,
    durationSeconds,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TimeEntryRecord &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.taskId == this.taskId &&
          other.noteId == this.noteId &&
          other.description == this.description &&
          other.startedAt == this.startedAt &&
          other.durationSeconds == this.durationSeconds &&
          other.createdAt == this.createdAt);
}

class TimeEntryRecordsCompanion extends UpdateCompanion<TimeEntryRecord> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String?> taskId;
  final Value<String?> noteId;
  final Value<String> description;
  final Value<String> startedAt;
  final Value<int> durationSeconds;
  final Value<String> createdAt;
  final Value<int> rowid;
  const TimeEntryRecordsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.noteId = const Value.absent(),
    this.description = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TimeEntryRecordsCompanion.insert({
    required String id,
    required String projectId,
    this.taskId = const Value.absent(),
    this.noteId = const Value.absent(),
    this.description = const Value.absent(),
    required String startedAt,
    required int durationSeconds,
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       startedAt = Value(startedAt),
       durationSeconds = Value(durationSeconds),
       createdAt = Value(createdAt);
  static Insertable<TimeEntryRecord> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? taskId,
    Expression<String>? noteId,
    Expression<String>? description,
    Expression<String>? startedAt,
    Expression<int>? durationSeconds,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (taskId != null) 'task_id': taskId,
      if (noteId != null) 'note_id': noteId,
      if (description != null) 'description': description,
      if (startedAt != null) 'started_at': startedAt,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TimeEntryRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<String?>? taskId,
    Value<String?>? noteId,
    Value<String>? description,
    Value<String>? startedAt,
    Value<int>? durationSeconds,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return TimeEntryRecordsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      taskId: taskId ?? this.taskId,
      noteId: noteId ?? this.noteId,
      description: description ?? this.description,
      startedAt: startedAt ?? this.startedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<String>(startedAt.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TimeEntryRecordsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('taskId: $taskId, ')
          ..write('noteId: $noteId, ')
          ..write('description: $description, ')
          ..write('startedAt: $startedAt, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeviceIdentityRecordsTable extends DeviceIdentityRecords
    with TableInfo<$DeviceIdentityRecordsTable, DeviceIdentityRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeviceIdentityRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _platformMeta = const VerificationMeta(
    'platform',
  );
  @override
  late final GeneratedColumn<String> platform = GeneratedColumn<String>(
    'platform',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<String> lastSeenAt = GeneratedColumn<String>(
    'last_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    deviceId,
    displayName,
    platform,
    createdAt,
    lastSeenAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'device_identity';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeviceIdentityRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('platform')) {
      context.handle(
        _platformMeta,
        platform.isAcceptableOrUnknown(data['platform']!, _platformMeta),
      );
    } else if (isInserting) {
      context.missing(_platformMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSeenAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deviceId};
  @override
  DeviceIdentityRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeviceIdentityRecord(
      deviceId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}device_id'],
          )!,
      displayName:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}display_name'],
          )!,
      platform:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}platform'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}created_at'],
          )!,
      lastSeenAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}last_seen_at'],
          )!,
    );
  }

  @override
  $DeviceIdentityRecordsTable createAlias(String alias) {
    return $DeviceIdentityRecordsTable(attachedDatabase, alias);
  }
}

class DeviceIdentityRecord extends DataClass
    implements Insertable<DeviceIdentityRecord> {
  final String deviceId;
  final String displayName;
  final String platform;
  final String createdAt;
  final String lastSeenAt;
  const DeviceIdentityRecord({
    required this.deviceId,
    required this.displayName,
    required this.platform,
    required this.createdAt,
    required this.lastSeenAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['device_id'] = Variable<String>(deviceId);
    map['display_name'] = Variable<String>(displayName);
    map['platform'] = Variable<String>(platform);
    map['created_at'] = Variable<String>(createdAt);
    map['last_seen_at'] = Variable<String>(lastSeenAt);
    return map;
  }

  DeviceIdentityRecordsCompanion toCompanion(bool nullToAbsent) {
    return DeviceIdentityRecordsCompanion(
      deviceId: Value(deviceId),
      displayName: Value(displayName),
      platform: Value(platform),
      createdAt: Value(createdAt),
      lastSeenAt: Value(lastSeenAt),
    );
  }

  factory DeviceIdentityRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeviceIdentityRecord(
      deviceId: serializer.fromJson<String>(json['deviceId']),
      displayName: serializer.fromJson<String>(json['displayName']),
      platform: serializer.fromJson<String>(json['platform']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      lastSeenAt: serializer.fromJson<String>(json['lastSeenAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deviceId': serializer.toJson<String>(deviceId),
      'displayName': serializer.toJson<String>(displayName),
      'platform': serializer.toJson<String>(platform),
      'createdAt': serializer.toJson<String>(createdAt),
      'lastSeenAt': serializer.toJson<String>(lastSeenAt),
    };
  }

  DeviceIdentityRecord copyWith({
    String? deviceId,
    String? displayName,
    String? platform,
    String? createdAt,
    String? lastSeenAt,
  }) => DeviceIdentityRecord(
    deviceId: deviceId ?? this.deviceId,
    displayName: displayName ?? this.displayName,
    platform: platform ?? this.platform,
    createdAt: createdAt ?? this.createdAt,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
  );
  DeviceIdentityRecord copyWithCompanion(DeviceIdentityRecordsCompanion data) {
    return DeviceIdentityRecord(
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      displayName:
          data.displayName.present ? data.displayName.value : this.displayName,
      platform: data.platform.present ? data.platform.value : this.platform,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastSeenAt:
          data.lastSeenAt.present ? data.lastSeenAt.value : this.lastSeenAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeviceIdentityRecord(')
          ..write('deviceId: $deviceId, ')
          ..write('displayName: $displayName, ')
          ..write('platform: $platform, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastSeenAt: $lastSeenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(deviceId, displayName, platform, createdAt, lastSeenAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeviceIdentityRecord &&
          other.deviceId == this.deviceId &&
          other.displayName == this.displayName &&
          other.platform == this.platform &&
          other.createdAt == this.createdAt &&
          other.lastSeenAt == this.lastSeenAt);
}

class DeviceIdentityRecordsCompanion
    extends UpdateCompanion<DeviceIdentityRecord> {
  final Value<String> deviceId;
  final Value<String> displayName;
  final Value<String> platform;
  final Value<String> createdAt;
  final Value<String> lastSeenAt;
  final Value<int> rowid;
  const DeviceIdentityRecordsCompanion({
    this.deviceId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.platform = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeviceIdentityRecordsCompanion.insert({
    required String deviceId,
    required String displayName,
    required String platform,
    required String createdAt,
    required String lastSeenAt,
    this.rowid = const Value.absent(),
  }) : deviceId = Value(deviceId),
       displayName = Value(displayName),
       platform = Value(platform),
       createdAt = Value(createdAt),
       lastSeenAt = Value(lastSeenAt);
  static Insertable<DeviceIdentityRecord> custom({
    Expression<String>? deviceId,
    Expression<String>? displayName,
    Expression<String>? platform,
    Expression<String>? createdAt,
    Expression<String>? lastSeenAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (deviceId != null) 'device_id': deviceId,
      if (displayName != null) 'display_name': displayName,
      if (platform != null) 'platform': platform,
      if (createdAt != null) 'created_at': createdAt,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeviceIdentityRecordsCompanion copyWith({
    Value<String>? deviceId,
    Value<String>? displayName,
    Value<String>? platform,
    Value<String>? createdAt,
    Value<String>? lastSeenAt,
    Value<int>? rowid,
  }) {
    return DeviceIdentityRecordsCompanion(
      deviceId: deviceId ?? this.deviceId,
      displayName: displayName ?? this.displayName,
      platform: platform ?? this.platform,
      createdAt: createdAt ?? this.createdAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (platform.present) {
      map['platform'] = Variable<String>(platform.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<String>(lastSeenAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeviceIdentityRecordsCompanion(')
          ..write('deviceId: $deviceId, ')
          ..write('displayName: $displayName, ')
          ..write('platform: $platform, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TrustedDeviceRecordsTable extends TrustedDeviceRecords
    with TableInfo<$TrustedDeviceRecordsTable, TrustedDeviceRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrustedDeviceRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _platformMeta = const VerificationMeta(
    'platform',
  );
  @override
  late final GeneratedColumn<String> platform = GeneratedColumn<String>(
    'platform',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _publicKeyMeta = const VerificationMeta(
    'publicKey',
  );
  @override
  late final GeneratedColumn<String> publicKey = GeneratedColumn<String>(
    'public_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pairedAtMeta = const VerificationMeta(
    'pairedAt',
  );
  @override
  late final GeneratedColumn<String> pairedAt = GeneratedColumn<String>(
    'paired_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<String> lastSeenAt = GeneratedColumn<String>(
    'last_seen_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncAtMeta = const VerificationMeta(
    'lastSyncAt',
  );
  @override
  late final GeneratedColumn<String> lastSyncAt = GeneratedColumn<String>(
    'last_sync_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revokedAtMeta = const VerificationMeta(
    'revokedAt',
  );
  @override
  late final GeneratedColumn<String> revokedAt = GeneratedColumn<String>(
    'revoked_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _autoSyncEnabledMeta = const VerificationMeta(
    'autoSyncEnabled',
  );
  @override
  late final GeneratedColumn<bool> autoSyncEnabled = GeneratedColumn<bool>(
    'auto_sync_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_sync_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    deviceId,
    displayName,
    platform,
    publicKey,
    pairedAt,
    lastSeenAt,
    lastSyncAt,
    revokedAt,
    autoSyncEnabled,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trusted_devices';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrustedDeviceRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('platform')) {
      context.handle(
        _platformMeta,
        platform.isAcceptableOrUnknown(data['platform']!, _platformMeta),
      );
    } else if (isInserting) {
      context.missing(_platformMeta);
    }
    if (data.containsKey('public_key')) {
      context.handle(
        _publicKeyMeta,
        publicKey.isAcceptableOrUnknown(data['public_key']!, _publicKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_publicKeyMeta);
    }
    if (data.containsKey('paired_at')) {
      context.handle(
        _pairedAtMeta,
        pairedAt.isAcceptableOrUnknown(data['paired_at']!, _pairedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_pairedAtMeta);
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    }
    if (data.containsKey('last_sync_at')) {
      context.handle(
        _lastSyncAtMeta,
        lastSyncAt.isAcceptableOrUnknown(
          data['last_sync_at']!,
          _lastSyncAtMeta,
        ),
      );
    }
    if (data.containsKey('revoked_at')) {
      context.handle(
        _revokedAtMeta,
        revokedAt.isAcceptableOrUnknown(data['revoked_at']!, _revokedAtMeta),
      );
    }
    if (data.containsKey('auto_sync_enabled')) {
      context.handle(
        _autoSyncEnabledMeta,
        autoSyncEnabled.isAcceptableOrUnknown(
          data['auto_sync_enabled']!,
          _autoSyncEnabledMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deviceId};
  @override
  TrustedDeviceRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrustedDeviceRecord(
      deviceId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}device_id'],
          )!,
      displayName:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}display_name'],
          )!,
      platform:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}platform'],
          )!,
      publicKey:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}public_key'],
          )!,
      pairedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}paired_at'],
          )!,
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_seen_at'],
      ),
      lastSyncAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_sync_at'],
      ),
      revokedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}revoked_at'],
      ),
      autoSyncEnabled:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}auto_sync_enabled'],
          )!,
    );
  }

  @override
  $TrustedDeviceRecordsTable createAlias(String alias) {
    return $TrustedDeviceRecordsTable(attachedDatabase, alias);
  }
}

class TrustedDeviceRecord extends DataClass
    implements Insertable<TrustedDeviceRecord> {
  final String deviceId;
  final String displayName;
  final String platform;
  final String publicKey;
  final String pairedAt;
  final String? lastSeenAt;
  final String? lastSyncAt;
  final String? revokedAt;
  final bool autoSyncEnabled;
  const TrustedDeviceRecord({
    required this.deviceId,
    required this.displayName,
    required this.platform,
    required this.publicKey,
    required this.pairedAt,
    this.lastSeenAt,
    this.lastSyncAt,
    this.revokedAt,
    required this.autoSyncEnabled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['device_id'] = Variable<String>(deviceId);
    map['display_name'] = Variable<String>(displayName);
    map['platform'] = Variable<String>(platform);
    map['public_key'] = Variable<String>(publicKey);
    map['paired_at'] = Variable<String>(pairedAt);
    if (!nullToAbsent || lastSeenAt != null) {
      map['last_seen_at'] = Variable<String>(lastSeenAt);
    }
    if (!nullToAbsent || lastSyncAt != null) {
      map['last_sync_at'] = Variable<String>(lastSyncAt);
    }
    if (!nullToAbsent || revokedAt != null) {
      map['revoked_at'] = Variable<String>(revokedAt);
    }
    map['auto_sync_enabled'] = Variable<bool>(autoSyncEnabled);
    return map;
  }

  TrustedDeviceRecordsCompanion toCompanion(bool nullToAbsent) {
    return TrustedDeviceRecordsCompanion(
      deviceId: Value(deviceId),
      displayName: Value(displayName),
      platform: Value(platform),
      publicKey: Value(publicKey),
      pairedAt: Value(pairedAt),
      lastSeenAt:
          lastSeenAt == null && nullToAbsent
              ? const Value.absent()
              : Value(lastSeenAt),
      lastSyncAt:
          lastSyncAt == null && nullToAbsent
              ? const Value.absent()
              : Value(lastSyncAt),
      revokedAt:
          revokedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(revokedAt),
      autoSyncEnabled: Value(autoSyncEnabled),
    );
  }

  factory TrustedDeviceRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrustedDeviceRecord(
      deviceId: serializer.fromJson<String>(json['deviceId']),
      displayName: serializer.fromJson<String>(json['displayName']),
      platform: serializer.fromJson<String>(json['platform']),
      publicKey: serializer.fromJson<String>(json['publicKey']),
      pairedAt: serializer.fromJson<String>(json['pairedAt']),
      lastSeenAt: serializer.fromJson<String?>(json['lastSeenAt']),
      lastSyncAt: serializer.fromJson<String?>(json['lastSyncAt']),
      revokedAt: serializer.fromJson<String?>(json['revokedAt']),
      autoSyncEnabled: serializer.fromJson<bool>(json['autoSyncEnabled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deviceId': serializer.toJson<String>(deviceId),
      'displayName': serializer.toJson<String>(displayName),
      'platform': serializer.toJson<String>(platform),
      'publicKey': serializer.toJson<String>(publicKey),
      'pairedAt': serializer.toJson<String>(pairedAt),
      'lastSeenAt': serializer.toJson<String?>(lastSeenAt),
      'lastSyncAt': serializer.toJson<String?>(lastSyncAt),
      'revokedAt': serializer.toJson<String?>(revokedAt),
      'autoSyncEnabled': serializer.toJson<bool>(autoSyncEnabled),
    };
  }

  TrustedDeviceRecord copyWith({
    String? deviceId,
    String? displayName,
    String? platform,
    String? publicKey,
    String? pairedAt,
    Value<String?> lastSeenAt = const Value.absent(),
    Value<String?> lastSyncAt = const Value.absent(),
    Value<String?> revokedAt = const Value.absent(),
    bool? autoSyncEnabled,
  }) => TrustedDeviceRecord(
    deviceId: deviceId ?? this.deviceId,
    displayName: displayName ?? this.displayName,
    platform: platform ?? this.platform,
    publicKey: publicKey ?? this.publicKey,
    pairedAt: pairedAt ?? this.pairedAt,
    lastSeenAt: lastSeenAt.present ? lastSeenAt.value : this.lastSeenAt,
    lastSyncAt: lastSyncAt.present ? lastSyncAt.value : this.lastSyncAt,
    revokedAt: revokedAt.present ? revokedAt.value : this.revokedAt,
    autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
  );
  TrustedDeviceRecord copyWithCompanion(TrustedDeviceRecordsCompanion data) {
    return TrustedDeviceRecord(
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      displayName:
          data.displayName.present ? data.displayName.value : this.displayName,
      platform: data.platform.present ? data.platform.value : this.platform,
      publicKey: data.publicKey.present ? data.publicKey.value : this.publicKey,
      pairedAt: data.pairedAt.present ? data.pairedAt.value : this.pairedAt,
      lastSeenAt:
          data.lastSeenAt.present ? data.lastSeenAt.value : this.lastSeenAt,
      lastSyncAt:
          data.lastSyncAt.present ? data.lastSyncAt.value : this.lastSyncAt,
      revokedAt: data.revokedAt.present ? data.revokedAt.value : this.revokedAt,
      autoSyncEnabled:
          data.autoSyncEnabled.present
              ? data.autoSyncEnabled.value
              : this.autoSyncEnabled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrustedDeviceRecord(')
          ..write('deviceId: $deviceId, ')
          ..write('displayName: $displayName, ')
          ..write('platform: $platform, ')
          ..write('publicKey: $publicKey, ')
          ..write('pairedAt: $pairedAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('revokedAt: $revokedAt, ')
          ..write('autoSyncEnabled: $autoSyncEnabled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    deviceId,
    displayName,
    platform,
    publicKey,
    pairedAt,
    lastSeenAt,
    lastSyncAt,
    revokedAt,
    autoSyncEnabled,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrustedDeviceRecord &&
          other.deviceId == this.deviceId &&
          other.displayName == this.displayName &&
          other.platform == this.platform &&
          other.publicKey == this.publicKey &&
          other.pairedAt == this.pairedAt &&
          other.lastSeenAt == this.lastSeenAt &&
          other.lastSyncAt == this.lastSyncAt &&
          other.revokedAt == this.revokedAt &&
          other.autoSyncEnabled == this.autoSyncEnabled);
}

class TrustedDeviceRecordsCompanion
    extends UpdateCompanion<TrustedDeviceRecord> {
  final Value<String> deviceId;
  final Value<String> displayName;
  final Value<String> platform;
  final Value<String> publicKey;
  final Value<String> pairedAt;
  final Value<String?> lastSeenAt;
  final Value<String?> lastSyncAt;
  final Value<String?> revokedAt;
  final Value<bool> autoSyncEnabled;
  final Value<int> rowid;
  const TrustedDeviceRecordsCompanion({
    this.deviceId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.platform = const Value.absent(),
    this.publicKey = const Value.absent(),
    this.pairedAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
    this.revokedAt = const Value.absent(),
    this.autoSyncEnabled = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrustedDeviceRecordsCompanion.insert({
    required String deviceId,
    required String displayName,
    required String platform,
    required String publicKey,
    required String pairedAt,
    this.lastSeenAt = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
    this.revokedAt = const Value.absent(),
    this.autoSyncEnabled = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : deviceId = Value(deviceId),
       displayName = Value(displayName),
       platform = Value(platform),
       publicKey = Value(publicKey),
       pairedAt = Value(pairedAt);
  static Insertable<TrustedDeviceRecord> custom({
    Expression<String>? deviceId,
    Expression<String>? displayName,
    Expression<String>? platform,
    Expression<String>? publicKey,
    Expression<String>? pairedAt,
    Expression<String>? lastSeenAt,
    Expression<String>? lastSyncAt,
    Expression<String>? revokedAt,
    Expression<bool>? autoSyncEnabled,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (deviceId != null) 'device_id': deviceId,
      if (displayName != null) 'display_name': displayName,
      if (platform != null) 'platform': platform,
      if (publicKey != null) 'public_key': publicKey,
      if (pairedAt != null) 'paired_at': pairedAt,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (lastSyncAt != null) 'last_sync_at': lastSyncAt,
      if (revokedAt != null) 'revoked_at': revokedAt,
      if (autoSyncEnabled != null) 'auto_sync_enabled': autoSyncEnabled,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrustedDeviceRecordsCompanion copyWith({
    Value<String>? deviceId,
    Value<String>? displayName,
    Value<String>? platform,
    Value<String>? publicKey,
    Value<String>? pairedAt,
    Value<String?>? lastSeenAt,
    Value<String?>? lastSyncAt,
    Value<String?>? revokedAt,
    Value<bool>? autoSyncEnabled,
    Value<int>? rowid,
  }) {
    return TrustedDeviceRecordsCompanion(
      deviceId: deviceId ?? this.deviceId,
      displayName: displayName ?? this.displayName,
      platform: platform ?? this.platform,
      publicKey: publicKey ?? this.publicKey,
      pairedAt: pairedAt ?? this.pairedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      revokedAt: revokedAt ?? this.revokedAt,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (platform.present) {
      map['platform'] = Variable<String>(platform.value);
    }
    if (publicKey.present) {
      map['public_key'] = Variable<String>(publicKey.value);
    }
    if (pairedAt.present) {
      map['paired_at'] = Variable<String>(pairedAt.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<String>(lastSeenAt.value);
    }
    if (lastSyncAt.present) {
      map['last_sync_at'] = Variable<String>(lastSyncAt.value);
    }
    if (revokedAt.present) {
      map['revoked_at'] = Variable<String>(revokedAt.value);
    }
    if (autoSyncEnabled.present) {
      map['auto_sync_enabled'] = Variable<bool>(autoSyncEnabled.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrustedDeviceRecordsCompanion(')
          ..write('deviceId: $deviceId, ')
          ..write('displayName: $displayName, ')
          ..write('platform: $platform, ')
          ..write('publicKey: $publicKey, ')
          ..write('pairedAt: $pairedAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('revokedAt: $revokedAt, ')
          ..write('autoSyncEnabled: $autoSyncEnabled, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChangeRecordRecordsTable extends ChangeRecordRecords
    with TableInfo<$ChangeRecordRecordsTable, ChangeRecordRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChangeRecordRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localSequenceMeta = const VerificationMeta(
    'localSequence',
  );
  @override
  late final GeneratedColumn<int> localSequence = GeneratedColumn<int>(
    'local_sequence',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _changeIdMeta = const VerificationMeta(
    'changeId',
  );
  @override
  late final GeneratedColumn<String> changeId = GeneratedColumn<String>(
    'change_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
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
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originDeviceIdMeta = const VerificationMeta(
    'originDeviceId',
  );
  @override
  late final GeneratedColumn<String> originDeviceId = GeneratedColumn<String>(
    'origin_device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _changedAtMeta = const VerificationMeta(
    'changedAt',
  );
  @override
  late final GeneratedColumn<String> changedAt = GeneratedColumn<String>(
    'changed_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _appliedAtMeta = const VerificationMeta(
    'appliedAt',
  );
  @override
  late final GeneratedColumn<String> appliedAt = GeneratedColumn<String>(
    'applied_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    localSequence,
    changeId,
    entityType,
    entityId,
    operation,
    revision,
    originDeviceId,
    changedAt,
    payloadJson,
    appliedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'change_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChangeRecordRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_sequence')) {
      context.handle(
        _localSequenceMeta,
        localSequence.isAcceptableOrUnknown(
          data['local_sequence']!,
          _localSequenceMeta,
        ),
      );
    }
    if (data.containsKey('change_id')) {
      context.handle(
        _changeIdMeta,
        changeId.isAcceptableOrUnknown(data['change_id']!, _changeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_changeIdMeta);
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
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('origin_device_id')) {
      context.handle(
        _originDeviceIdMeta,
        originDeviceId.isAcceptableOrUnknown(
          data['origin_device_id']!,
          _originDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originDeviceIdMeta);
    }
    if (data.containsKey('changed_at')) {
      context.handle(
        _changedAtMeta,
        changedAt.isAcceptableOrUnknown(data['changed_at']!, _changedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_changedAtMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('applied_at')) {
      context.handle(
        _appliedAtMeta,
        appliedAt.isAcceptableOrUnknown(data['applied_at']!, _appliedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localSequence};
  @override
  ChangeRecordRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChangeRecordRecord(
      localSequence:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}local_sequence'],
          )!,
      changeId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}change_id'],
          )!,
      entityType:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}entity_type'],
          )!,
      entityId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}entity_id'],
          )!,
      operation:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}operation'],
          )!,
      revision:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}revision'],
          )!,
      originDeviceId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}origin_device_id'],
          )!,
      changedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}changed_at'],
          )!,
      payloadJson:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}payload_json'],
          )!,
      appliedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}applied_at'],
      ),
    );
  }

  @override
  $ChangeRecordRecordsTable createAlias(String alias) {
    return $ChangeRecordRecordsTable(attachedDatabase, alias);
  }
}

class ChangeRecordRecord extends DataClass
    implements Insertable<ChangeRecordRecord> {
  final int localSequence;
  final String changeId;
  final String entityType;
  final String entityId;
  final String operation;
  final int revision;
  final String originDeviceId;
  final String changedAt;
  final String payloadJson;
  final String? appliedAt;
  const ChangeRecordRecord({
    required this.localSequence,
    required this.changeId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.revision,
    required this.originDeviceId,
    required this.changedAt,
    required this.payloadJson,
    this.appliedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_sequence'] = Variable<int>(localSequence);
    map['change_id'] = Variable<String>(changeId);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['operation'] = Variable<String>(operation);
    map['revision'] = Variable<int>(revision);
    map['origin_device_id'] = Variable<String>(originDeviceId);
    map['changed_at'] = Variable<String>(changedAt);
    map['payload_json'] = Variable<String>(payloadJson);
    if (!nullToAbsent || appliedAt != null) {
      map['applied_at'] = Variable<String>(appliedAt);
    }
    return map;
  }

  ChangeRecordRecordsCompanion toCompanion(bool nullToAbsent) {
    return ChangeRecordRecordsCompanion(
      localSequence: Value(localSequence),
      changeId: Value(changeId),
      entityType: Value(entityType),
      entityId: Value(entityId),
      operation: Value(operation),
      revision: Value(revision),
      originDeviceId: Value(originDeviceId),
      changedAt: Value(changedAt),
      payloadJson: Value(payloadJson),
      appliedAt:
          appliedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(appliedAt),
    );
  }

  factory ChangeRecordRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChangeRecordRecord(
      localSequence: serializer.fromJson<int>(json['localSequence']),
      changeId: serializer.fromJson<String>(json['changeId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      operation: serializer.fromJson<String>(json['operation']),
      revision: serializer.fromJson<int>(json['revision']),
      originDeviceId: serializer.fromJson<String>(json['originDeviceId']),
      changedAt: serializer.fromJson<String>(json['changedAt']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      appliedAt: serializer.fromJson<String?>(json['appliedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localSequence': serializer.toJson<int>(localSequence),
      'changeId': serializer.toJson<String>(changeId),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'operation': serializer.toJson<String>(operation),
      'revision': serializer.toJson<int>(revision),
      'originDeviceId': serializer.toJson<String>(originDeviceId),
      'changedAt': serializer.toJson<String>(changedAt),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'appliedAt': serializer.toJson<String?>(appliedAt),
    };
  }

  ChangeRecordRecord copyWith({
    int? localSequence,
    String? changeId,
    String? entityType,
    String? entityId,
    String? operation,
    int? revision,
    String? originDeviceId,
    String? changedAt,
    String? payloadJson,
    Value<String?> appliedAt = const Value.absent(),
  }) => ChangeRecordRecord(
    localSequence: localSequence ?? this.localSequence,
    changeId: changeId ?? this.changeId,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    operation: operation ?? this.operation,
    revision: revision ?? this.revision,
    originDeviceId: originDeviceId ?? this.originDeviceId,
    changedAt: changedAt ?? this.changedAt,
    payloadJson: payloadJson ?? this.payloadJson,
    appliedAt: appliedAt.present ? appliedAt.value : this.appliedAt,
  );
  ChangeRecordRecord copyWithCompanion(ChangeRecordRecordsCompanion data) {
    return ChangeRecordRecord(
      localSequence:
          data.localSequence.present
              ? data.localSequence.value
              : this.localSequence,
      changeId: data.changeId.present ? data.changeId.value : this.changeId,
      entityType:
          data.entityType.present ? data.entityType.value : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      operation: data.operation.present ? data.operation.value : this.operation,
      revision: data.revision.present ? data.revision.value : this.revision,
      originDeviceId:
          data.originDeviceId.present
              ? data.originDeviceId.value
              : this.originDeviceId,
      changedAt: data.changedAt.present ? data.changedAt.value : this.changedAt,
      payloadJson:
          data.payloadJson.present ? data.payloadJson.value : this.payloadJson,
      appliedAt: data.appliedAt.present ? data.appliedAt.value : this.appliedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChangeRecordRecord(')
          ..write('localSequence: $localSequence, ')
          ..write('changeId: $changeId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('revision: $revision, ')
          ..write('originDeviceId: $originDeviceId, ')
          ..write('changedAt: $changedAt, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('appliedAt: $appliedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    localSequence,
    changeId,
    entityType,
    entityId,
    operation,
    revision,
    originDeviceId,
    changedAt,
    payloadJson,
    appliedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChangeRecordRecord &&
          other.localSequence == this.localSequence &&
          other.changeId == this.changeId &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.operation == this.operation &&
          other.revision == this.revision &&
          other.originDeviceId == this.originDeviceId &&
          other.changedAt == this.changedAt &&
          other.payloadJson == this.payloadJson &&
          other.appliedAt == this.appliedAt);
}

class ChangeRecordRecordsCompanion extends UpdateCompanion<ChangeRecordRecord> {
  final Value<int> localSequence;
  final Value<String> changeId;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> operation;
  final Value<int> revision;
  final Value<String> originDeviceId;
  final Value<String> changedAt;
  final Value<String> payloadJson;
  final Value<String?> appliedAt;
  const ChangeRecordRecordsCompanion({
    this.localSequence = const Value.absent(),
    this.changeId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.operation = const Value.absent(),
    this.revision = const Value.absent(),
    this.originDeviceId = const Value.absent(),
    this.changedAt = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.appliedAt = const Value.absent(),
  });
  ChangeRecordRecordsCompanion.insert({
    this.localSequence = const Value.absent(),
    required String changeId,
    required String entityType,
    required String entityId,
    required String operation,
    required int revision,
    required String originDeviceId,
    required String changedAt,
    required String payloadJson,
    this.appliedAt = const Value.absent(),
  }) : changeId = Value(changeId),
       entityType = Value(entityType),
       entityId = Value(entityId),
       operation = Value(operation),
       revision = Value(revision),
       originDeviceId = Value(originDeviceId),
       changedAt = Value(changedAt),
       payloadJson = Value(payloadJson);
  static Insertable<ChangeRecordRecord> custom({
    Expression<int>? localSequence,
    Expression<String>? changeId,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? operation,
    Expression<int>? revision,
    Expression<String>? originDeviceId,
    Expression<String>? changedAt,
    Expression<String>? payloadJson,
    Expression<String>? appliedAt,
  }) {
    return RawValuesInsertable({
      if (localSequence != null) 'local_sequence': localSequence,
      if (changeId != null) 'change_id': changeId,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (operation != null) 'operation': operation,
      if (revision != null) 'revision': revision,
      if (originDeviceId != null) 'origin_device_id': originDeviceId,
      if (changedAt != null) 'changed_at': changedAt,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (appliedAt != null) 'applied_at': appliedAt,
    });
  }

  ChangeRecordRecordsCompanion copyWith({
    Value<int>? localSequence,
    Value<String>? changeId,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? operation,
    Value<int>? revision,
    Value<String>? originDeviceId,
    Value<String>? changedAt,
    Value<String>? payloadJson,
    Value<String?>? appliedAt,
  }) {
    return ChangeRecordRecordsCompanion(
      localSequence: localSequence ?? this.localSequence,
      changeId: changeId ?? this.changeId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      revision: revision ?? this.revision,
      originDeviceId: originDeviceId ?? this.originDeviceId,
      changedAt: changedAt ?? this.changedAt,
      payloadJson: payloadJson ?? this.payloadJson,
      appliedAt: appliedAt ?? this.appliedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localSequence.present) {
      map['local_sequence'] = Variable<int>(localSequence.value);
    }
    if (changeId.present) {
      map['change_id'] = Variable<String>(changeId.value);
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
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (originDeviceId.present) {
      map['origin_device_id'] = Variable<String>(originDeviceId.value);
    }
    if (changedAt.present) {
      map['changed_at'] = Variable<String>(changedAt.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (appliedAt.present) {
      map['applied_at'] = Variable<String>(appliedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChangeRecordRecordsCompanion(')
          ..write('localSequence: $localSequence, ')
          ..write('changeId: $changeId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('revision: $revision, ')
          ..write('originDeviceId: $originDeviceId, ')
          ..write('changedAt: $changedAt, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('appliedAt: $appliedAt')
          ..write(')'))
        .toString();
  }
}

class $SyncCursorRecordsTable extends SyncCursorRecords
    with TableInfo<$SyncCursorRecordsTable, SyncCursorRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncCursorRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _peerDeviceIdMeta = const VerificationMeta(
    'peerDeviceId',
  );
  @override
  late final GeneratedColumn<String> peerDeviceId = GeneratedColumn<String>(
    'peer_device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSentSequenceMeta = const VerificationMeta(
    'lastSentSequence',
  );
  @override
  late final GeneratedColumn<int> lastSentSequence = GeneratedColumn<int>(
    'last_sent_sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastReceivedChangeIdMeta =
      const VerificationMeta('lastReceivedChangeId');
  @override
  late final GeneratedColumn<String> lastReceivedChangeId =
      GeneratedColumn<String>(
        'last_received_change_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastSuccessAtMeta = const VerificationMeta(
    'lastSuccessAt',
  );
  @override
  late final GeneratedColumn<String> lastSuccessAt = GeneratedColumn<String>(
    'last_success_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    peerDeviceId,
    lastSentSequence,
    lastReceivedChangeId,
    lastSuccessAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_cursors';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncCursorRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('peer_device_id')) {
      context.handle(
        _peerDeviceIdMeta,
        peerDeviceId.isAcceptableOrUnknown(
          data['peer_device_id']!,
          _peerDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_peerDeviceIdMeta);
    }
    if (data.containsKey('last_sent_sequence')) {
      context.handle(
        _lastSentSequenceMeta,
        lastSentSequence.isAcceptableOrUnknown(
          data['last_sent_sequence']!,
          _lastSentSequenceMeta,
        ),
      );
    }
    if (data.containsKey('last_received_change_id')) {
      context.handle(
        _lastReceivedChangeIdMeta,
        lastReceivedChangeId.isAcceptableOrUnknown(
          data['last_received_change_id']!,
          _lastReceivedChangeIdMeta,
        ),
      );
    }
    if (data.containsKey('last_success_at')) {
      context.handle(
        _lastSuccessAtMeta,
        lastSuccessAt.isAcceptableOrUnknown(
          data['last_success_at']!,
          _lastSuccessAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {peerDeviceId};
  @override
  SyncCursorRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncCursorRecord(
      peerDeviceId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}peer_device_id'],
          )!,
      lastSentSequence:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}last_sent_sequence'],
          )!,
      lastReceivedChangeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_received_change_id'],
      ),
      lastSuccessAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_success_at'],
      ),
    );
  }

  @override
  $SyncCursorRecordsTable createAlias(String alias) {
    return $SyncCursorRecordsTable(attachedDatabase, alias);
  }
}

class SyncCursorRecord extends DataClass
    implements Insertable<SyncCursorRecord> {
  final String peerDeviceId;
  final int lastSentSequence;
  final String? lastReceivedChangeId;
  final String? lastSuccessAt;
  const SyncCursorRecord({
    required this.peerDeviceId,
    required this.lastSentSequence,
    this.lastReceivedChangeId,
    this.lastSuccessAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['peer_device_id'] = Variable<String>(peerDeviceId);
    map['last_sent_sequence'] = Variable<int>(lastSentSequence);
    if (!nullToAbsent || lastReceivedChangeId != null) {
      map['last_received_change_id'] = Variable<String>(lastReceivedChangeId);
    }
    if (!nullToAbsent || lastSuccessAt != null) {
      map['last_success_at'] = Variable<String>(lastSuccessAt);
    }
    return map;
  }

  SyncCursorRecordsCompanion toCompanion(bool nullToAbsent) {
    return SyncCursorRecordsCompanion(
      peerDeviceId: Value(peerDeviceId),
      lastSentSequence: Value(lastSentSequence),
      lastReceivedChangeId:
          lastReceivedChangeId == null && nullToAbsent
              ? const Value.absent()
              : Value(lastReceivedChangeId),
      lastSuccessAt:
          lastSuccessAt == null && nullToAbsent
              ? const Value.absent()
              : Value(lastSuccessAt),
    );
  }

  factory SyncCursorRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncCursorRecord(
      peerDeviceId: serializer.fromJson<String>(json['peerDeviceId']),
      lastSentSequence: serializer.fromJson<int>(json['lastSentSequence']),
      lastReceivedChangeId: serializer.fromJson<String?>(
        json['lastReceivedChangeId'],
      ),
      lastSuccessAt: serializer.fromJson<String?>(json['lastSuccessAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'peerDeviceId': serializer.toJson<String>(peerDeviceId),
      'lastSentSequence': serializer.toJson<int>(lastSentSequence),
      'lastReceivedChangeId': serializer.toJson<String?>(lastReceivedChangeId),
      'lastSuccessAt': serializer.toJson<String?>(lastSuccessAt),
    };
  }

  SyncCursorRecord copyWith({
    String? peerDeviceId,
    int? lastSentSequence,
    Value<String?> lastReceivedChangeId = const Value.absent(),
    Value<String?> lastSuccessAt = const Value.absent(),
  }) => SyncCursorRecord(
    peerDeviceId: peerDeviceId ?? this.peerDeviceId,
    lastSentSequence: lastSentSequence ?? this.lastSentSequence,
    lastReceivedChangeId:
        lastReceivedChangeId.present
            ? lastReceivedChangeId.value
            : this.lastReceivedChangeId,
    lastSuccessAt:
        lastSuccessAt.present ? lastSuccessAt.value : this.lastSuccessAt,
  );
  SyncCursorRecord copyWithCompanion(SyncCursorRecordsCompanion data) {
    return SyncCursorRecord(
      peerDeviceId:
          data.peerDeviceId.present
              ? data.peerDeviceId.value
              : this.peerDeviceId,
      lastSentSequence:
          data.lastSentSequence.present
              ? data.lastSentSequence.value
              : this.lastSentSequence,
      lastReceivedChangeId:
          data.lastReceivedChangeId.present
              ? data.lastReceivedChangeId.value
              : this.lastReceivedChangeId,
      lastSuccessAt:
          data.lastSuccessAt.present
              ? data.lastSuccessAt.value
              : this.lastSuccessAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorRecord(')
          ..write('peerDeviceId: $peerDeviceId, ')
          ..write('lastSentSequence: $lastSentSequence, ')
          ..write('lastReceivedChangeId: $lastReceivedChangeId, ')
          ..write('lastSuccessAt: $lastSuccessAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    peerDeviceId,
    lastSentSequence,
    lastReceivedChangeId,
    lastSuccessAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncCursorRecord &&
          other.peerDeviceId == this.peerDeviceId &&
          other.lastSentSequence == this.lastSentSequence &&
          other.lastReceivedChangeId == this.lastReceivedChangeId &&
          other.lastSuccessAt == this.lastSuccessAt);
}

class SyncCursorRecordsCompanion extends UpdateCompanion<SyncCursorRecord> {
  final Value<String> peerDeviceId;
  final Value<int> lastSentSequence;
  final Value<String?> lastReceivedChangeId;
  final Value<String?> lastSuccessAt;
  final Value<int> rowid;
  const SyncCursorRecordsCompanion({
    this.peerDeviceId = const Value.absent(),
    this.lastSentSequence = const Value.absent(),
    this.lastReceivedChangeId = const Value.absent(),
    this.lastSuccessAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncCursorRecordsCompanion.insert({
    required String peerDeviceId,
    this.lastSentSequence = const Value.absent(),
    this.lastReceivedChangeId = const Value.absent(),
    this.lastSuccessAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : peerDeviceId = Value(peerDeviceId);
  static Insertable<SyncCursorRecord> custom({
    Expression<String>? peerDeviceId,
    Expression<int>? lastSentSequence,
    Expression<String>? lastReceivedChangeId,
    Expression<String>? lastSuccessAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (peerDeviceId != null) 'peer_device_id': peerDeviceId,
      if (lastSentSequence != null) 'last_sent_sequence': lastSentSequence,
      if (lastReceivedChangeId != null)
        'last_received_change_id': lastReceivedChangeId,
      if (lastSuccessAt != null) 'last_success_at': lastSuccessAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncCursorRecordsCompanion copyWith({
    Value<String>? peerDeviceId,
    Value<int>? lastSentSequence,
    Value<String?>? lastReceivedChangeId,
    Value<String?>? lastSuccessAt,
    Value<int>? rowid,
  }) {
    return SyncCursorRecordsCompanion(
      peerDeviceId: peerDeviceId ?? this.peerDeviceId,
      lastSentSequence: lastSentSequence ?? this.lastSentSequence,
      lastReceivedChangeId: lastReceivedChangeId ?? this.lastReceivedChangeId,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (peerDeviceId.present) {
      map['peer_device_id'] = Variable<String>(peerDeviceId.value);
    }
    if (lastSentSequence.present) {
      map['last_sent_sequence'] = Variable<int>(lastSentSequence.value);
    }
    if (lastReceivedChangeId.present) {
      map['last_received_change_id'] = Variable<String>(
        lastReceivedChangeId.value,
      );
    }
    if (lastSuccessAt.present) {
      map['last_success_at'] = Variable<String>(lastSuccessAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorRecordsCompanion(')
          ..write('peerDeviceId: $peerDeviceId, ')
          ..write('lastSentSequence: $lastSentSequence, ')
          ..write('lastReceivedChangeId: $lastReceivedChangeId, ')
          ..write('lastSuccessAt: $lastSuccessAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ChronicleDatabase extends GeneratedDatabase {
  _$ChronicleDatabase(QueryExecutor e) : super(e);
  $ChronicleDatabaseManager get managers => $ChronicleDatabaseManager(this);
  late final $AppStateRecordsTable appStateRecords = $AppStateRecordsTable(
    this,
  );
  late final $ProjectRecordsTable projectRecords = $ProjectRecordsTable(this);
  late final $NoteRecordsTable noteRecords = $NoteRecordsTable(this);
  late final $NoteLinkRecordsTable noteLinkRecords = $NoteLinkRecordsTable(
    this,
  );
  late final $NoteVersionRecordsTable noteVersionRecords =
      $NoteVersionRecordsTable(this);
  late final $TaskRecordsTable taskRecords = $TaskRecordsTable(this);
  late final $TimeEntryRecordsTable timeEntryRecords = $TimeEntryRecordsTable(
    this,
  );
  late final $DeviceIdentityRecordsTable deviceIdentityRecords =
      $DeviceIdentityRecordsTable(this);
  late final $TrustedDeviceRecordsTable trustedDeviceRecords =
      $TrustedDeviceRecordsTable(this);
  late final $ChangeRecordRecordsTable changeRecordRecords =
      $ChangeRecordRecordsTable(this);
  late final $SyncCursorRecordsTable syncCursorRecords =
      $SyncCursorRecordsTable(this);
  late final Index idxProjectsArchived = Index(
    'idx_projects_archived',
    'CREATE INDEX idx_projects_archived ON projects (archived, updated_at)',
  );
  late final Index idxNotesProject = Index(
    'idx_notes_project',
    'CREATE INDEX idx_notes_project ON notes (project_id, updated_at)',
  );
  late final Index idxNoteLinksTarget = Index(
    'idx_note_links_target',
    'CREATE INDEX idx_note_links_target ON note_links (target_note_id, target_title)',
  );
  late final Index idxNoteLinksSource = Index(
    'idx_note_links_source',
    'CREATE INDEX idx_note_links_source ON note_links (source_note_id)',
  );
  late final Index idxNoteVersionsNote = Index(
    'idx_note_versions_note',
    'CREATE INDEX idx_note_versions_note ON note_versions (note_id, created_at)',
  );
  late final Index idxTasksStatusDue = Index(
    'idx_tasks_status_due',
    'CREATE INDEX idx_tasks_status_due ON tasks (status, due_at)',
  );
  late final Index idxTasksProject = Index(
    'idx_tasks_project',
    'CREATE INDEX idx_tasks_project ON tasks (project_id, status)',
  );
  late final Index idxTimeEntriesStarted = Index(
    'idx_time_entries_started',
    'CREATE INDEX idx_time_entries_started ON time_entries (started_at)',
  );
  late final Index idxTimeEntriesProject = Index(
    'idx_time_entries_project',
    'CREATE INDEX idx_time_entries_project ON time_entries (project_id, started_at)',
  );
  late final Index idxTrustedDevicesActive = Index(
    'idx_trusted_devices_active',
    'CREATE INDEX idx_trusted_devices_active ON trusted_devices (revoked_at, last_sync_at)',
  );
  late final Index idxChangeRecordsEntity = Index(
    'idx_change_records_entity',
    'CREATE INDEX idx_change_records_entity ON change_records (entity_type, entity_id, revision)',
  );
  late final Index idxChangeRecordsOrigin = Index(
    'idx_change_records_origin',
    'CREATE INDEX idx_change_records_origin ON change_records (origin_device_id, local_sequence)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    appStateRecords,
    projectRecords,
    noteRecords,
    noteLinkRecords,
    noteVersionRecords,
    taskRecords,
    timeEntryRecords,
    deviceIdentityRecords,
    trustedDeviceRecords,
    changeRecordRecords,
    syncCursorRecords,
    idxProjectsArchived,
    idxNotesProject,
    idxNoteLinksTarget,
    idxNoteLinksSource,
    idxNoteVersionsNote,
    idxTasksStatusDue,
    idxTasksProject,
    idxTimeEntriesStarted,
    idxTimeEntriesProject,
    idxTrustedDevicesActive,
    idxChangeRecordsEntity,
    idxChangeRecordsOrigin,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'notes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('note_links', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'notes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('note_links', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'notes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('note_versions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'notes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('tasks', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tasks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('time_entries', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'notes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('time_entries', kind: UpdateKind.update)],
    ),
  ]);
}

typedef $$AppStateRecordsTableCreateCompanionBuilder =
    AppStateRecordsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppStateRecordsTableUpdateCompanionBuilder =
    AppStateRecordsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppStateRecordsTableFilterComposer
    extends Composer<_$ChronicleDatabase, $AppStateRecordsTable> {
  $$AppStateRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppStateRecordsTableOrderingComposer
    extends Composer<_$ChronicleDatabase, $AppStateRecordsTable> {
  $$AppStateRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppStateRecordsTableAnnotationComposer
    extends Composer<_$ChronicleDatabase, $AppStateRecordsTable> {
  $$AppStateRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppStateRecordsTableTableManager
    extends
        RootTableManager<
          _$ChronicleDatabase,
          $AppStateRecordsTable,
          AppStateRecord,
          $$AppStateRecordsTableFilterComposer,
          $$AppStateRecordsTableOrderingComposer,
          $$AppStateRecordsTableAnnotationComposer,
          $$AppStateRecordsTableCreateCompanionBuilder,
          $$AppStateRecordsTableUpdateCompanionBuilder,
          (
            AppStateRecord,
            BaseReferences<
              _$ChronicleDatabase,
              $AppStateRecordsTable,
              AppStateRecord
            >,
          ),
          AppStateRecord,
          PrefetchHooks Function()
        > {
  $$AppStateRecordsTableTableManager(
    _$ChronicleDatabase db,
    $AppStateRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () =>
                  $$AppStateRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$AppStateRecordsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$AppStateRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppStateRecordsCompanion(
                key: key,
                value: value,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppStateRecordsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppStateRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$ChronicleDatabase,
      $AppStateRecordsTable,
      AppStateRecord,
      $$AppStateRecordsTableFilterComposer,
      $$AppStateRecordsTableOrderingComposer,
      $$AppStateRecordsTableAnnotationComposer,
      $$AppStateRecordsTableCreateCompanionBuilder,
      $$AppStateRecordsTableUpdateCompanionBuilder,
      (
        AppStateRecord,
        BaseReferences<
          _$ChronicleDatabase,
          $AppStateRecordsTable,
          AppStateRecord
        >,
      ),
      AppStateRecord,
      PrefetchHooks Function()
    >;
typedef $$ProjectRecordsTableCreateCompanionBuilder =
    ProjectRecordsCompanion Function({
      required String id,
      required String title,
      Value<String> emoji,
      Value<String> description,
      Value<int> colorValue,
      Value<String?> dueAt,
      Value<int?> budgetMinutes,
      Value<bool> archived,
      required String createdAt,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$ProjectRecordsTableUpdateCompanionBuilder =
    ProjectRecordsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> emoji,
      Value<String> description,
      Value<int> colorValue,
      Value<String?> dueAt,
      Value<int?> budgetMinutes,
      Value<bool> archived,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<int> rowid,
    });

final class $$ProjectRecordsTableReferences
    extends
        BaseReferences<
          _$ChronicleDatabase,
          $ProjectRecordsTable,
          ProjectRecord
        > {
  $$ProjectRecordsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$NoteRecordsTable, List<NoteRecord>>
  _noteRecordsRefsTable(_$ChronicleDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.noteRecords,
        aliasName: 'projects__id__notes__project_id',
      );

  $$NoteRecordsTableProcessedTableManager get noteRecordsRefs {
    final manager = $$NoteRecordsTableTableManager(
      $_db,
      $_db.noteRecords,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_noteRecordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TaskRecordsTable, List<TaskRecord>>
  _taskRecordsRefsTable(_$ChronicleDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.taskRecords,
        aliasName: 'projects__id__tasks__project_id',
      );

  $$TaskRecordsTableProcessedTableManager get taskRecordsRefs {
    final manager = $$TaskRecordsTableTableManager(
      $_db,
      $_db.taskRecords,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_taskRecordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TimeEntryRecordsTable, List<TimeEntryRecord>>
  _timeEntryRecordsRefsTable(_$ChronicleDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.timeEntryRecords,
        aliasName: 'projects__id__time_entries__project_id',
      );

  $$TimeEntryRecordsTableProcessedTableManager get timeEntryRecordsRefs {
    final manager = $$TimeEntryRecordsTableTableManager(
      $_db,
      $_db.timeEntryRecords,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _timeEntryRecordsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProjectRecordsTableFilterComposer
    extends Composer<_$ChronicleDatabase, $ProjectRecordsTable> {
  $$ProjectRecordsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get budgetMinutes => $composableBuilder(
    column: $table.budgetMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> noteRecordsRefs(
    Expression<bool> Function($$NoteRecordsTableFilterComposer f) f,
  ) {
    final $$NoteRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteRecords,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteRecordsTableFilterComposer(
            $db: $db,
            $table: $db.noteRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> taskRecordsRefs(
    Expression<bool> Function($$TaskRecordsTableFilterComposer f) f,
  ) {
    final $$TaskRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskRecords,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskRecordsTableFilterComposer(
            $db: $db,
            $table: $db.taskRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> timeEntryRecordsRefs(
    Expression<bool> Function($$TimeEntryRecordsTableFilterComposer f) f,
  ) {
    final $$TimeEntryRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.timeEntryRecords,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TimeEntryRecordsTableFilterComposer(
            $db: $db,
            $table: $db.timeEntryRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProjectRecordsTableOrderingComposer
    extends Composer<_$ChronicleDatabase, $ProjectRecordsTable> {
  $$ProjectRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get budgetMinutes => $composableBuilder(
    column: $table.budgetMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProjectRecordsTableAnnotationComposer
    extends Composer<_$ChronicleDatabase, $ProjectRecordsTable> {
  $$ProjectRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get emoji =>
      $composableBuilder(column: $table.emoji, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<int> get budgetMinutes => $composableBuilder(
    column: $table.budgetMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> noteRecordsRefs<T extends Object>(
    Expression<T> Function($$NoteRecordsTableAnnotationComposer a) f,
  ) {
    final $$NoteRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteRecords,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.noteRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> taskRecordsRefs<T extends Object>(
    Expression<T> Function($$TaskRecordsTableAnnotationComposer a) f,
  ) {
    final $$TaskRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskRecords,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.taskRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> timeEntryRecordsRefs<T extends Object>(
    Expression<T> Function($$TimeEntryRecordsTableAnnotationComposer a) f,
  ) {
    final $$TimeEntryRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.timeEntryRecords,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TimeEntryRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.timeEntryRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProjectRecordsTableTableManager
    extends
        RootTableManager<
          _$ChronicleDatabase,
          $ProjectRecordsTable,
          ProjectRecord,
          $$ProjectRecordsTableFilterComposer,
          $$ProjectRecordsTableOrderingComposer,
          $$ProjectRecordsTableAnnotationComposer,
          $$ProjectRecordsTableCreateCompanionBuilder,
          $$ProjectRecordsTableUpdateCompanionBuilder,
          (ProjectRecord, $$ProjectRecordsTableReferences),
          ProjectRecord,
          PrefetchHooks Function({
            bool noteRecordsRefs,
            bool taskRecordsRefs,
            bool timeEntryRecordsRefs,
          })
        > {
  $$ProjectRecordsTableTableManager(
    _$ChronicleDatabase db,
    $ProjectRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$ProjectRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$ProjectRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$ProjectRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> emoji = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<String?> dueAt = const Value.absent(),
                Value<int?> budgetMinutes = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectRecordsCompanion(
                id: id,
                title: title,
                emoji: emoji,
                description: description,
                colorValue: colorValue,
                dueAt: dueAt,
                budgetMinutes: budgetMinutes,
                archived: archived,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String> emoji = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<String?> dueAt = const Value.absent(),
                Value<int?> budgetMinutes = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ProjectRecordsCompanion.insert(
                id: id,
                title: title,
                emoji: emoji,
                description: description,
                colorValue: colorValue,
                dueAt: dueAt,
                budgetMinutes: budgetMinutes,
                archived: archived,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$ProjectRecordsTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({
            noteRecordsRefs = false,
            taskRecordsRefs = false,
            timeEntryRecordsRefs = false,
          }) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (noteRecordsRefs) db.noteRecords,
                if (taskRecordsRefs) db.taskRecords,
                if (timeEntryRecordsRefs) db.timeEntryRecords,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (noteRecordsRefs)
                    await $_getPrefetchedData<
                      ProjectRecord,
                      $ProjectRecordsTable,
                      NoteRecord
                    >(
                      currentTable: table,
                      referencedTable: $$ProjectRecordsTableReferences
                          ._noteRecordsRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$ProjectRecordsTableReferences(
                                db,
                                table,
                                p0,
                              ).noteRecordsRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.projectId == item.id,
                          ),
                      typedResults: items,
                    ),
                  if (taskRecordsRefs)
                    await $_getPrefetchedData<
                      ProjectRecord,
                      $ProjectRecordsTable,
                      TaskRecord
                    >(
                      currentTable: table,
                      referencedTable: $$ProjectRecordsTableReferences
                          ._taskRecordsRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$ProjectRecordsTableReferences(
                                db,
                                table,
                                p0,
                              ).taskRecordsRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.projectId == item.id,
                          ),
                      typedResults: items,
                    ),
                  if (timeEntryRecordsRefs)
                    await $_getPrefetchedData<
                      ProjectRecord,
                      $ProjectRecordsTable,
                      TimeEntryRecord
                    >(
                      currentTable: table,
                      referencedTable: $$ProjectRecordsTableReferences
                          ._timeEntryRecordsRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$ProjectRecordsTableReferences(
                                db,
                                table,
                                p0,
                              ).timeEntryRecordsRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.projectId == item.id,
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

typedef $$ProjectRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$ChronicleDatabase,
      $ProjectRecordsTable,
      ProjectRecord,
      $$ProjectRecordsTableFilterComposer,
      $$ProjectRecordsTableOrderingComposer,
      $$ProjectRecordsTableAnnotationComposer,
      $$ProjectRecordsTableCreateCompanionBuilder,
      $$ProjectRecordsTableUpdateCompanionBuilder,
      (ProjectRecord, $$ProjectRecordsTableReferences),
      ProjectRecord,
      PrefetchHooks Function({
        bool noteRecordsRefs,
        bool taskRecordsRefs,
        bool timeEntryRecordsRefs,
      })
    >;
typedef $$NoteRecordsTableCreateCompanionBuilder =
    NoteRecordsCompanion Function({
      required String id,
      required String projectId,
      required String title,
      Value<String> body,
      Value<String> tagsJson,
      Value<String> status,
      Value<String> folderPath,
      Value<String> noteType,
      Value<String> propertiesJson,
      Value<bool> pinned,
      Value<int> revision,
      required String createdAt,
      required String updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $$NoteRecordsTableUpdateCompanionBuilder =
    NoteRecordsCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<String> title,
      Value<String> body,
      Value<String> tagsJson,
      Value<String> status,
      Value<String> folderPath,
      Value<String> noteType,
      Value<String> propertiesJson,
      Value<bool> pinned,
      Value<int> revision,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });

final class $$NoteRecordsTableReferences
    extends BaseReferences<_$ChronicleDatabase, $NoteRecordsTable, NoteRecord> {
  $$NoteRecordsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectRecordsTable _projectIdTable(_$ChronicleDatabase db) =>
      db.projectRecords.createAlias('notes__project_id__projects__id');

  $$ProjectRecordsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectRecordsTableTableManager(
      $_db,
      $_db.projectRecords,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$NoteLinkRecordsTable, List<NoteLinkRecord>>
  _sourceNoteLinksTable(_$ChronicleDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.noteLinkRecords,
        aliasName: 'notes__id__note_links__source_note_id',
      );

  $$NoteLinkRecordsTableProcessedTableManager get sourceNoteLinks {
    final manager = $$NoteLinkRecordsTableTableManager(
      $_db,
      $_db.noteLinkRecords,
    ).filter((f) => f.sourceNoteId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_sourceNoteLinksTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$NoteLinkRecordsTable, List<NoteLinkRecord>>
  _targetNoteLinksTable(_$ChronicleDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.noteLinkRecords,
        aliasName: 'notes__id__note_links__target_note_id',
      );

  $$NoteLinkRecordsTableProcessedTableManager get targetNoteLinks {
    final manager = $$NoteLinkRecordsTableTableManager(
      $_db,
      $_db.noteLinkRecords,
    ).filter((f) => f.targetNoteId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_targetNoteLinksTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$NoteVersionRecordsTable, List<NoteVersionRecord>>
  _noteVersionRecordsRefsTable(_$ChronicleDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.noteVersionRecords,
        aliasName: 'notes__id__note_versions__note_id',
      );

  $$NoteVersionRecordsTableProcessedTableManager get noteVersionRecordsRefs {
    final manager = $$NoteVersionRecordsTableTableManager(
      $_db,
      $_db.noteVersionRecords,
    ).filter((f) => f.noteId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _noteVersionRecordsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TaskRecordsTable, List<TaskRecord>>
  _taskRecordsRefsTable(_$ChronicleDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.taskRecords,
        aliasName: 'notes__id__tasks__note_id',
      );

  $$TaskRecordsTableProcessedTableManager get taskRecordsRefs {
    final manager = $$TaskRecordsTableTableManager(
      $_db,
      $_db.taskRecords,
    ).filter((f) => f.noteId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_taskRecordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TimeEntryRecordsTable, List<TimeEntryRecord>>
  _timeEntryRecordsRefsTable(_$ChronicleDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.timeEntryRecords,
        aliasName: 'notes__id__time_entries__note_id',
      );

  $$TimeEntryRecordsTableProcessedTableManager get timeEntryRecordsRefs {
    final manager = $$TimeEntryRecordsTableTableManager(
      $_db,
      $_db.timeEntryRecords,
    ).filter((f) => f.noteId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _timeEntryRecordsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$NoteRecordsTableFilterComposer
    extends Composer<_$ChronicleDatabase, $NoteRecordsTable> {
  $$NoteRecordsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderPath => $composableBuilder(
    column: $table.folderPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get noteType => $composableBuilder(
    column: $table.noteType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get propertiesJson => $composableBuilder(
    column: $table.propertiesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectRecordsTableFilterComposer get projectId {
    final $$ProjectRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projectRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectRecordsTableFilterComposer(
            $db: $db,
            $table: $db.projectRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> sourceNoteLinks(
    Expression<bool> Function($$NoteLinkRecordsTableFilterComposer f) f,
  ) {
    final $$NoteLinkRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteLinkRecords,
      getReferencedColumn: (t) => t.sourceNoteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteLinkRecordsTableFilterComposer(
            $db: $db,
            $table: $db.noteLinkRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> targetNoteLinks(
    Expression<bool> Function($$NoteLinkRecordsTableFilterComposer f) f,
  ) {
    final $$NoteLinkRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteLinkRecords,
      getReferencedColumn: (t) => t.targetNoteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteLinkRecordsTableFilterComposer(
            $db: $db,
            $table: $db.noteLinkRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> noteVersionRecordsRefs(
    Expression<bool> Function($$NoteVersionRecordsTableFilterComposer f) f,
  ) {
    final $$NoteVersionRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteVersionRecords,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteVersionRecordsTableFilterComposer(
            $db: $db,
            $table: $db.noteVersionRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> taskRecordsRefs(
    Expression<bool> Function($$TaskRecordsTableFilterComposer f) f,
  ) {
    final $$TaskRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskRecords,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskRecordsTableFilterComposer(
            $db: $db,
            $table: $db.taskRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> timeEntryRecordsRefs(
    Expression<bool> Function($$TimeEntryRecordsTableFilterComposer f) f,
  ) {
    final $$TimeEntryRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.timeEntryRecords,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TimeEntryRecordsTableFilterComposer(
            $db: $db,
            $table: $db.timeEntryRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NoteRecordsTableOrderingComposer
    extends Composer<_$ChronicleDatabase, $NoteRecordsTable> {
  $$NoteRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderPath => $composableBuilder(
    column: $table.folderPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get noteType => $composableBuilder(
    column: $table.noteType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get propertiesJson => $composableBuilder(
    column: $table.propertiesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectRecordsTableOrderingComposer get projectId {
    final $$ProjectRecordsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projectRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectRecordsTableOrderingComposer(
            $db: $db,
            $table: $db.projectRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteRecordsTableAnnotationComposer
    extends Composer<_$ChronicleDatabase, $NoteRecordsTable> {
  $$NoteRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get tagsJson =>
      $composableBuilder(column: $table.tagsJson, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get folderPath => $composableBuilder(
    column: $table.folderPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get noteType =>
      $composableBuilder(column: $table.noteType, builder: (column) => column);

  GeneratedColumn<String> get propertiesJson => $composableBuilder(
    column: $table.propertiesJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$ProjectRecordsTableAnnotationComposer get projectId {
    final $$ProjectRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projectRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.projectRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> sourceNoteLinks<T extends Object>(
    Expression<T> Function($$NoteLinkRecordsTableAnnotationComposer a) f,
  ) {
    final $$NoteLinkRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteLinkRecords,
      getReferencedColumn: (t) => t.sourceNoteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteLinkRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.noteLinkRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> targetNoteLinks<T extends Object>(
    Expression<T> Function($$NoteLinkRecordsTableAnnotationComposer a) f,
  ) {
    final $$NoteLinkRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteLinkRecords,
      getReferencedColumn: (t) => t.targetNoteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteLinkRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.noteLinkRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> noteVersionRecordsRefs<T extends Object>(
    Expression<T> Function($$NoteVersionRecordsTableAnnotationComposer a) f,
  ) {
    final $$NoteVersionRecordsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.noteVersionRecords,
          getReferencedColumn: (t) => t.noteId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$NoteVersionRecordsTableAnnotationComposer(
                $db: $db,
                $table: $db.noteVersionRecords,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> taskRecordsRefs<T extends Object>(
    Expression<T> Function($$TaskRecordsTableAnnotationComposer a) f,
  ) {
    final $$TaskRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskRecords,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.taskRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> timeEntryRecordsRefs<T extends Object>(
    Expression<T> Function($$TimeEntryRecordsTableAnnotationComposer a) f,
  ) {
    final $$TimeEntryRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.timeEntryRecords,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TimeEntryRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.timeEntryRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NoteRecordsTableTableManager
    extends
        RootTableManager<
          _$ChronicleDatabase,
          $NoteRecordsTable,
          NoteRecord,
          $$NoteRecordsTableFilterComposer,
          $$NoteRecordsTableOrderingComposer,
          $$NoteRecordsTableAnnotationComposer,
          $$NoteRecordsTableCreateCompanionBuilder,
          $$NoteRecordsTableUpdateCompanionBuilder,
          (NoteRecord, $$NoteRecordsTableReferences),
          NoteRecord,
          PrefetchHooks Function({
            bool projectId,
            bool sourceNoteLinks,
            bool targetNoteLinks,
            bool noteVersionRecordsRefs,
            bool taskRecordsRefs,
            bool timeEntryRecordsRefs,
          })
        > {
  $$NoteRecordsTableTableManager(
    _$ChronicleDatabase db,
    $NoteRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$NoteRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$NoteRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$NoteRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> folderPath = const Value.absent(),
                Value<String> noteType = const Value.absent(),
                Value<String> propertiesJson = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteRecordsCompanion(
                id: id,
                projectId: projectId,
                title: title,
                body: body,
                tagsJson: tagsJson,
                status: status,
                folderPath: folderPath,
                noteType: noteType,
                propertiesJson: propertiesJson,
                pinned: pinned,
                revision: revision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                required String title,
                Value<String> body = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> folderPath = const Value.absent(),
                Value<String> noteType = const Value.absent(),
                Value<String> propertiesJson = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<int> revision = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteRecordsCompanion.insert(
                id: id,
                projectId: projectId,
                title: title,
                body: body,
                tagsJson: tagsJson,
                status: status,
                folderPath: folderPath,
                noteType: noteType,
                propertiesJson: propertiesJson,
                pinned: pinned,
                revision: revision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$NoteRecordsTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({
            projectId = false,
            sourceNoteLinks = false,
            targetNoteLinks = false,
            noteVersionRecordsRefs = false,
            taskRecordsRefs = false,
            timeEntryRecordsRefs = false,
          }) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (sourceNoteLinks) db.noteLinkRecords,
                if (targetNoteLinks) db.noteLinkRecords,
                if (noteVersionRecordsRefs) db.noteVersionRecords,
                if (taskRecordsRefs) db.taskRecords,
                if (timeEntryRecordsRefs) db.timeEntryRecords,
              ],
              addJoins: <
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
                if (projectId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.projectId,
                            referencedTable: $$NoteRecordsTableReferences
                                ._projectIdTable(db),
                            referencedColumn:
                                $$NoteRecordsTableReferences
                                    ._projectIdTable(db)
                                    .id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (sourceNoteLinks)
                    await $_getPrefetchedData<
                      NoteRecord,
                      $NoteRecordsTable,
                      NoteLinkRecord
                    >(
                      currentTable: table,
                      referencedTable: $$NoteRecordsTableReferences
                          ._sourceNoteLinksTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$NoteRecordsTableReferences(
                                db,
                                table,
                                p0,
                              ).sourceNoteLinks,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.sourceNoteId == item.id,
                          ),
                      typedResults: items,
                    ),
                  if (targetNoteLinks)
                    await $_getPrefetchedData<
                      NoteRecord,
                      $NoteRecordsTable,
                      NoteLinkRecord
                    >(
                      currentTable: table,
                      referencedTable: $$NoteRecordsTableReferences
                          ._targetNoteLinksTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$NoteRecordsTableReferences(
                                db,
                                table,
                                p0,
                              ).targetNoteLinks,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.targetNoteId == item.id,
                          ),
                      typedResults: items,
                    ),
                  if (noteVersionRecordsRefs)
                    await $_getPrefetchedData<
                      NoteRecord,
                      $NoteRecordsTable,
                      NoteVersionRecord
                    >(
                      currentTable: table,
                      referencedTable: $$NoteRecordsTableReferences
                          ._noteVersionRecordsRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$NoteRecordsTableReferences(
                                db,
                                table,
                                p0,
                              ).noteVersionRecordsRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) =>
                              referencedItems.where((e) => e.noteId == item.id),
                      typedResults: items,
                    ),
                  if (taskRecordsRefs)
                    await $_getPrefetchedData<
                      NoteRecord,
                      $NoteRecordsTable,
                      TaskRecord
                    >(
                      currentTable: table,
                      referencedTable: $$NoteRecordsTableReferences
                          ._taskRecordsRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$NoteRecordsTableReferences(
                                db,
                                table,
                                p0,
                              ).taskRecordsRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) =>
                              referencedItems.where((e) => e.noteId == item.id),
                      typedResults: items,
                    ),
                  if (timeEntryRecordsRefs)
                    await $_getPrefetchedData<
                      NoteRecord,
                      $NoteRecordsTable,
                      TimeEntryRecord
                    >(
                      currentTable: table,
                      referencedTable: $$NoteRecordsTableReferences
                          ._timeEntryRecordsRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$NoteRecordsTableReferences(
                                db,
                                table,
                                p0,
                              ).timeEntryRecordsRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) =>
                              referencedItems.where((e) => e.noteId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$NoteRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$ChronicleDatabase,
      $NoteRecordsTable,
      NoteRecord,
      $$NoteRecordsTableFilterComposer,
      $$NoteRecordsTableOrderingComposer,
      $$NoteRecordsTableAnnotationComposer,
      $$NoteRecordsTableCreateCompanionBuilder,
      $$NoteRecordsTableUpdateCompanionBuilder,
      (NoteRecord, $$NoteRecordsTableReferences),
      NoteRecord,
      PrefetchHooks Function({
        bool projectId,
        bool sourceNoteLinks,
        bool targetNoteLinks,
        bool noteVersionRecordsRefs,
        bool taskRecordsRefs,
        bool timeEntryRecordsRefs,
      })
    >;
typedef $$NoteLinkRecordsTableCreateCompanionBuilder =
    NoteLinkRecordsCompanion Function({
      required String id,
      required String sourceNoteId,
      required String targetTitle,
      Value<String?> targetNoteId,
      required String createdAt,
      Value<int> rowid,
    });
typedef $$NoteLinkRecordsTableUpdateCompanionBuilder =
    NoteLinkRecordsCompanion Function({
      Value<String> id,
      Value<String> sourceNoteId,
      Value<String> targetTitle,
      Value<String?> targetNoteId,
      Value<String> createdAt,
      Value<int> rowid,
    });

final class $$NoteLinkRecordsTableReferences
    extends
        BaseReferences<
          _$ChronicleDatabase,
          $NoteLinkRecordsTable,
          NoteLinkRecord
        > {
  $$NoteLinkRecordsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $NoteRecordsTable _sourceNoteIdTable(_$ChronicleDatabase db) =>
      db.noteRecords.createAlias('note_links__source_note_id__notes__id');

  $$NoteRecordsTableProcessedTableManager get sourceNoteId {
    final $_column = $_itemColumn<String>('source_note_id')!;

    final manager = $$NoteRecordsTableTableManager(
      $_db,
      $_db.noteRecords,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceNoteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $NoteRecordsTable _targetNoteIdTable(_$ChronicleDatabase db) =>
      db.noteRecords.createAlias('note_links__target_note_id__notes__id');

  $$NoteRecordsTableProcessedTableManager? get targetNoteId {
    final $_column = $_itemColumn<String>('target_note_id');
    if ($_column == null) return null;
    final manager = $$NoteRecordsTableTableManager(
      $_db,
      $_db.noteRecords,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_targetNoteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$NoteLinkRecordsTableFilterComposer
    extends Composer<_$ChronicleDatabase, $NoteLinkRecordsTable> {
  $$NoteLinkRecordsTableFilterComposer({
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

  ColumnFilters<String> get targetTitle => $composableBuilder(
    column: $table.targetTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$NoteRecordsTableFilterComposer get sourceNoteId {
    final $$NoteRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceNoteId,
      referencedTable: $db.noteRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteRecordsTableFilterComposer(
            $db: $db,
            $table: $db.noteRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$NoteRecordsTableFilterComposer get targetNoteId {
    final $$NoteRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.targetNoteId,
      referencedTable: $db.noteRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteRecordsTableFilterComposer(
            $db: $db,
            $table: $db.noteRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteLinkRecordsTableOrderingComposer
    extends Composer<_$ChronicleDatabase, $NoteLinkRecordsTable> {
  $$NoteLinkRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get targetTitle => $composableBuilder(
    column: $table.targetTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$NoteRecordsTableOrderingComposer get sourceNoteId {
    final $$NoteRecordsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceNoteId,
      referencedTable: $db.noteRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteRecordsTableOrderingComposer(
            $db: $db,
            $table: $db.noteRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$NoteRecordsTableOrderingComposer get targetNoteId {
    final $$NoteRecordsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.targetNoteId,
      referencedTable: $db.noteRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteRecordsTableOrderingComposer(
            $db: $db,
            $table: $db.noteRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteLinkRecordsTableAnnotationComposer
    extends Composer<_$ChronicleDatabase, $NoteLinkRecordsTable> {
  $$NoteLinkRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get targetTitle => $composableBuilder(
    column: $table.targetTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$NoteRecordsTableAnnotationComposer get sourceNoteId {
    final $$NoteRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceNoteId,
      referencedTable: $db.noteRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.noteRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$NoteRecordsTableAnnotationComposer get targetNoteId {
    final $$NoteRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.targetNoteId,
      referencedTable: $db.noteRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.noteRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteLinkRecordsTableTableManager
    extends
        RootTableManager<
          _$ChronicleDatabase,
          $NoteLinkRecordsTable,
          NoteLinkRecord,
          $$NoteLinkRecordsTableFilterComposer,
          $$NoteLinkRecordsTableOrderingComposer,
          $$NoteLinkRecordsTableAnnotationComposer,
          $$NoteLinkRecordsTableCreateCompanionBuilder,
          $$NoteLinkRecordsTableUpdateCompanionBuilder,
          (NoteLinkRecord, $$NoteLinkRecordsTableReferences),
          NoteLinkRecord,
          PrefetchHooks Function({bool sourceNoteId, bool targetNoteId})
        > {
  $$NoteLinkRecordsTableTableManager(
    _$ChronicleDatabase db,
    $NoteLinkRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () =>
                  $$NoteLinkRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$NoteLinkRecordsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$NoteLinkRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sourceNoteId = const Value.absent(),
                Value<String> targetTitle = const Value.absent(),
                Value<String?> targetNoteId = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteLinkRecordsCompanion(
                id: id,
                sourceNoteId: sourceNoteId,
                targetTitle: targetTitle,
                targetNoteId: targetNoteId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sourceNoteId,
                required String targetTitle,
                Value<String?> targetNoteId = const Value.absent(),
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => NoteLinkRecordsCompanion.insert(
                id: id,
                sourceNoteId: sourceNoteId,
                targetTitle: targetTitle,
                targetNoteId: targetNoteId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$NoteLinkRecordsTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({
            sourceNoteId = false,
            targetNoteId = false,
          }) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
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
                if (sourceNoteId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.sourceNoteId,
                            referencedTable: $$NoteLinkRecordsTableReferences
                                ._sourceNoteIdTable(db),
                            referencedColumn:
                                $$NoteLinkRecordsTableReferences
                                    ._sourceNoteIdTable(db)
                                    .id,
                          )
                          as T;
                }
                if (targetNoteId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.targetNoteId,
                            referencedTable: $$NoteLinkRecordsTableReferences
                                ._targetNoteIdTable(db),
                            referencedColumn:
                                $$NoteLinkRecordsTableReferences
                                    ._targetNoteIdTable(db)
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

typedef $$NoteLinkRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$ChronicleDatabase,
      $NoteLinkRecordsTable,
      NoteLinkRecord,
      $$NoteLinkRecordsTableFilterComposer,
      $$NoteLinkRecordsTableOrderingComposer,
      $$NoteLinkRecordsTableAnnotationComposer,
      $$NoteLinkRecordsTableCreateCompanionBuilder,
      $$NoteLinkRecordsTableUpdateCompanionBuilder,
      (NoteLinkRecord, $$NoteLinkRecordsTableReferences),
      NoteLinkRecord,
      PrefetchHooks Function({bool sourceNoteId, bool targetNoteId})
    >;
typedef $$NoteVersionRecordsTableCreateCompanionBuilder =
    NoteVersionRecordsCompanion Function({
      required String id,
      required String noteId,
      required String title,
      Value<String> body,
      Value<String> tagsJson,
      Value<String> status,
      Value<String> folderPath,
      Value<String> noteType,
      Value<String> propertiesJson,
      Value<String> reason,
      required String createdAt,
      Value<int> rowid,
    });
typedef $$NoteVersionRecordsTableUpdateCompanionBuilder =
    NoteVersionRecordsCompanion Function({
      Value<String> id,
      Value<String> noteId,
      Value<String> title,
      Value<String> body,
      Value<String> tagsJson,
      Value<String> status,
      Value<String> folderPath,
      Value<String> noteType,
      Value<String> propertiesJson,
      Value<String> reason,
      Value<String> createdAt,
      Value<int> rowid,
    });

final class $$NoteVersionRecordsTableReferences
    extends
        BaseReferences<
          _$ChronicleDatabase,
          $NoteVersionRecordsTable,
          NoteVersionRecord
        > {
  $$NoteVersionRecordsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $NoteRecordsTable _noteIdTable(_$ChronicleDatabase db) =>
      db.noteRecords.createAlias('note_versions__note_id__notes__id');

  $$NoteRecordsTableProcessedTableManager get noteId {
    final $_column = $_itemColumn<String>('note_id')!;

    final manager = $$NoteRecordsTableTableManager(
      $_db,
      $_db.noteRecords,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_noteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$NoteVersionRecordsTableFilterComposer
    extends Composer<_$ChronicleDatabase, $NoteVersionRecordsTable> {
  $$NoteVersionRecordsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderPath => $composableBuilder(
    column: $table.folderPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get noteType => $composableBuilder(
    column: $table.noteType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get propertiesJson => $composableBuilder(
    column: $table.propertiesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$NoteRecordsTableFilterComposer get noteId {
    final $$NoteRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.noteRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteRecordsTableFilterComposer(
            $db: $db,
            $table: $db.noteRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteVersionRecordsTableOrderingComposer
    extends Composer<_$ChronicleDatabase, $NoteVersionRecordsTable> {
  $$NoteVersionRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderPath => $composableBuilder(
    column: $table.folderPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get noteType => $composableBuilder(
    column: $table.noteType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get propertiesJson => $composableBuilder(
    column: $table.propertiesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$NoteRecordsTableOrderingComposer get noteId {
    final $$NoteRecordsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.noteRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteRecordsTableOrderingComposer(
            $db: $db,
            $table: $db.noteRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteVersionRecordsTableAnnotationComposer
    extends Composer<_$ChronicleDatabase, $NoteVersionRecordsTable> {
  $$NoteVersionRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get tagsJson =>
      $composableBuilder(column: $table.tagsJson, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get folderPath => $composableBuilder(
    column: $table.folderPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get noteType =>
      $composableBuilder(column: $table.noteType, builder: (column) => column);

  GeneratedColumn<String> get propertiesJson => $composableBuilder(
    column: $table.propertiesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$NoteRecordsTableAnnotationComposer get noteId {
    final $$NoteRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.noteRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.noteRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteVersionRecordsTableTableManager
    extends
        RootTableManager<
          _$ChronicleDatabase,
          $NoteVersionRecordsTable,
          NoteVersionRecord,
          $$NoteVersionRecordsTableFilterComposer,
          $$NoteVersionRecordsTableOrderingComposer,
          $$NoteVersionRecordsTableAnnotationComposer,
          $$NoteVersionRecordsTableCreateCompanionBuilder,
          $$NoteVersionRecordsTableUpdateCompanionBuilder,
          (NoteVersionRecord, $$NoteVersionRecordsTableReferences),
          NoteVersionRecord,
          PrefetchHooks Function({bool noteId})
        > {
  $$NoteVersionRecordsTableTableManager(
    _$ChronicleDatabase db,
    $NoteVersionRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$NoteVersionRecordsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$NoteVersionRecordsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$NoteVersionRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> noteId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> folderPath = const Value.absent(),
                Value<String> noteType = const Value.absent(),
                Value<String> propertiesJson = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteVersionRecordsCompanion(
                id: id,
                noteId: noteId,
                title: title,
                body: body,
                tagsJson: tagsJson,
                status: status,
                folderPath: folderPath,
                noteType: noteType,
                propertiesJson: propertiesJson,
                reason: reason,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String noteId,
                required String title,
                Value<String> body = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> folderPath = const Value.absent(),
                Value<String> noteType = const Value.absent(),
                Value<String> propertiesJson = const Value.absent(),
                Value<String> reason = const Value.absent(),
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => NoteVersionRecordsCompanion.insert(
                id: id,
                noteId: noteId,
                title: title,
                body: body,
                tagsJson: tagsJson,
                status: status,
                folderPath: folderPath,
                noteType: noteType,
                propertiesJson: propertiesJson,
                reason: reason,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$NoteVersionRecordsTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({noteId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
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
                if (noteId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.noteId,
                            referencedTable: $$NoteVersionRecordsTableReferences
                                ._noteIdTable(db),
                            referencedColumn:
                                $$NoteVersionRecordsTableReferences
                                    ._noteIdTable(db)
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

typedef $$NoteVersionRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$ChronicleDatabase,
      $NoteVersionRecordsTable,
      NoteVersionRecord,
      $$NoteVersionRecordsTableFilterComposer,
      $$NoteVersionRecordsTableOrderingComposer,
      $$NoteVersionRecordsTableAnnotationComposer,
      $$NoteVersionRecordsTableCreateCompanionBuilder,
      $$NoteVersionRecordsTableUpdateCompanionBuilder,
      (NoteVersionRecord, $$NoteVersionRecordsTableReferences),
      NoteVersionRecord,
      PrefetchHooks Function({bool noteId})
    >;
typedef $$TaskRecordsTableCreateCompanionBuilder =
    TaskRecordsCompanion Function({
      required String id,
      required String projectId,
      Value<String?> parentTaskId,
      Value<String?> noteId,
      required String title,
      Value<String> description,
      Value<String> status,
      Value<int> priority,
      Value<int> estimateMinutes,
      Value<int> sortOrder,
      Value<String?> dueAt,
      required String createdAt,
      required String updatedAt,
      Value<String?> completedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $$TaskRecordsTableUpdateCompanionBuilder =
    TaskRecordsCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<String?> parentTaskId,
      Value<String?> noteId,
      Value<String> title,
      Value<String> description,
      Value<String> status,
      Value<int> priority,
      Value<int> estimateMinutes,
      Value<int> sortOrder,
      Value<String?> dueAt,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<String?> completedAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });

final class $$TaskRecordsTableReferences
    extends BaseReferences<_$ChronicleDatabase, $TaskRecordsTable, TaskRecord> {
  $$TaskRecordsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectRecordsTable _projectIdTable(_$ChronicleDatabase db) =>
      db.projectRecords.createAlias('tasks__project_id__projects__id');

  $$ProjectRecordsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectRecordsTableTableManager(
      $_db,
      $_db.projectRecords,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $NoteRecordsTable _noteIdTable(_$ChronicleDatabase db) =>
      db.noteRecords.createAlias('tasks__note_id__notes__id');

  $$NoteRecordsTableProcessedTableManager? get noteId {
    final $_column = $_itemColumn<String>('note_id');
    if ($_column == null) return null;
    final manager = $$NoteRecordsTableTableManager(
      $_db,
      $_db.noteRecords,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_noteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TimeEntryRecordsTable, List<TimeEntryRecord>>
  _timeEntryRecordsRefsTable(_$ChronicleDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.timeEntryRecords,
        aliasName: 'tasks__id__time_entries__task_id',
      );

  $$TimeEntryRecordsTableProcessedTableManager get timeEntryRecordsRefs {
    final manager = $$TimeEntryRecordsTableTableManager(
      $_db,
      $_db.timeEntryRecords,
    ).filter((f) => f.taskId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _timeEntryRecordsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TaskRecordsTableFilterComposer
    extends Composer<_$ChronicleDatabase, $TaskRecordsTable> {
  $$TaskRecordsTableFilterComposer({
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

  ColumnFilters<String> get parentTaskId => $composableBuilder(
    column: $table.parentTaskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get estimateMinutes => $composableBuilder(
    column: $table.estimateMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectRecordsTableFilterComposer get projectId {
    final $$ProjectRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projectRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectRecordsTableFilterComposer(
            $db: $db,
            $table: $db.projectRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$NoteRecordsTableFilterComposer get noteId {
    final $$NoteRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.noteRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteRecordsTableFilterComposer(
            $db: $db,
            $table: $db.noteRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> timeEntryRecordsRefs(
    Expression<bool> Function($$TimeEntryRecordsTableFilterComposer f) f,
  ) {
    final $$TimeEntryRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.timeEntryRecords,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TimeEntryRecordsTableFilterComposer(
            $db: $db,
            $table: $db.timeEntryRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TaskRecordsTableOrderingComposer
    extends Composer<_$ChronicleDatabase, $TaskRecordsTable> {
  $$TaskRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get parentTaskId => $composableBuilder(
    column: $table.parentTaskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get estimateMinutes => $composableBuilder(
    column: $table.estimateMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectRecordsTableOrderingComposer get projectId {
    final $$ProjectRecordsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projectRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectRecordsTableOrderingComposer(
            $db: $db,
            $table: $db.projectRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$NoteRecordsTableOrderingComposer get noteId {
    final $$NoteRecordsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.noteRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteRecordsTableOrderingComposer(
            $db: $db,
            $table: $db.noteRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskRecordsTableAnnotationComposer
    extends Composer<_$ChronicleDatabase, $TaskRecordsTable> {
  $$TaskRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get parentTaskId => $composableBuilder(
    column: $table.parentTaskId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<int> get estimateMinutes => $composableBuilder(
    column: $table.estimateMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$ProjectRecordsTableAnnotationComposer get projectId {
    final $$ProjectRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projectRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.projectRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$NoteRecordsTableAnnotationComposer get noteId {
    final $$NoteRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.noteRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.noteRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> timeEntryRecordsRefs<T extends Object>(
    Expression<T> Function($$TimeEntryRecordsTableAnnotationComposer a) f,
  ) {
    final $$TimeEntryRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.timeEntryRecords,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TimeEntryRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.timeEntryRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TaskRecordsTableTableManager
    extends
        RootTableManager<
          _$ChronicleDatabase,
          $TaskRecordsTable,
          TaskRecord,
          $$TaskRecordsTableFilterComposer,
          $$TaskRecordsTableOrderingComposer,
          $$TaskRecordsTableAnnotationComposer,
          $$TaskRecordsTableCreateCompanionBuilder,
          $$TaskRecordsTableUpdateCompanionBuilder,
          (TaskRecord, $$TaskRecordsTableReferences),
          TaskRecord,
          PrefetchHooks Function({
            bool projectId,
            bool noteId,
            bool timeEntryRecordsRefs,
          })
        > {
  $$TaskRecordsTableTableManager(
    _$ChronicleDatabase db,
    $TaskRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$TaskRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$TaskRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$TaskRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String?> parentTaskId = const Value.absent(),
                Value<String?> noteId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int> estimateMinutes = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> dueAt = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> completedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskRecordsCompanion(
                id: id,
                projectId: projectId,
                parentTaskId: parentTaskId,
                noteId: noteId,
                title: title,
                description: description,
                status: status,
                priority: priority,
                estimateMinutes: estimateMinutes,
                sortOrder: sortOrder,
                dueAt: dueAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                Value<String?> parentTaskId = const Value.absent(),
                Value<String?> noteId = const Value.absent(),
                required String title,
                Value<String> description = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int> estimateMinutes = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> dueAt = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                Value<String?> completedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskRecordsCompanion.insert(
                id: id,
                projectId: projectId,
                parentTaskId: parentTaskId,
                noteId: noteId,
                title: title,
                description: description,
                status: status,
                priority: priority,
                estimateMinutes: estimateMinutes,
                sortOrder: sortOrder,
                dueAt: dueAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$TaskRecordsTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({
            projectId = false,
            noteId = false,
            timeEntryRecordsRefs = false,
          }) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (timeEntryRecordsRefs) db.timeEntryRecords,
              ],
              addJoins: <
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
                if (projectId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.projectId,
                            referencedTable: $$TaskRecordsTableReferences
                                ._projectIdTable(db),
                            referencedColumn:
                                $$TaskRecordsTableReferences
                                    ._projectIdTable(db)
                                    .id,
                          )
                          as T;
                }
                if (noteId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.noteId,
                            referencedTable: $$TaskRecordsTableReferences
                                ._noteIdTable(db),
                            referencedColumn:
                                $$TaskRecordsTableReferences
                                    ._noteIdTable(db)
                                    .id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (timeEntryRecordsRefs)
                    await $_getPrefetchedData<
                      TaskRecord,
                      $TaskRecordsTable,
                      TimeEntryRecord
                    >(
                      currentTable: table,
                      referencedTable: $$TaskRecordsTableReferences
                          ._timeEntryRecordsRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$TaskRecordsTableReferences(
                                db,
                                table,
                                p0,
                              ).timeEntryRecordsRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) =>
                              referencedItems.where((e) => e.taskId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TaskRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$ChronicleDatabase,
      $TaskRecordsTable,
      TaskRecord,
      $$TaskRecordsTableFilterComposer,
      $$TaskRecordsTableOrderingComposer,
      $$TaskRecordsTableAnnotationComposer,
      $$TaskRecordsTableCreateCompanionBuilder,
      $$TaskRecordsTableUpdateCompanionBuilder,
      (TaskRecord, $$TaskRecordsTableReferences),
      TaskRecord,
      PrefetchHooks Function({
        bool projectId,
        bool noteId,
        bool timeEntryRecordsRefs,
      })
    >;
typedef $$TimeEntryRecordsTableCreateCompanionBuilder =
    TimeEntryRecordsCompanion Function({
      required String id,
      required String projectId,
      Value<String?> taskId,
      Value<String?> noteId,
      Value<String> description,
      required String startedAt,
      required int durationSeconds,
      required String createdAt,
      Value<int> rowid,
    });
typedef $$TimeEntryRecordsTableUpdateCompanionBuilder =
    TimeEntryRecordsCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<String?> taskId,
      Value<String?> noteId,
      Value<String> description,
      Value<String> startedAt,
      Value<int> durationSeconds,
      Value<String> createdAt,
      Value<int> rowid,
    });

final class $$TimeEntryRecordsTableReferences
    extends
        BaseReferences<
          _$ChronicleDatabase,
          $TimeEntryRecordsTable,
          TimeEntryRecord
        > {
  $$TimeEntryRecordsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProjectRecordsTable _projectIdTable(_$ChronicleDatabase db) =>
      db.projectRecords.createAlias('time_entries__project_id__projects__id');

  $$ProjectRecordsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectRecordsTableTableManager(
      $_db,
      $_db.projectRecords,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TaskRecordsTable _taskIdTable(_$ChronicleDatabase db) =>
      db.taskRecords.createAlias('time_entries__task_id__tasks__id');

  $$TaskRecordsTableProcessedTableManager? get taskId {
    final $_column = $_itemColumn<String>('task_id');
    if ($_column == null) return null;
    final manager = $$TaskRecordsTableTableManager(
      $_db,
      $_db.taskRecords,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $NoteRecordsTable _noteIdTable(_$ChronicleDatabase db) =>
      db.noteRecords.createAlias('time_entries__note_id__notes__id');

  $$NoteRecordsTableProcessedTableManager? get noteId {
    final $_column = $_itemColumn<String>('note_id');
    if ($_column == null) return null;
    final manager = $$NoteRecordsTableTableManager(
      $_db,
      $_db.noteRecords,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_noteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TimeEntryRecordsTableFilterComposer
    extends Composer<_$ChronicleDatabase, $TimeEntryRecordsTable> {
  $$TimeEntryRecordsTableFilterComposer({
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

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectRecordsTableFilterComposer get projectId {
    final $$ProjectRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projectRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectRecordsTableFilterComposer(
            $db: $db,
            $table: $db.projectRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TaskRecordsTableFilterComposer get taskId {
    final $$TaskRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.taskRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskRecordsTableFilterComposer(
            $db: $db,
            $table: $db.taskRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$NoteRecordsTableFilterComposer get noteId {
    final $$NoteRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.noteRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteRecordsTableFilterComposer(
            $db: $db,
            $table: $db.noteRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TimeEntryRecordsTableOrderingComposer
    extends Composer<_$ChronicleDatabase, $TimeEntryRecordsTable> {
  $$TimeEntryRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectRecordsTableOrderingComposer get projectId {
    final $$ProjectRecordsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projectRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectRecordsTableOrderingComposer(
            $db: $db,
            $table: $db.projectRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TaskRecordsTableOrderingComposer get taskId {
    final $$TaskRecordsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.taskRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskRecordsTableOrderingComposer(
            $db: $db,
            $table: $db.taskRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$NoteRecordsTableOrderingComposer get noteId {
    final $$NoteRecordsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.noteRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteRecordsTableOrderingComposer(
            $db: $db,
            $table: $db.noteRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TimeEntryRecordsTableAnnotationComposer
    extends Composer<_$ChronicleDatabase, $TimeEntryRecordsTable> {
  $$TimeEntryRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ProjectRecordsTableAnnotationComposer get projectId {
    final $$ProjectRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projectRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.projectRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TaskRecordsTableAnnotationComposer get taskId {
    final $$TaskRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.taskRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.taskRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$NoteRecordsTableAnnotationComposer get noteId {
    final $$NoteRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.noteRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.noteRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TimeEntryRecordsTableTableManager
    extends
        RootTableManager<
          _$ChronicleDatabase,
          $TimeEntryRecordsTable,
          TimeEntryRecord,
          $$TimeEntryRecordsTableFilterComposer,
          $$TimeEntryRecordsTableOrderingComposer,
          $$TimeEntryRecordsTableAnnotationComposer,
          $$TimeEntryRecordsTableCreateCompanionBuilder,
          $$TimeEntryRecordsTableUpdateCompanionBuilder,
          (TimeEntryRecord, $$TimeEntryRecordsTableReferences),
          TimeEntryRecord,
          PrefetchHooks Function({bool projectId, bool taskId, bool noteId})
        > {
  $$TimeEntryRecordsTableTableManager(
    _$ChronicleDatabase db,
    $TimeEntryRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () =>
                  $$TimeEntryRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$TimeEntryRecordsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$TimeEntryRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String?> taskId = const Value.absent(),
                Value<String?> noteId = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> startedAt = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TimeEntryRecordsCompanion(
                id: id,
                projectId: projectId,
                taskId: taskId,
                noteId: noteId,
                description: description,
                startedAt: startedAt,
                durationSeconds: durationSeconds,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                Value<String?> taskId = const Value.absent(),
                Value<String?> noteId = const Value.absent(),
                Value<String> description = const Value.absent(),
                required String startedAt,
                required int durationSeconds,
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => TimeEntryRecordsCompanion.insert(
                id: id,
                projectId: projectId,
                taskId: taskId,
                noteId: noteId,
                description: description,
                startedAt: startedAt,
                durationSeconds: durationSeconds,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$TimeEntryRecordsTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({
            projectId = false,
            taskId = false,
            noteId = false,
          }) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
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
                if (projectId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.projectId,
                            referencedTable: $$TimeEntryRecordsTableReferences
                                ._projectIdTable(db),
                            referencedColumn:
                                $$TimeEntryRecordsTableReferences
                                    ._projectIdTable(db)
                                    .id,
                          )
                          as T;
                }
                if (taskId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.taskId,
                            referencedTable: $$TimeEntryRecordsTableReferences
                                ._taskIdTable(db),
                            referencedColumn:
                                $$TimeEntryRecordsTableReferences
                                    ._taskIdTable(db)
                                    .id,
                          )
                          as T;
                }
                if (noteId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.noteId,
                            referencedTable: $$TimeEntryRecordsTableReferences
                                ._noteIdTable(db),
                            referencedColumn:
                                $$TimeEntryRecordsTableReferences
                                    ._noteIdTable(db)
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

typedef $$TimeEntryRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$ChronicleDatabase,
      $TimeEntryRecordsTable,
      TimeEntryRecord,
      $$TimeEntryRecordsTableFilterComposer,
      $$TimeEntryRecordsTableOrderingComposer,
      $$TimeEntryRecordsTableAnnotationComposer,
      $$TimeEntryRecordsTableCreateCompanionBuilder,
      $$TimeEntryRecordsTableUpdateCompanionBuilder,
      (TimeEntryRecord, $$TimeEntryRecordsTableReferences),
      TimeEntryRecord,
      PrefetchHooks Function({bool projectId, bool taskId, bool noteId})
    >;
typedef $$DeviceIdentityRecordsTableCreateCompanionBuilder =
    DeviceIdentityRecordsCompanion Function({
      required String deviceId,
      required String displayName,
      required String platform,
      required String createdAt,
      required String lastSeenAt,
      Value<int> rowid,
    });
typedef $$DeviceIdentityRecordsTableUpdateCompanionBuilder =
    DeviceIdentityRecordsCompanion Function({
      Value<String> deviceId,
      Value<String> displayName,
      Value<String> platform,
      Value<String> createdAt,
      Value<String> lastSeenAt,
      Value<int> rowid,
    });

class $$DeviceIdentityRecordsTableFilterComposer
    extends Composer<_$ChronicleDatabase, $DeviceIdentityRecordsTable> {
  $$DeviceIdentityRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DeviceIdentityRecordsTableOrderingComposer
    extends Composer<_$ChronicleDatabase, $DeviceIdentityRecordsTable> {
  $$DeviceIdentityRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DeviceIdentityRecordsTableAnnotationComposer
    extends Composer<_$ChronicleDatabase, $DeviceIdentityRecordsTable> {
  $$DeviceIdentityRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get platform =>
      $composableBuilder(column: $table.platform, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );
}

class $$DeviceIdentityRecordsTableTableManager
    extends
        RootTableManager<
          _$ChronicleDatabase,
          $DeviceIdentityRecordsTable,
          DeviceIdentityRecord,
          $$DeviceIdentityRecordsTableFilterComposer,
          $$DeviceIdentityRecordsTableOrderingComposer,
          $$DeviceIdentityRecordsTableAnnotationComposer,
          $$DeviceIdentityRecordsTableCreateCompanionBuilder,
          $$DeviceIdentityRecordsTableUpdateCompanionBuilder,
          (
            DeviceIdentityRecord,
            BaseReferences<
              _$ChronicleDatabase,
              $DeviceIdentityRecordsTable,
              DeviceIdentityRecord
            >,
          ),
          DeviceIdentityRecord,
          PrefetchHooks Function()
        > {
  $$DeviceIdentityRecordsTableTableManager(
    _$ChronicleDatabase db,
    $DeviceIdentityRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$DeviceIdentityRecordsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$DeviceIdentityRecordsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$DeviceIdentityRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> deviceId = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> platform = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> lastSeenAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeviceIdentityRecordsCompanion(
                deviceId: deviceId,
                displayName: displayName,
                platform: platform,
                createdAt: createdAt,
                lastSeenAt: lastSeenAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String deviceId,
                required String displayName,
                required String platform,
                required String createdAt,
                required String lastSeenAt,
                Value<int> rowid = const Value.absent(),
              }) => DeviceIdentityRecordsCompanion.insert(
                deviceId: deviceId,
                displayName: displayName,
                platform: platform,
                createdAt: createdAt,
                lastSeenAt: lastSeenAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeviceIdentityRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$ChronicleDatabase,
      $DeviceIdentityRecordsTable,
      DeviceIdentityRecord,
      $$DeviceIdentityRecordsTableFilterComposer,
      $$DeviceIdentityRecordsTableOrderingComposer,
      $$DeviceIdentityRecordsTableAnnotationComposer,
      $$DeviceIdentityRecordsTableCreateCompanionBuilder,
      $$DeviceIdentityRecordsTableUpdateCompanionBuilder,
      (
        DeviceIdentityRecord,
        BaseReferences<
          _$ChronicleDatabase,
          $DeviceIdentityRecordsTable,
          DeviceIdentityRecord
        >,
      ),
      DeviceIdentityRecord,
      PrefetchHooks Function()
    >;
typedef $$TrustedDeviceRecordsTableCreateCompanionBuilder =
    TrustedDeviceRecordsCompanion Function({
      required String deviceId,
      required String displayName,
      required String platform,
      required String publicKey,
      required String pairedAt,
      Value<String?> lastSeenAt,
      Value<String?> lastSyncAt,
      Value<String?> revokedAt,
      Value<bool> autoSyncEnabled,
      Value<int> rowid,
    });
typedef $$TrustedDeviceRecordsTableUpdateCompanionBuilder =
    TrustedDeviceRecordsCompanion Function({
      Value<String> deviceId,
      Value<String> displayName,
      Value<String> platform,
      Value<String> publicKey,
      Value<String> pairedAt,
      Value<String?> lastSeenAt,
      Value<String?> lastSyncAt,
      Value<String?> revokedAt,
      Value<bool> autoSyncEnabled,
      Value<int> rowid,
    });

class $$TrustedDeviceRecordsTableFilterComposer
    extends Composer<_$ChronicleDatabase, $TrustedDeviceRecordsTable> {
  $$TrustedDeviceRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publicKey => $composableBuilder(
    column: $table.publicKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pairedAt => $composableBuilder(
    column: $table.pairedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get revokedAt => $composableBuilder(
    column: $table.revokedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoSyncEnabled => $composableBuilder(
    column: $table.autoSyncEnabled,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TrustedDeviceRecordsTableOrderingComposer
    extends Composer<_$ChronicleDatabase, $TrustedDeviceRecordsTable> {
  $$TrustedDeviceRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publicKey => $composableBuilder(
    column: $table.publicKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pairedAt => $composableBuilder(
    column: $table.pairedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get revokedAt => $composableBuilder(
    column: $table.revokedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoSyncEnabled => $composableBuilder(
    column: $table.autoSyncEnabled,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TrustedDeviceRecordsTableAnnotationComposer
    extends Composer<_$ChronicleDatabase, $TrustedDeviceRecordsTable> {
  $$TrustedDeviceRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get platform =>
      $composableBuilder(column: $table.platform, builder: (column) => column);

  GeneratedColumn<String> get publicKey =>
      $composableBuilder(column: $table.publicKey, builder: (column) => column);

  GeneratedColumn<String> get pairedAt =>
      $composableBuilder(column: $table.pairedAt, builder: (column) => column);

  GeneratedColumn<String> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get revokedAt =>
      $composableBuilder(column: $table.revokedAt, builder: (column) => column);

  GeneratedColumn<bool> get autoSyncEnabled => $composableBuilder(
    column: $table.autoSyncEnabled,
    builder: (column) => column,
  );
}

class $$TrustedDeviceRecordsTableTableManager
    extends
        RootTableManager<
          _$ChronicleDatabase,
          $TrustedDeviceRecordsTable,
          TrustedDeviceRecord,
          $$TrustedDeviceRecordsTableFilterComposer,
          $$TrustedDeviceRecordsTableOrderingComposer,
          $$TrustedDeviceRecordsTableAnnotationComposer,
          $$TrustedDeviceRecordsTableCreateCompanionBuilder,
          $$TrustedDeviceRecordsTableUpdateCompanionBuilder,
          (
            TrustedDeviceRecord,
            BaseReferences<
              _$ChronicleDatabase,
              $TrustedDeviceRecordsTable,
              TrustedDeviceRecord
            >,
          ),
          TrustedDeviceRecord,
          PrefetchHooks Function()
        > {
  $$TrustedDeviceRecordsTableTableManager(
    _$ChronicleDatabase db,
    $TrustedDeviceRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$TrustedDeviceRecordsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$TrustedDeviceRecordsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$TrustedDeviceRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> deviceId = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> platform = const Value.absent(),
                Value<String> publicKey = const Value.absent(),
                Value<String> pairedAt = const Value.absent(),
                Value<String?> lastSeenAt = const Value.absent(),
                Value<String?> lastSyncAt = const Value.absent(),
                Value<String?> revokedAt = const Value.absent(),
                Value<bool> autoSyncEnabled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrustedDeviceRecordsCompanion(
                deviceId: deviceId,
                displayName: displayName,
                platform: platform,
                publicKey: publicKey,
                pairedAt: pairedAt,
                lastSeenAt: lastSeenAt,
                lastSyncAt: lastSyncAt,
                revokedAt: revokedAt,
                autoSyncEnabled: autoSyncEnabled,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String deviceId,
                required String displayName,
                required String platform,
                required String publicKey,
                required String pairedAt,
                Value<String?> lastSeenAt = const Value.absent(),
                Value<String?> lastSyncAt = const Value.absent(),
                Value<String?> revokedAt = const Value.absent(),
                Value<bool> autoSyncEnabled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrustedDeviceRecordsCompanion.insert(
                deviceId: deviceId,
                displayName: displayName,
                platform: platform,
                publicKey: publicKey,
                pairedAt: pairedAt,
                lastSeenAt: lastSeenAt,
                lastSyncAt: lastSyncAt,
                revokedAt: revokedAt,
                autoSyncEnabled: autoSyncEnabled,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TrustedDeviceRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$ChronicleDatabase,
      $TrustedDeviceRecordsTable,
      TrustedDeviceRecord,
      $$TrustedDeviceRecordsTableFilterComposer,
      $$TrustedDeviceRecordsTableOrderingComposer,
      $$TrustedDeviceRecordsTableAnnotationComposer,
      $$TrustedDeviceRecordsTableCreateCompanionBuilder,
      $$TrustedDeviceRecordsTableUpdateCompanionBuilder,
      (
        TrustedDeviceRecord,
        BaseReferences<
          _$ChronicleDatabase,
          $TrustedDeviceRecordsTable,
          TrustedDeviceRecord
        >,
      ),
      TrustedDeviceRecord,
      PrefetchHooks Function()
    >;
typedef $$ChangeRecordRecordsTableCreateCompanionBuilder =
    ChangeRecordRecordsCompanion Function({
      Value<int> localSequence,
      required String changeId,
      required String entityType,
      required String entityId,
      required String operation,
      required int revision,
      required String originDeviceId,
      required String changedAt,
      required String payloadJson,
      Value<String?> appliedAt,
    });
typedef $$ChangeRecordRecordsTableUpdateCompanionBuilder =
    ChangeRecordRecordsCompanion Function({
      Value<int> localSequence,
      Value<String> changeId,
      Value<String> entityType,
      Value<String> entityId,
      Value<String> operation,
      Value<int> revision,
      Value<String> originDeviceId,
      Value<String> changedAt,
      Value<String> payloadJson,
      Value<String?> appliedAt,
    });

class $$ChangeRecordRecordsTableFilterComposer
    extends Composer<_$ChronicleDatabase, $ChangeRecordRecordsTable> {
  $$ChangeRecordRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get localSequence => $composableBuilder(
    column: $table.localSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get changeId => $composableBuilder(
    column: $table.changeId,
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

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originDeviceId => $composableBuilder(
    column: $table.originDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get changedAt => $composableBuilder(
    column: $table.changedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get appliedAt => $composableBuilder(
    column: $table.appliedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChangeRecordRecordsTableOrderingComposer
    extends Composer<_$ChronicleDatabase, $ChangeRecordRecordsTable> {
  $$ChangeRecordRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get localSequence => $composableBuilder(
    column: $table.localSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get changeId => $composableBuilder(
    column: $table.changeId,
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

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originDeviceId => $composableBuilder(
    column: $table.originDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get changedAt => $composableBuilder(
    column: $table.changedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get appliedAt => $composableBuilder(
    column: $table.appliedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChangeRecordRecordsTableAnnotationComposer
    extends Composer<_$ChronicleDatabase, $ChangeRecordRecordsTable> {
  $$ChangeRecordRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get localSequence => $composableBuilder(
    column: $table.localSequence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get changeId =>
      $composableBuilder(column: $table.changeId, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get originDeviceId => $composableBuilder(
    column: $table.originDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get changedAt =>
      $composableBuilder(column: $table.changedAt, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get appliedAt =>
      $composableBuilder(column: $table.appliedAt, builder: (column) => column);
}

class $$ChangeRecordRecordsTableTableManager
    extends
        RootTableManager<
          _$ChronicleDatabase,
          $ChangeRecordRecordsTable,
          ChangeRecordRecord,
          $$ChangeRecordRecordsTableFilterComposer,
          $$ChangeRecordRecordsTableOrderingComposer,
          $$ChangeRecordRecordsTableAnnotationComposer,
          $$ChangeRecordRecordsTableCreateCompanionBuilder,
          $$ChangeRecordRecordsTableUpdateCompanionBuilder,
          (
            ChangeRecordRecord,
            BaseReferences<
              _$ChronicleDatabase,
              $ChangeRecordRecordsTable,
              ChangeRecordRecord
            >,
          ),
          ChangeRecordRecord,
          PrefetchHooks Function()
        > {
  $$ChangeRecordRecordsTableTableManager(
    _$ChronicleDatabase db,
    $ChangeRecordRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$ChangeRecordRecordsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$ChangeRecordRecordsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$ChangeRecordRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> localSequence = const Value.absent(),
                Value<String> changeId = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> originDeviceId = const Value.absent(),
                Value<String> changedAt = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String?> appliedAt = const Value.absent(),
              }) => ChangeRecordRecordsCompanion(
                localSequence: localSequence,
                changeId: changeId,
                entityType: entityType,
                entityId: entityId,
                operation: operation,
                revision: revision,
                originDeviceId: originDeviceId,
                changedAt: changedAt,
                payloadJson: payloadJson,
                appliedAt: appliedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> localSequence = const Value.absent(),
                required String changeId,
                required String entityType,
                required String entityId,
                required String operation,
                required int revision,
                required String originDeviceId,
                required String changedAt,
                required String payloadJson,
                Value<String?> appliedAt = const Value.absent(),
              }) => ChangeRecordRecordsCompanion.insert(
                localSequence: localSequence,
                changeId: changeId,
                entityType: entityType,
                entityId: entityId,
                operation: operation,
                revision: revision,
                originDeviceId: originDeviceId,
                changedAt: changedAt,
                payloadJson: payloadJson,
                appliedAt: appliedAt,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChangeRecordRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$ChronicleDatabase,
      $ChangeRecordRecordsTable,
      ChangeRecordRecord,
      $$ChangeRecordRecordsTableFilterComposer,
      $$ChangeRecordRecordsTableOrderingComposer,
      $$ChangeRecordRecordsTableAnnotationComposer,
      $$ChangeRecordRecordsTableCreateCompanionBuilder,
      $$ChangeRecordRecordsTableUpdateCompanionBuilder,
      (
        ChangeRecordRecord,
        BaseReferences<
          _$ChronicleDatabase,
          $ChangeRecordRecordsTable,
          ChangeRecordRecord
        >,
      ),
      ChangeRecordRecord,
      PrefetchHooks Function()
    >;
typedef $$SyncCursorRecordsTableCreateCompanionBuilder =
    SyncCursorRecordsCompanion Function({
      required String peerDeviceId,
      Value<int> lastSentSequence,
      Value<String?> lastReceivedChangeId,
      Value<String?> lastSuccessAt,
      Value<int> rowid,
    });
typedef $$SyncCursorRecordsTableUpdateCompanionBuilder =
    SyncCursorRecordsCompanion Function({
      Value<String> peerDeviceId,
      Value<int> lastSentSequence,
      Value<String?> lastReceivedChangeId,
      Value<String?> lastSuccessAt,
      Value<int> rowid,
    });

class $$SyncCursorRecordsTableFilterComposer
    extends Composer<_$ChronicleDatabase, $SyncCursorRecordsTable> {
  $$SyncCursorRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get peerDeviceId => $composableBuilder(
    column: $table.peerDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSentSequence => $composableBuilder(
    column: $table.lastSentSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastReceivedChangeId => $composableBuilder(
    column: $table.lastReceivedChangeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastSuccessAt => $composableBuilder(
    column: $table.lastSuccessAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncCursorRecordsTableOrderingComposer
    extends Composer<_$ChronicleDatabase, $SyncCursorRecordsTable> {
  $$SyncCursorRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get peerDeviceId => $composableBuilder(
    column: $table.peerDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSentSequence => $composableBuilder(
    column: $table.lastSentSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastReceivedChangeId => $composableBuilder(
    column: $table.lastReceivedChangeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastSuccessAt => $composableBuilder(
    column: $table.lastSuccessAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncCursorRecordsTableAnnotationComposer
    extends Composer<_$ChronicleDatabase, $SyncCursorRecordsTable> {
  $$SyncCursorRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get peerDeviceId => $composableBuilder(
    column: $table.peerDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSentSequence => $composableBuilder(
    column: $table.lastSentSequence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastReceivedChangeId => $composableBuilder(
    column: $table.lastReceivedChangeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastSuccessAt => $composableBuilder(
    column: $table.lastSuccessAt,
    builder: (column) => column,
  );
}

class $$SyncCursorRecordsTableTableManager
    extends
        RootTableManager<
          _$ChronicleDatabase,
          $SyncCursorRecordsTable,
          SyncCursorRecord,
          $$SyncCursorRecordsTableFilterComposer,
          $$SyncCursorRecordsTableOrderingComposer,
          $$SyncCursorRecordsTableAnnotationComposer,
          $$SyncCursorRecordsTableCreateCompanionBuilder,
          $$SyncCursorRecordsTableUpdateCompanionBuilder,
          (
            SyncCursorRecord,
            BaseReferences<
              _$ChronicleDatabase,
              $SyncCursorRecordsTable,
              SyncCursorRecord
            >,
          ),
          SyncCursorRecord,
          PrefetchHooks Function()
        > {
  $$SyncCursorRecordsTableTableManager(
    _$ChronicleDatabase db,
    $SyncCursorRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$SyncCursorRecordsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$SyncCursorRecordsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$SyncCursorRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> peerDeviceId = const Value.absent(),
                Value<int> lastSentSequence = const Value.absent(),
                Value<String?> lastReceivedChangeId = const Value.absent(),
                Value<String?> lastSuccessAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorRecordsCompanion(
                peerDeviceId: peerDeviceId,
                lastSentSequence: lastSentSequence,
                lastReceivedChangeId: lastReceivedChangeId,
                lastSuccessAt: lastSuccessAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String peerDeviceId,
                Value<int> lastSentSequence = const Value.absent(),
                Value<String?> lastReceivedChangeId = const Value.absent(),
                Value<String?> lastSuccessAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorRecordsCompanion.insert(
                peerDeviceId: peerDeviceId,
                lastSentSequence: lastSentSequence,
                lastReceivedChangeId: lastReceivedChangeId,
                lastSuccessAt: lastSuccessAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncCursorRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$ChronicleDatabase,
      $SyncCursorRecordsTable,
      SyncCursorRecord,
      $$SyncCursorRecordsTableFilterComposer,
      $$SyncCursorRecordsTableOrderingComposer,
      $$SyncCursorRecordsTableAnnotationComposer,
      $$SyncCursorRecordsTableCreateCompanionBuilder,
      $$SyncCursorRecordsTableUpdateCompanionBuilder,
      (
        SyncCursorRecord,
        BaseReferences<
          _$ChronicleDatabase,
          $SyncCursorRecordsTable,
          SyncCursorRecord
        >,
      ),
      SyncCursorRecord,
      PrefetchHooks Function()
    >;

class $ChronicleDatabaseManager {
  final _$ChronicleDatabase _db;
  $ChronicleDatabaseManager(this._db);
  $$AppStateRecordsTableTableManager get appStateRecords =>
      $$AppStateRecordsTableTableManager(_db, _db.appStateRecords);
  $$ProjectRecordsTableTableManager get projectRecords =>
      $$ProjectRecordsTableTableManager(_db, _db.projectRecords);
  $$NoteRecordsTableTableManager get noteRecords =>
      $$NoteRecordsTableTableManager(_db, _db.noteRecords);
  $$NoteLinkRecordsTableTableManager get noteLinkRecords =>
      $$NoteLinkRecordsTableTableManager(_db, _db.noteLinkRecords);
  $$NoteVersionRecordsTableTableManager get noteVersionRecords =>
      $$NoteVersionRecordsTableTableManager(_db, _db.noteVersionRecords);
  $$TaskRecordsTableTableManager get taskRecords =>
      $$TaskRecordsTableTableManager(_db, _db.taskRecords);
  $$TimeEntryRecordsTableTableManager get timeEntryRecords =>
      $$TimeEntryRecordsTableTableManager(_db, _db.timeEntryRecords);
  $$DeviceIdentityRecordsTableTableManager get deviceIdentityRecords =>
      $$DeviceIdentityRecordsTableTableManager(_db, _db.deviceIdentityRecords);
  $$TrustedDeviceRecordsTableTableManager get trustedDeviceRecords =>
      $$TrustedDeviceRecordsTableTableManager(_db, _db.trustedDeviceRecords);
  $$ChangeRecordRecordsTableTableManager get changeRecordRecords =>
      $$ChangeRecordRecordsTableTableManager(_db, _db.changeRecordRecords);
  $$SyncCursorRecordsTableTableManager get syncCursorRecords =>
      $$SyncCursorRecordsTableTableManager(_db, _db.syncCursorRecords);
}
