// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PlansTable extends Plans with TableInfo<$PlansTable, Plan> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlansTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _areaMeta = const VerificationMeta('area');
  @override
  late final GeneratedColumn<String> area = GeneratedColumn<String>(
    'area',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentGroupIdMeta = const VerificationMeta(
    'currentGroupId',
  );
  @override
  late final GeneratedColumn<String> currentGroupId = GeneratedColumn<String>(
    'current_group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    area,
    currentGroupId,
    active,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plans';
  @override
  VerificationContext validateIntegrity(
    Insertable<Plan> instance, {
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
    if (data.containsKey('area')) {
      context.handle(
        _areaMeta,
        area.isAcceptableOrUnknown(data['area']!, _areaMeta),
      );
    } else if (isInserting) {
      context.missing(_areaMeta);
    }
    if (data.containsKey('current_group_id')) {
      context.handle(
        _currentGroupIdMeta,
        currentGroupId.isAcceptableOrUnknown(
          data['current_group_id']!,
          _currentGroupIdMeta,
        ),
      );
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
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
  Plan map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Plan(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      area: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}area'],
      )!,
      currentGroupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_group_id'],
      ),
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PlansTable createAlias(String alias) {
    return $PlansTable(attachedDatabase, alias);
  }
}

class Plan extends DataClass implements Insertable<Plan> {
  final String id;
  final String name;
  final String area;
  final String? currentGroupId;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Plan({
    required this.id,
    required this.name,
    required this.area,
    this.currentGroupId,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['area'] = Variable<String>(area);
    if (!nullToAbsent || currentGroupId != null) {
      map['current_group_id'] = Variable<String>(currentGroupId);
    }
    map['active'] = Variable<bool>(active);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PlansCompanion toCompanion(bool nullToAbsent) {
    return PlansCompanion(
      id: Value(id),
      name: Value(name),
      area: Value(area),
      currentGroupId: currentGroupId == null && nullToAbsent
          ? const Value.absent()
          : Value(currentGroupId),
      active: Value(active),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Plan.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Plan(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      area: serializer.fromJson<String>(json['area']),
      currentGroupId: serializer.fromJson<String?>(json['currentGroupId']),
      active: serializer.fromJson<bool>(json['active']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'area': serializer.toJson<String>(area),
      'currentGroupId': serializer.toJson<String?>(currentGroupId),
      'active': serializer.toJson<bool>(active),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Plan copyWith({
    String? id,
    String? name,
    String? area,
    Value<String?> currentGroupId = const Value.absent(),
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Plan(
    id: id ?? this.id,
    name: name ?? this.name,
    area: area ?? this.area,
    currentGroupId: currentGroupId.present
        ? currentGroupId.value
        : this.currentGroupId,
    active: active ?? this.active,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Plan copyWithCompanion(PlansCompanion data) {
    return Plan(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      area: data.area.present ? data.area.value : this.area,
      currentGroupId: data.currentGroupId.present
          ? data.currentGroupId.value
          : this.currentGroupId,
      active: data.active.present ? data.active.value : this.active,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Plan(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('area: $area, ')
          ..write('currentGroupId: $currentGroupId, ')
          ..write('active: $active, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, area, currentGroupId, active, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Plan &&
          other.id == this.id &&
          other.name == this.name &&
          other.area == this.area &&
          other.currentGroupId == this.currentGroupId &&
          other.active == this.active &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PlansCompanion extends UpdateCompanion<Plan> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> area;
  final Value<String?> currentGroupId;
  final Value<bool> active;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PlansCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.area = const Value.absent(),
    this.currentGroupId = const Value.absent(),
    this.active = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlansCompanion.insert({
    required String id,
    required String name,
    required String area,
    this.currentGroupId = const Value.absent(),
    this.active = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       area = Value(area),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Plan> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? area,
    Expression<String>? currentGroupId,
    Expression<bool>? active,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (area != null) 'area': area,
      if (currentGroupId != null) 'current_group_id': currentGroupId,
      if (active != null) 'active': active,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlansCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? area,
    Value<String?>? currentGroupId,
    Value<bool>? active,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PlansCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      area: area ?? this.area,
      currentGroupId: currentGroupId ?? this.currentGroupId,
      active: active ?? this.active,
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
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (area.present) {
      map['area'] = Variable<String>(area.value);
    }
    if (currentGroupId.present) {
      map['current_group_id'] = Variable<String>(currentGroupId.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlansCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('area: $area, ')
          ..write('currentGroupId: $currentGroupId, ')
          ..write('active: $active, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlanGroupsTable extends PlanGroups
    with TableInfo<$PlanGroupsTable, PlanGroup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlanGroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<String> planId = GeneratedColumn<String>(
    'plan_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES plans (id)',
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
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _orderModeMeta = const VerificationMeta(
    'orderMode',
  );
  @override
  late final GeneratedColumn<String> orderMode = GeneratedColumn<String>(
    'order_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unordered'),
  );
  static const VerificationMeta _anchorNameMeta = const VerificationMeta(
    'anchorName',
  );
  @override
  late final GeneratedColumn<String> anchorName = GeneratedColumn<String>(
    'anchor_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _anchorLatitudeMeta = const VerificationMeta(
    'anchorLatitude',
  );
  @override
  late final GeneratedColumn<double> anchorLatitude = GeneratedColumn<double>(
    'anchor_latitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _anchorLongitudeMeta = const VerificationMeta(
    'anchorLongitude',
  );
  @override
  late final GeneratedColumn<double> anchorLongitude = GeneratedColumn<double>(
    'anchor_longitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _anchorPointIdMeta = const VerificationMeta(
    'anchorPointId',
  );
  @override
  late final GeneratedColumn<String> anchorPointId = GeneratedColumn<String>(
    'anchor_point_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    planId,
    name,
    orderIndex,
    orderMode,
    anchorName,
    anchorLatitude,
    anchorLongitude,
    anchorPointId,
    note,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plan_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlanGroup> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('plan_id')) {
      context.handle(
        _planIdMeta,
        planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta),
      );
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    }
    if (data.containsKey('order_mode')) {
      context.handle(
        _orderModeMeta,
        orderMode.isAcceptableOrUnknown(data['order_mode']!, _orderModeMeta),
      );
    }
    if (data.containsKey('anchor_name')) {
      context.handle(
        _anchorNameMeta,
        anchorName.isAcceptableOrUnknown(data['anchor_name']!, _anchorNameMeta),
      );
    }
    if (data.containsKey('anchor_latitude')) {
      context.handle(
        _anchorLatitudeMeta,
        anchorLatitude.isAcceptableOrUnknown(
          data['anchor_latitude']!,
          _anchorLatitudeMeta,
        ),
      );
    }
    if (data.containsKey('anchor_longitude')) {
      context.handle(
        _anchorLongitudeMeta,
        anchorLongitude.isAcceptableOrUnknown(
          data['anchor_longitude']!,
          _anchorLongitudeMeta,
        ),
      );
    }
    if (data.containsKey('anchor_point_id')) {
      context.handle(
        _anchorPointIdMeta,
        anchorPointId.isAcceptableOrUnknown(
          data['anchor_point_id']!,
          _anchorPointIdMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
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
  PlanGroup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlanGroup(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      planId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      orderMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}order_mode'],
      )!,
      anchorName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}anchor_name'],
      ),
      anchorLatitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}anchor_latitude'],
      ),
      anchorLongitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}anchor_longitude'],
      ),
      anchorPointId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}anchor_point_id'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PlanGroupsTable createAlias(String alias) {
    return $PlanGroupsTable(attachedDatabase, alias);
  }
}

class PlanGroup extends DataClass implements Insertable<PlanGroup> {
  final String id;
  final String planId;
  final String name;
  final int orderIndex;
  final String orderMode;
  final String? anchorName;
  final double? anchorLatitude;
  final double? anchorLongitude;
  final String? anchorPointId;
  final String? note;
  final DateTime createdAt;
  const PlanGroup({
    required this.id,
    required this.planId,
    required this.name,
    required this.orderIndex,
    required this.orderMode,
    this.anchorName,
    this.anchorLatitude,
    this.anchorLongitude,
    this.anchorPointId,
    this.note,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['plan_id'] = Variable<String>(planId);
    map['name'] = Variable<String>(name);
    map['order_index'] = Variable<int>(orderIndex);
    map['order_mode'] = Variable<String>(orderMode);
    if (!nullToAbsent || anchorName != null) {
      map['anchor_name'] = Variable<String>(anchorName);
    }
    if (!nullToAbsent || anchorLatitude != null) {
      map['anchor_latitude'] = Variable<double>(anchorLatitude);
    }
    if (!nullToAbsent || anchorLongitude != null) {
      map['anchor_longitude'] = Variable<double>(anchorLongitude);
    }
    if (!nullToAbsent || anchorPointId != null) {
      map['anchor_point_id'] = Variable<String>(anchorPointId);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PlanGroupsCompanion toCompanion(bool nullToAbsent) {
    return PlanGroupsCompanion(
      id: Value(id),
      planId: Value(planId),
      name: Value(name),
      orderIndex: Value(orderIndex),
      orderMode: Value(orderMode),
      anchorName: anchorName == null && nullToAbsent
          ? const Value.absent()
          : Value(anchorName),
      anchorLatitude: anchorLatitude == null && nullToAbsent
          ? const Value.absent()
          : Value(anchorLatitude),
      anchorLongitude: anchorLongitude == null && nullToAbsent
          ? const Value.absent()
          : Value(anchorLongitude),
      anchorPointId: anchorPointId == null && nullToAbsent
          ? const Value.absent()
          : Value(anchorPointId),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
    );
  }

  factory PlanGroup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlanGroup(
      id: serializer.fromJson<String>(json['id']),
      planId: serializer.fromJson<String>(json['planId']),
      name: serializer.fromJson<String>(json['name']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      orderMode: serializer.fromJson<String>(json['orderMode']),
      anchorName: serializer.fromJson<String?>(json['anchorName']),
      anchorLatitude: serializer.fromJson<double?>(json['anchorLatitude']),
      anchorLongitude: serializer.fromJson<double?>(json['anchorLongitude']),
      anchorPointId: serializer.fromJson<String?>(json['anchorPointId']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'planId': serializer.toJson<String>(planId),
      'name': serializer.toJson<String>(name),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'orderMode': serializer.toJson<String>(orderMode),
      'anchorName': serializer.toJson<String?>(anchorName),
      'anchorLatitude': serializer.toJson<double?>(anchorLatitude),
      'anchorLongitude': serializer.toJson<double?>(anchorLongitude),
      'anchorPointId': serializer.toJson<String?>(anchorPointId),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PlanGroup copyWith({
    String? id,
    String? planId,
    String? name,
    int? orderIndex,
    String? orderMode,
    Value<String?> anchorName = const Value.absent(),
    Value<double?> anchorLatitude = const Value.absent(),
    Value<double?> anchorLongitude = const Value.absent(),
    Value<String?> anchorPointId = const Value.absent(),
    Value<String?> note = const Value.absent(),
    DateTime? createdAt,
  }) => PlanGroup(
    id: id ?? this.id,
    planId: planId ?? this.planId,
    name: name ?? this.name,
    orderIndex: orderIndex ?? this.orderIndex,
    orderMode: orderMode ?? this.orderMode,
    anchorName: anchorName.present ? anchorName.value : this.anchorName,
    anchorLatitude: anchorLatitude.present
        ? anchorLatitude.value
        : this.anchorLatitude,
    anchorLongitude: anchorLongitude.present
        ? anchorLongitude.value
        : this.anchorLongitude,
    anchorPointId: anchorPointId.present
        ? anchorPointId.value
        : this.anchorPointId,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
  );
  PlanGroup copyWithCompanion(PlanGroupsCompanion data) {
    return PlanGroup(
      id: data.id.present ? data.id.value : this.id,
      planId: data.planId.present ? data.planId.value : this.planId,
      name: data.name.present ? data.name.value : this.name,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      orderMode: data.orderMode.present ? data.orderMode.value : this.orderMode,
      anchorName: data.anchorName.present
          ? data.anchorName.value
          : this.anchorName,
      anchorLatitude: data.anchorLatitude.present
          ? data.anchorLatitude.value
          : this.anchorLatitude,
      anchorLongitude: data.anchorLongitude.present
          ? data.anchorLongitude.value
          : this.anchorLongitude,
      anchorPointId: data.anchorPointId.present
          ? data.anchorPointId.value
          : this.anchorPointId,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlanGroup(')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('name: $name, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('orderMode: $orderMode, ')
          ..write('anchorName: $anchorName, ')
          ..write('anchorLatitude: $anchorLatitude, ')
          ..write('anchorLongitude: $anchorLongitude, ')
          ..write('anchorPointId: $anchorPointId, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    planId,
    name,
    orderIndex,
    orderMode,
    anchorName,
    anchorLatitude,
    anchorLongitude,
    anchorPointId,
    note,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlanGroup &&
          other.id == this.id &&
          other.planId == this.planId &&
          other.name == this.name &&
          other.orderIndex == this.orderIndex &&
          other.orderMode == this.orderMode &&
          other.anchorName == this.anchorName &&
          other.anchorLatitude == this.anchorLatitude &&
          other.anchorLongitude == this.anchorLongitude &&
          other.anchorPointId == this.anchorPointId &&
          other.note == this.note &&
          other.createdAt == this.createdAt);
}

class PlanGroupsCompanion extends UpdateCompanion<PlanGroup> {
  final Value<String> id;
  final Value<String> planId;
  final Value<String> name;
  final Value<int> orderIndex;
  final Value<String> orderMode;
  final Value<String?> anchorName;
  final Value<double?> anchorLatitude;
  final Value<double?> anchorLongitude;
  final Value<String?> anchorPointId;
  final Value<String?> note;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PlanGroupsCompanion({
    this.id = const Value.absent(),
    this.planId = const Value.absent(),
    this.name = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.orderMode = const Value.absent(),
    this.anchorName = const Value.absent(),
    this.anchorLatitude = const Value.absent(),
    this.anchorLongitude = const Value.absent(),
    this.anchorPointId = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlanGroupsCompanion.insert({
    required String id,
    required String planId,
    required String name,
    this.orderIndex = const Value.absent(),
    this.orderMode = const Value.absent(),
    this.anchorName = const Value.absent(),
    this.anchorLatitude = const Value.absent(),
    this.anchorLongitude = const Value.absent(),
    this.anchorPointId = const Value.absent(),
    this.note = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       planId = Value(planId),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<PlanGroup> custom({
    Expression<String>? id,
    Expression<String>? planId,
    Expression<String>? name,
    Expression<int>? orderIndex,
    Expression<String>? orderMode,
    Expression<String>? anchorName,
    Expression<double>? anchorLatitude,
    Expression<double>? anchorLongitude,
    Expression<String>? anchorPointId,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (planId != null) 'plan_id': planId,
      if (name != null) 'name': name,
      if (orderIndex != null) 'order_index': orderIndex,
      if (orderMode != null) 'order_mode': orderMode,
      if (anchorName != null) 'anchor_name': anchorName,
      if (anchorLatitude != null) 'anchor_latitude': anchorLatitude,
      if (anchorLongitude != null) 'anchor_longitude': anchorLongitude,
      if (anchorPointId != null) 'anchor_point_id': anchorPointId,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlanGroupsCompanion copyWith({
    Value<String>? id,
    Value<String>? planId,
    Value<String>? name,
    Value<int>? orderIndex,
    Value<String>? orderMode,
    Value<String?>? anchorName,
    Value<double?>? anchorLatitude,
    Value<double?>? anchorLongitude,
    Value<String?>? anchorPointId,
    Value<String?>? note,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return PlanGroupsCompanion(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      name: name ?? this.name,
      orderIndex: orderIndex ?? this.orderIndex,
      orderMode: orderMode ?? this.orderMode,
      anchorName: anchorName ?? this.anchorName,
      anchorLatitude: anchorLatitude ?? this.anchorLatitude,
      anchorLongitude: anchorLongitude ?? this.anchorLongitude,
      anchorPointId: anchorPointId ?? this.anchorPointId,
      note: note ?? this.note,
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
    if (planId.present) {
      map['plan_id'] = Variable<String>(planId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (orderMode.present) {
      map['order_mode'] = Variable<String>(orderMode.value);
    }
    if (anchorName.present) {
      map['anchor_name'] = Variable<String>(anchorName.value);
    }
    if (anchorLatitude.present) {
      map['anchor_latitude'] = Variable<double>(anchorLatitude.value);
    }
    if (anchorLongitude.present) {
      map['anchor_longitude'] = Variable<double>(anchorLongitude.value);
    }
    if (anchorPointId.present) {
      map['anchor_point_id'] = Variable<String>(anchorPointId.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlanGroupsCompanion(')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('name: $name, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('orderMode: $orderMode, ')
          ..write('anchorName: $anchorName, ')
          ..write('anchorLatitude: $anchorLatitude, ')
          ..write('anchorLongitude: $anchorLongitude, ')
          ..write('anchorPointId: $anchorPointId, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorksTable extends Works with TableInfo<$WorksTable, Work> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<String> planId = GeneratedColumn<String>(
    'plan_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES plans (id)',
    ),
  );
  static const VerificationMeta _bangumiIdMeta = const VerificationMeta(
    'bangumiId',
  );
  @override
  late final GeneratedColumn<int> bangumiId = GeneratedColumn<int>(
    'bangumi_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
  static const VerificationMeta _subtitleMeta = const VerificationMeta(
    'subtitle',
  );
  @override
  late final GeneratedColumn<String> subtitle = GeneratedColumn<String>(
    'subtitle',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cityMeta = const VerificationMeta('city');
  @override
  late final GeneratedColumn<String> city = GeneratedColumn<String>(
    'city',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    planId,
    bangumiId,
    title,
    subtitle,
    city,
    source,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'works';
  @override
  VerificationContext validateIntegrity(
    Insertable<Work> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('plan_id')) {
      context.handle(
        _planIdMeta,
        planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta),
      );
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    if (data.containsKey('bangumi_id')) {
      context.handle(
        _bangumiIdMeta,
        bangumiId.isAcceptableOrUnknown(data['bangumi_id']!, _bangumiIdMeta),
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
    if (data.containsKey('subtitle')) {
      context.handle(
        _subtitleMeta,
        subtitle.isAcceptableOrUnknown(data['subtitle']!, _subtitleMeta),
      );
    } else if (isInserting) {
      context.missing(_subtitleMeta);
    }
    if (data.containsKey('city')) {
      context.handle(
        _cityMeta,
        city.isAcceptableOrUnknown(data['city']!, _cityMeta),
      );
    } else if (isInserting) {
      context.missing(_cityMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Work map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Work(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      planId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_id'],
      )!,
      bangumiId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bangumi_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      subtitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subtitle'],
      )!,
      city: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}city'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
    );
  }

  @override
  $WorksTable createAlias(String alias) {
    return $WorksTable(attachedDatabase, alias);
  }
}

class Work extends DataClass implements Insertable<Work> {
  final String id;
  final String planId;
  final int? bangumiId;
  final String title;
  final String subtitle;
  final String city;
  final String source;
  const Work({
    required this.id,
    required this.planId,
    this.bangumiId,
    required this.title,
    required this.subtitle,
    required this.city,
    required this.source,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['plan_id'] = Variable<String>(planId);
    if (!nullToAbsent || bangumiId != null) {
      map['bangumi_id'] = Variable<int>(bangumiId);
    }
    map['title'] = Variable<String>(title);
    map['subtitle'] = Variable<String>(subtitle);
    map['city'] = Variable<String>(city);
    map['source'] = Variable<String>(source);
    return map;
  }

  WorksCompanion toCompanion(bool nullToAbsent) {
    return WorksCompanion(
      id: Value(id),
      planId: Value(planId),
      bangumiId: bangumiId == null && nullToAbsent
          ? const Value.absent()
          : Value(bangumiId),
      title: Value(title),
      subtitle: Value(subtitle),
      city: Value(city),
      source: Value(source),
    );
  }

  factory Work.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Work(
      id: serializer.fromJson<String>(json['id']),
      planId: serializer.fromJson<String>(json['planId']),
      bangumiId: serializer.fromJson<int?>(json['bangumiId']),
      title: serializer.fromJson<String>(json['title']),
      subtitle: serializer.fromJson<String>(json['subtitle']),
      city: serializer.fromJson<String>(json['city']),
      source: serializer.fromJson<String>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'planId': serializer.toJson<String>(planId),
      'bangumiId': serializer.toJson<int?>(bangumiId),
      'title': serializer.toJson<String>(title),
      'subtitle': serializer.toJson<String>(subtitle),
      'city': serializer.toJson<String>(city),
      'source': serializer.toJson<String>(source),
    };
  }

  Work copyWith({
    String? id,
    String? planId,
    Value<int?> bangumiId = const Value.absent(),
    String? title,
    String? subtitle,
    String? city,
    String? source,
  }) => Work(
    id: id ?? this.id,
    planId: planId ?? this.planId,
    bangumiId: bangumiId.present ? bangumiId.value : this.bangumiId,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    city: city ?? this.city,
    source: source ?? this.source,
  );
  Work copyWithCompanion(WorksCompanion data) {
    return Work(
      id: data.id.present ? data.id.value : this.id,
      planId: data.planId.present ? data.planId.value : this.planId,
      bangumiId: data.bangumiId.present ? data.bangumiId.value : this.bangumiId,
      title: data.title.present ? data.title.value : this.title,
      subtitle: data.subtitle.present ? data.subtitle.value : this.subtitle,
      city: data.city.present ? data.city.value : this.city,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Work(')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('bangumiId: $bangumiId, ')
          ..write('title: $title, ')
          ..write('subtitle: $subtitle, ')
          ..write('city: $city, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, planId, bangumiId, title, subtitle, city, source);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Work &&
          other.id == this.id &&
          other.planId == this.planId &&
          other.bangumiId == this.bangumiId &&
          other.title == this.title &&
          other.subtitle == this.subtitle &&
          other.city == this.city &&
          other.source == this.source);
}

class WorksCompanion extends UpdateCompanion<Work> {
  final Value<String> id;
  final Value<String> planId;
  final Value<int?> bangumiId;
  final Value<String> title;
  final Value<String> subtitle;
  final Value<String> city;
  final Value<String> source;
  final Value<int> rowid;
  const WorksCompanion({
    this.id = const Value.absent(),
    this.planId = const Value.absent(),
    this.bangumiId = const Value.absent(),
    this.title = const Value.absent(),
    this.subtitle = const Value.absent(),
    this.city = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorksCompanion.insert({
    required String id,
    required String planId,
    this.bangumiId = const Value.absent(),
    required String title,
    required String subtitle,
    required String city,
    required String source,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       planId = Value(planId),
       title = Value(title),
       subtitle = Value(subtitle),
       city = Value(city),
       source = Value(source);
  static Insertable<Work> custom({
    Expression<String>? id,
    Expression<String>? planId,
    Expression<int>? bangumiId,
    Expression<String>? title,
    Expression<String>? subtitle,
    Expression<String>? city,
    Expression<String>? source,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (planId != null) 'plan_id': planId,
      if (bangumiId != null) 'bangumi_id': bangumiId,
      if (title != null) 'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      if (city != null) 'city': city,
      if (source != null) 'source': source,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorksCompanion copyWith({
    Value<String>? id,
    Value<String>? planId,
    Value<int?>? bangumiId,
    Value<String>? title,
    Value<String>? subtitle,
    Value<String>? city,
    Value<String>? source,
    Value<int>? rowid,
  }) {
    return WorksCompanion(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      bangumiId: bangumiId ?? this.bangumiId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      city: city ?? this.city,
      source: source ?? this.source,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<String>(planId.value);
    }
    if (bangumiId.present) {
      map['bangumi_id'] = Variable<int>(bangumiId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (subtitle.present) {
      map['subtitle'] = Variable<String>(subtitle.value);
    }
    if (city.present) {
      map['city'] = Variable<String>(city.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorksCompanion(')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('bangumiId: $bangumiId, ')
          ..write('title: $title, ')
          ..write('subtitle: $subtitle, ')
          ..write('city: $city, ')
          ..write('source: $source, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PointsTable extends Points with TableInfo<$PointsTable, Point> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<String> planId = GeneratedColumn<String>(
    'plan_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES plans (id)',
    ),
  );
  static const VerificationMeta _workIdMeta = const VerificationMeta('workId');
  @override
  late final GeneratedColumn<String> workId = GeneratedColumn<String>(
    'work_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES works (id)',
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
  static const VerificationMeta _subtitleMeta = const VerificationMeta(
    'subtitle',
  );
  @override
  late final GeneratedColumn<String> subtitle = GeneratedColumn<String>(
    'subtitle',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _episodeLabelMeta = const VerificationMeta(
    'episodeLabel',
  );
  @override
  late final GeneratedColumn<String> episodeLabel = GeneratedColumn<String>(
    'episode_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _referenceLabelMeta = const VerificationMeta(
    'referenceLabel',
  );
  @override
  late final GeneratedColumn<String> referenceLabel = GeneratedColumn<String>(
    'reference_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _referenceImageUrlMeta = const VerificationMeta(
    'referenceImageUrl',
  );
  @override
  late final GeneratedColumn<String> referenceImageUrl =
      GeneratedColumn<String>(
        'reference_image_url',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _referenceThumbnailPathMeta =
      const VerificationMeta('referenceThumbnailPath');
  @override
  late final GeneratedColumn<String> referenceThumbnailPath =
      GeneratedColumn<String>(
        'reference_thumbnail_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _referenceFullImagePathMeta =
      const VerificationMeta('referenceFullImagePath');
  @override
  late final GeneratedColumn<String> referenceFullImagePath =
      GeneratedColumn<String>(
        'reference_full_image_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES plan_groups (id)',
    ),
  );
  static const VerificationMeta _groupOrderIndexMeta = const VerificationMeta(
    'groupOrderIndex',
  );
  @override
  late final GeneratedColumn<int> groupOrderIndex = GeneratedColumn<int>(
    'group_order_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
  static const VerificationMeta _isCurrentMeta = const VerificationMeta(
    'isCurrent',
  );
  @override
  late final GeneratedColumn<bool> isCurrent = GeneratedColumn<bool>(
    'is_current',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_current" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    planId,
    workId,
    name,
    subtitle,
    latitude,
    longitude,
    episodeLabel,
    referenceLabel,
    source,
    sourceId,
    referenceImageUrl,
    referenceThumbnailPath,
    referenceFullImagePath,
    sourceUrl,
    note,
    groupId,
    groupOrderIndex,
    sortOrder,
    isCurrent,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'points';
  @override
  VerificationContext validateIntegrity(
    Insertable<Point> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('plan_id')) {
      context.handle(
        _planIdMeta,
        planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta),
      );
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    if (data.containsKey('work_id')) {
      context.handle(
        _workIdMeta,
        workId.isAcceptableOrUnknown(data['work_id']!, _workIdMeta),
      );
    } else if (isInserting) {
      context.missing(_workIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('subtitle')) {
      context.handle(
        _subtitleMeta,
        subtitle.isAcceptableOrUnknown(data['subtitle']!, _subtitleMeta),
      );
    } else if (isInserting) {
      context.missing(_subtitleMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('episode_label')) {
      context.handle(
        _episodeLabelMeta,
        episodeLabel.isAcceptableOrUnknown(
          data['episode_label']!,
          _episodeLabelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_episodeLabelMeta);
    }
    if (data.containsKey('reference_label')) {
      context.handle(
        _referenceLabelMeta,
        referenceLabel.isAcceptableOrUnknown(
          data['reference_label']!,
          _referenceLabelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_referenceLabelMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    }
    if (data.containsKey('reference_image_url')) {
      context.handle(
        _referenceImageUrlMeta,
        referenceImageUrl.isAcceptableOrUnknown(
          data['reference_image_url']!,
          _referenceImageUrlMeta,
        ),
      );
    }
    if (data.containsKey('reference_thumbnail_path')) {
      context.handle(
        _referenceThumbnailPathMeta,
        referenceThumbnailPath.isAcceptableOrUnknown(
          data['reference_thumbnail_path']!,
          _referenceThumbnailPathMeta,
        ),
      );
    }
    if (data.containsKey('reference_full_image_path')) {
      context.handle(
        _referenceFullImagePathMeta,
        referenceFullImagePath.isAcceptableOrUnknown(
          data['reference_full_image_path']!,
          _referenceFullImagePathMeta,
        ),
      );
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    if (data.containsKey('group_order_index')) {
      context.handle(
        _groupOrderIndexMeta,
        groupOrderIndex.isAcceptableOrUnknown(
          data['group_order_index']!,
          _groupOrderIndexMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('is_current')) {
      context.handle(
        _isCurrentMeta,
        isCurrent.isAcceptableOrUnknown(data['is_current']!, _isCurrentMeta),
      );
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Point map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Point(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      planId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_id'],
      )!,
      workId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}work_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      subtitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subtitle'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      )!,
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      )!,
      episodeLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode_label'],
      )!,
      referenceLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference_label'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      ),
      referenceImageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference_image_url'],
      ),
      referenceThumbnailPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference_thumbnail_path'],
      ),
      referenceFullImagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference_full_image_path'],
      ),
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      ),
      groupOrderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}group_order_index'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      isCurrent: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_current'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $PointsTable createAlias(String alias) {
    return $PointsTable(attachedDatabase, alias);
  }
}

class Point extends DataClass implements Insertable<Point> {
  final String id;
  final String planId;
  final String workId;
  final String name;
  final String subtitle;
  final double latitude;
  final double longitude;
  final String episodeLabel;
  final String referenceLabel;
  final String source;
  final String? sourceId;
  final String? referenceImageUrl;
  final String? referenceThumbnailPath;
  final String? referenceFullImagePath;
  final String? sourceUrl;
  final String? note;
  final String? groupId;
  final int? groupOrderIndex;
  final int sortOrder;
  final bool isCurrent;
  final DateTime? completedAt;
  const Point({
    required this.id,
    required this.planId,
    required this.workId,
    required this.name,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
    required this.episodeLabel,
    required this.referenceLabel,
    required this.source,
    this.sourceId,
    this.referenceImageUrl,
    this.referenceThumbnailPath,
    this.referenceFullImagePath,
    this.sourceUrl,
    this.note,
    this.groupId,
    this.groupOrderIndex,
    required this.sortOrder,
    required this.isCurrent,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['plan_id'] = Variable<String>(planId);
    map['work_id'] = Variable<String>(workId);
    map['name'] = Variable<String>(name);
    map['subtitle'] = Variable<String>(subtitle);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    map['episode_label'] = Variable<String>(episodeLabel);
    map['reference_label'] = Variable<String>(referenceLabel);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || sourceId != null) {
      map['source_id'] = Variable<String>(sourceId);
    }
    if (!nullToAbsent || referenceImageUrl != null) {
      map['reference_image_url'] = Variable<String>(referenceImageUrl);
    }
    if (!nullToAbsent || referenceThumbnailPath != null) {
      map['reference_thumbnail_path'] = Variable<String>(
        referenceThumbnailPath,
      );
    }
    if (!nullToAbsent || referenceFullImagePath != null) {
      map['reference_full_image_path'] = Variable<String>(
        referenceFullImagePath,
      );
    }
    if (!nullToAbsent || sourceUrl != null) {
      map['source_url'] = Variable<String>(sourceUrl);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<String>(groupId);
    }
    if (!nullToAbsent || groupOrderIndex != null) {
      map['group_order_index'] = Variable<int>(groupOrderIndex);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_current'] = Variable<bool>(isCurrent);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  PointsCompanion toCompanion(bool nullToAbsent) {
    return PointsCompanion(
      id: Value(id),
      planId: Value(planId),
      workId: Value(workId),
      name: Value(name),
      subtitle: Value(subtitle),
      latitude: Value(latitude),
      longitude: Value(longitude),
      episodeLabel: Value(episodeLabel),
      referenceLabel: Value(referenceLabel),
      source: Value(source),
      sourceId: sourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceId),
      referenceImageUrl: referenceImageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceImageUrl),
      referenceThumbnailPath: referenceThumbnailPath == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceThumbnailPath),
      referenceFullImagePath: referenceFullImagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceFullImagePath),
      sourceUrl: sourceUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceUrl),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      groupOrderIndex: groupOrderIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(groupOrderIndex),
      sortOrder: Value(sortOrder),
      isCurrent: Value(isCurrent),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory Point.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Point(
      id: serializer.fromJson<String>(json['id']),
      planId: serializer.fromJson<String>(json['planId']),
      workId: serializer.fromJson<String>(json['workId']),
      name: serializer.fromJson<String>(json['name']),
      subtitle: serializer.fromJson<String>(json['subtitle']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      episodeLabel: serializer.fromJson<String>(json['episodeLabel']),
      referenceLabel: serializer.fromJson<String>(json['referenceLabel']),
      source: serializer.fromJson<String>(json['source']),
      sourceId: serializer.fromJson<String?>(json['sourceId']),
      referenceImageUrl: serializer.fromJson<String?>(
        json['referenceImageUrl'],
      ),
      referenceThumbnailPath: serializer.fromJson<String?>(
        json['referenceThumbnailPath'],
      ),
      referenceFullImagePath: serializer.fromJson<String?>(
        json['referenceFullImagePath'],
      ),
      sourceUrl: serializer.fromJson<String?>(json['sourceUrl']),
      note: serializer.fromJson<String?>(json['note']),
      groupId: serializer.fromJson<String?>(json['groupId']),
      groupOrderIndex: serializer.fromJson<int?>(json['groupOrderIndex']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      isCurrent: serializer.fromJson<bool>(json['isCurrent']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'planId': serializer.toJson<String>(planId),
      'workId': serializer.toJson<String>(workId),
      'name': serializer.toJson<String>(name),
      'subtitle': serializer.toJson<String>(subtitle),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'episodeLabel': serializer.toJson<String>(episodeLabel),
      'referenceLabel': serializer.toJson<String>(referenceLabel),
      'source': serializer.toJson<String>(source),
      'sourceId': serializer.toJson<String?>(sourceId),
      'referenceImageUrl': serializer.toJson<String?>(referenceImageUrl),
      'referenceThumbnailPath': serializer.toJson<String?>(
        referenceThumbnailPath,
      ),
      'referenceFullImagePath': serializer.toJson<String?>(
        referenceFullImagePath,
      ),
      'sourceUrl': serializer.toJson<String?>(sourceUrl),
      'note': serializer.toJson<String?>(note),
      'groupId': serializer.toJson<String?>(groupId),
      'groupOrderIndex': serializer.toJson<int?>(groupOrderIndex),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'isCurrent': serializer.toJson<bool>(isCurrent),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  Point copyWith({
    String? id,
    String? planId,
    String? workId,
    String? name,
    String? subtitle,
    double? latitude,
    double? longitude,
    String? episodeLabel,
    String? referenceLabel,
    String? source,
    Value<String?> sourceId = const Value.absent(),
    Value<String?> referenceImageUrl = const Value.absent(),
    Value<String?> referenceThumbnailPath = const Value.absent(),
    Value<String?> referenceFullImagePath = const Value.absent(),
    Value<String?> sourceUrl = const Value.absent(),
    Value<String?> note = const Value.absent(),
    Value<String?> groupId = const Value.absent(),
    Value<int?> groupOrderIndex = const Value.absent(),
    int? sortOrder,
    bool? isCurrent,
    Value<DateTime?> completedAt = const Value.absent(),
  }) => Point(
    id: id ?? this.id,
    planId: planId ?? this.planId,
    workId: workId ?? this.workId,
    name: name ?? this.name,
    subtitle: subtitle ?? this.subtitle,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    episodeLabel: episodeLabel ?? this.episodeLabel,
    referenceLabel: referenceLabel ?? this.referenceLabel,
    source: source ?? this.source,
    sourceId: sourceId.present ? sourceId.value : this.sourceId,
    referenceImageUrl: referenceImageUrl.present
        ? referenceImageUrl.value
        : this.referenceImageUrl,
    referenceThumbnailPath: referenceThumbnailPath.present
        ? referenceThumbnailPath.value
        : this.referenceThumbnailPath,
    referenceFullImagePath: referenceFullImagePath.present
        ? referenceFullImagePath.value
        : this.referenceFullImagePath,
    sourceUrl: sourceUrl.present ? sourceUrl.value : this.sourceUrl,
    note: note.present ? note.value : this.note,
    groupId: groupId.present ? groupId.value : this.groupId,
    groupOrderIndex: groupOrderIndex.present
        ? groupOrderIndex.value
        : this.groupOrderIndex,
    sortOrder: sortOrder ?? this.sortOrder,
    isCurrent: isCurrent ?? this.isCurrent,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  Point copyWithCompanion(PointsCompanion data) {
    return Point(
      id: data.id.present ? data.id.value : this.id,
      planId: data.planId.present ? data.planId.value : this.planId,
      workId: data.workId.present ? data.workId.value : this.workId,
      name: data.name.present ? data.name.value : this.name,
      subtitle: data.subtitle.present ? data.subtitle.value : this.subtitle,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      episodeLabel: data.episodeLabel.present
          ? data.episodeLabel.value
          : this.episodeLabel,
      referenceLabel: data.referenceLabel.present
          ? data.referenceLabel.value
          : this.referenceLabel,
      source: data.source.present ? data.source.value : this.source,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      referenceImageUrl: data.referenceImageUrl.present
          ? data.referenceImageUrl.value
          : this.referenceImageUrl,
      referenceThumbnailPath: data.referenceThumbnailPath.present
          ? data.referenceThumbnailPath.value
          : this.referenceThumbnailPath,
      referenceFullImagePath: data.referenceFullImagePath.present
          ? data.referenceFullImagePath.value
          : this.referenceFullImagePath,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      note: data.note.present ? data.note.value : this.note,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      groupOrderIndex: data.groupOrderIndex.present
          ? data.groupOrderIndex.value
          : this.groupOrderIndex,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isCurrent: data.isCurrent.present ? data.isCurrent.value : this.isCurrent,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Point(')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('workId: $workId, ')
          ..write('name: $name, ')
          ..write('subtitle: $subtitle, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('episodeLabel: $episodeLabel, ')
          ..write('referenceLabel: $referenceLabel, ')
          ..write('source: $source, ')
          ..write('sourceId: $sourceId, ')
          ..write('referenceImageUrl: $referenceImageUrl, ')
          ..write('referenceThumbnailPath: $referenceThumbnailPath, ')
          ..write('referenceFullImagePath: $referenceFullImagePath, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('note: $note, ')
          ..write('groupId: $groupId, ')
          ..write('groupOrderIndex: $groupOrderIndex, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isCurrent: $isCurrent, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    planId,
    workId,
    name,
    subtitle,
    latitude,
    longitude,
    episodeLabel,
    referenceLabel,
    source,
    sourceId,
    referenceImageUrl,
    referenceThumbnailPath,
    referenceFullImagePath,
    sourceUrl,
    note,
    groupId,
    groupOrderIndex,
    sortOrder,
    isCurrent,
    completedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Point &&
          other.id == this.id &&
          other.planId == this.planId &&
          other.workId == this.workId &&
          other.name == this.name &&
          other.subtitle == this.subtitle &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.episodeLabel == this.episodeLabel &&
          other.referenceLabel == this.referenceLabel &&
          other.source == this.source &&
          other.sourceId == this.sourceId &&
          other.referenceImageUrl == this.referenceImageUrl &&
          other.referenceThumbnailPath == this.referenceThumbnailPath &&
          other.referenceFullImagePath == this.referenceFullImagePath &&
          other.sourceUrl == this.sourceUrl &&
          other.note == this.note &&
          other.groupId == this.groupId &&
          other.groupOrderIndex == this.groupOrderIndex &&
          other.sortOrder == this.sortOrder &&
          other.isCurrent == this.isCurrent &&
          other.completedAt == this.completedAt);
}

class PointsCompanion extends UpdateCompanion<Point> {
  final Value<String> id;
  final Value<String> planId;
  final Value<String> workId;
  final Value<String> name;
  final Value<String> subtitle;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<String> episodeLabel;
  final Value<String> referenceLabel;
  final Value<String> source;
  final Value<String?> sourceId;
  final Value<String?> referenceImageUrl;
  final Value<String?> referenceThumbnailPath;
  final Value<String?> referenceFullImagePath;
  final Value<String?> sourceUrl;
  final Value<String?> note;
  final Value<String?> groupId;
  final Value<int?> groupOrderIndex;
  final Value<int> sortOrder;
  final Value<bool> isCurrent;
  final Value<DateTime?> completedAt;
  final Value<int> rowid;
  const PointsCompanion({
    this.id = const Value.absent(),
    this.planId = const Value.absent(),
    this.workId = const Value.absent(),
    this.name = const Value.absent(),
    this.subtitle = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.episodeLabel = const Value.absent(),
    this.referenceLabel = const Value.absent(),
    this.source = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.referenceImageUrl = const Value.absent(),
    this.referenceThumbnailPath = const Value.absent(),
    this.referenceFullImagePath = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.note = const Value.absent(),
    this.groupId = const Value.absent(),
    this.groupOrderIndex = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isCurrent = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PointsCompanion.insert({
    required String id,
    required String planId,
    required String workId,
    required String name,
    required String subtitle,
    required double latitude,
    required double longitude,
    required String episodeLabel,
    required String referenceLabel,
    required String source,
    this.sourceId = const Value.absent(),
    this.referenceImageUrl = const Value.absent(),
    this.referenceThumbnailPath = const Value.absent(),
    this.referenceFullImagePath = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.note = const Value.absent(),
    this.groupId = const Value.absent(),
    this.groupOrderIndex = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isCurrent = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       planId = Value(planId),
       workId = Value(workId),
       name = Value(name),
       subtitle = Value(subtitle),
       latitude = Value(latitude),
       longitude = Value(longitude),
       episodeLabel = Value(episodeLabel),
       referenceLabel = Value(referenceLabel),
       source = Value(source);
  static Insertable<Point> custom({
    Expression<String>? id,
    Expression<String>? planId,
    Expression<String>? workId,
    Expression<String>? name,
    Expression<String>? subtitle,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? episodeLabel,
    Expression<String>? referenceLabel,
    Expression<String>? source,
    Expression<String>? sourceId,
    Expression<String>? referenceImageUrl,
    Expression<String>? referenceThumbnailPath,
    Expression<String>? referenceFullImagePath,
    Expression<String>? sourceUrl,
    Expression<String>? note,
    Expression<String>? groupId,
    Expression<int>? groupOrderIndex,
    Expression<int>? sortOrder,
    Expression<bool>? isCurrent,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (planId != null) 'plan_id': planId,
      if (workId != null) 'work_id': workId,
      if (name != null) 'name': name,
      if (subtitle != null) 'subtitle': subtitle,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (episodeLabel != null) 'episode_label': episodeLabel,
      if (referenceLabel != null) 'reference_label': referenceLabel,
      if (source != null) 'source': source,
      if (sourceId != null) 'source_id': sourceId,
      if (referenceImageUrl != null) 'reference_image_url': referenceImageUrl,
      if (referenceThumbnailPath != null)
        'reference_thumbnail_path': referenceThumbnailPath,
      if (referenceFullImagePath != null)
        'reference_full_image_path': referenceFullImagePath,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (note != null) 'note': note,
      if (groupId != null) 'group_id': groupId,
      if (groupOrderIndex != null) 'group_order_index': groupOrderIndex,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isCurrent != null) 'is_current': isCurrent,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PointsCompanion copyWith({
    Value<String>? id,
    Value<String>? planId,
    Value<String>? workId,
    Value<String>? name,
    Value<String>? subtitle,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<String>? episodeLabel,
    Value<String>? referenceLabel,
    Value<String>? source,
    Value<String?>? sourceId,
    Value<String?>? referenceImageUrl,
    Value<String?>? referenceThumbnailPath,
    Value<String?>? referenceFullImagePath,
    Value<String?>? sourceUrl,
    Value<String?>? note,
    Value<String?>? groupId,
    Value<int?>? groupOrderIndex,
    Value<int>? sortOrder,
    Value<bool>? isCurrent,
    Value<DateTime?>? completedAt,
    Value<int>? rowid,
  }) {
    return PointsCompanion(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      workId: workId ?? this.workId,
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      episodeLabel: episodeLabel ?? this.episodeLabel,
      referenceLabel: referenceLabel ?? this.referenceLabel,
      source: source ?? this.source,
      sourceId: sourceId ?? this.sourceId,
      referenceImageUrl: referenceImageUrl ?? this.referenceImageUrl,
      referenceThumbnailPath:
          referenceThumbnailPath ?? this.referenceThumbnailPath,
      referenceFullImagePath:
          referenceFullImagePath ?? this.referenceFullImagePath,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      note: note ?? this.note,
      groupId: groupId ?? this.groupId,
      groupOrderIndex: groupOrderIndex ?? this.groupOrderIndex,
      sortOrder: sortOrder ?? this.sortOrder,
      isCurrent: isCurrent ?? this.isCurrent,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<String>(planId.value);
    }
    if (workId.present) {
      map['work_id'] = Variable<String>(workId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (subtitle.present) {
      map['subtitle'] = Variable<String>(subtitle.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (episodeLabel.present) {
      map['episode_label'] = Variable<String>(episodeLabel.value);
    }
    if (referenceLabel.present) {
      map['reference_label'] = Variable<String>(referenceLabel.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (referenceImageUrl.present) {
      map['reference_image_url'] = Variable<String>(referenceImageUrl.value);
    }
    if (referenceThumbnailPath.present) {
      map['reference_thumbnail_path'] = Variable<String>(
        referenceThumbnailPath.value,
      );
    }
    if (referenceFullImagePath.present) {
      map['reference_full_image_path'] = Variable<String>(
        referenceFullImagePath.value,
      );
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (groupOrderIndex.present) {
      map['group_order_index'] = Variable<int>(groupOrderIndex.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isCurrent.present) {
      map['is_current'] = Variable<bool>(isCurrent.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PointsCompanion(')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('workId: $workId, ')
          ..write('name: $name, ')
          ..write('subtitle: $subtitle, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('episodeLabel: $episodeLabel, ')
          ..write('referenceLabel: $referenceLabel, ')
          ..write('source: $source, ')
          ..write('sourceId: $sourceId, ')
          ..write('referenceImageUrl: $referenceImageUrl, ')
          ..write('referenceThumbnailPath: $referenceThumbnailPath, ')
          ..write('referenceFullImagePath: $referenceFullImagePath, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('note: $note, ')
          ..write('groupId: $groupId, ')
          ..write('groupOrderIndex: $groupOrderIndex, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isCurrent: $isCurrent, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VisitRecordsTable extends VisitRecords
    with TableInfo<$VisitRecordsTable, VisitRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VisitRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<String> planId = GeneratedColumn<String>(
    'plan_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pointIdMeta = const VerificationMeta(
    'pointId',
  );
  @override
  late final GeneratedColumn<String> pointId = GeneratedColumn<String>(
    'point_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _workIdMeta = const VerificationMeta('workId');
  @override
  late final GeneratedColumn<String> workId = GeneratedColumn<String>(
    'work_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _workTitleMeta = const VerificationMeta(
    'workTitle',
  );
  @override
  late final GeneratedColumn<String> workTitle = GeneratedColumn<String>(
    'work_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _workSubtitleMeta = const VerificationMeta(
    'workSubtitle',
  );
  @override
  late final GeneratedColumn<String> workSubtitle = GeneratedColumn<String>(
    'work_subtitle',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pointNameMeta = const VerificationMeta(
    'pointName',
  );
  @override
  late final GeneratedColumn<String> pointName = GeneratedColumn<String>(
    'point_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pointSubtitleMeta = const VerificationMeta(
    'pointSubtitle',
  );
  @override
  late final GeneratedColumn<String> pointSubtitle = GeneratedColumn<String>(
    'point_subtitle',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _photoPathMeta = const VerificationMeta(
    'photoPath',
  );
  @override
  late final GeneratedColumn<String> photoPath = GeneratedColumn<String>(
    'photo_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originalPhotoPathMeta = const VerificationMeta(
    'originalPhotoPath',
  );
  @override
  late final GeneratedColumn<String> originalPhotoPath =
      GeneratedColumn<String>(
        'original_photo_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _gradedPhotoPathMeta = const VerificationMeta(
    'gradedPhotoPath',
  );
  @override
  late final GeneratedColumn<String> gradedPhotoPath = GeneratedColumn<String>(
    'graded_photo_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorGradingModeMeta = const VerificationMeta(
    'colorGradingMode',
  );
  @override
  late final GeneratedColumn<String> colorGradingMode = GeneratedColumn<String>(
    'color_grading_mode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorGradingParamsJsonMeta =
      const VerificationMeta('colorGradingParamsJson');
  @override
  late final GeneratedColumn<String> colorGradingParamsJson =
      GeneratedColumn<String>(
        'color_grading_params_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _colorGradingIntensityMeta =
      const VerificationMeta('colorGradingIntensity');
  @override
  late final GeneratedColumn<double> colorGradingIntensity =
      GeneratedColumn<double>(
        'color_grading_intensity',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _referenceImagePathMeta =
      const VerificationMeta('referenceImagePath');
  @override
  late final GeneratedColumn<String> referenceImagePath =
      GeneratedColumn<String>(
        'reference_image_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _referenceImageUrlMeta = const VerificationMeta(
    'referenceImageUrl',
  );
  @override
  late final GeneratedColumn<String> referenceImageUrl =
      GeneratedColumn<String>(
        'reference_image_url',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _referenceModeMeta = const VerificationMeta(
    'referenceMode',
  );
  @override
  late final GeneratedColumn<String> referenceMode = GeneratedColumn<String>(
    'reference_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capturedAtMeta = const VerificationMeta(
    'capturedAt',
  );
  @override
  late final GeneratedColumn<DateTime> capturedAt = GeneratedColumn<DateTime>(
    'captured_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    planId,
    pointId,
    workId,
    workTitle,
    workSubtitle,
    pointName,
    pointSubtitle,
    photoPath,
    originalPhotoPath,
    gradedPhotoPath,
    colorGradingMode,
    colorGradingParamsJson,
    colorGradingIntensity,
    referenceImagePath,
    referenceImageUrl,
    referenceMode,
    capturedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'visit_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<VisitRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('plan_id')) {
      context.handle(
        _planIdMeta,
        planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta),
      );
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    if (data.containsKey('point_id')) {
      context.handle(
        _pointIdMeta,
        pointId.isAcceptableOrUnknown(data['point_id']!, _pointIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pointIdMeta);
    }
    if (data.containsKey('work_id')) {
      context.handle(
        _workIdMeta,
        workId.isAcceptableOrUnknown(data['work_id']!, _workIdMeta),
      );
    } else if (isInserting) {
      context.missing(_workIdMeta);
    }
    if (data.containsKey('work_title')) {
      context.handle(
        _workTitleMeta,
        workTitle.isAcceptableOrUnknown(data['work_title']!, _workTitleMeta),
      );
    }
    if (data.containsKey('work_subtitle')) {
      context.handle(
        _workSubtitleMeta,
        workSubtitle.isAcceptableOrUnknown(
          data['work_subtitle']!,
          _workSubtitleMeta,
        ),
      );
    }
    if (data.containsKey('point_name')) {
      context.handle(
        _pointNameMeta,
        pointName.isAcceptableOrUnknown(data['point_name']!, _pointNameMeta),
      );
    }
    if (data.containsKey('point_subtitle')) {
      context.handle(
        _pointSubtitleMeta,
        pointSubtitle.isAcceptableOrUnknown(
          data['point_subtitle']!,
          _pointSubtitleMeta,
        ),
      );
    }
    if (data.containsKey('photo_path')) {
      context.handle(
        _photoPathMeta,
        photoPath.isAcceptableOrUnknown(data['photo_path']!, _photoPathMeta),
      );
    } else if (isInserting) {
      context.missing(_photoPathMeta);
    }
    if (data.containsKey('original_photo_path')) {
      context.handle(
        _originalPhotoPathMeta,
        originalPhotoPath.isAcceptableOrUnknown(
          data['original_photo_path']!,
          _originalPhotoPathMeta,
        ),
      );
    }
    if (data.containsKey('graded_photo_path')) {
      context.handle(
        _gradedPhotoPathMeta,
        gradedPhotoPath.isAcceptableOrUnknown(
          data['graded_photo_path']!,
          _gradedPhotoPathMeta,
        ),
      );
    }
    if (data.containsKey('color_grading_mode')) {
      context.handle(
        _colorGradingModeMeta,
        colorGradingMode.isAcceptableOrUnknown(
          data['color_grading_mode']!,
          _colorGradingModeMeta,
        ),
      );
    }
    if (data.containsKey('color_grading_params_json')) {
      context.handle(
        _colorGradingParamsJsonMeta,
        colorGradingParamsJson.isAcceptableOrUnknown(
          data['color_grading_params_json']!,
          _colorGradingParamsJsonMeta,
        ),
      );
    }
    if (data.containsKey('color_grading_intensity')) {
      context.handle(
        _colorGradingIntensityMeta,
        colorGradingIntensity.isAcceptableOrUnknown(
          data['color_grading_intensity']!,
          _colorGradingIntensityMeta,
        ),
      );
    }
    if (data.containsKey('reference_image_path')) {
      context.handle(
        _referenceImagePathMeta,
        referenceImagePath.isAcceptableOrUnknown(
          data['reference_image_path']!,
          _referenceImagePathMeta,
        ),
      );
    }
    if (data.containsKey('reference_image_url')) {
      context.handle(
        _referenceImageUrlMeta,
        referenceImageUrl.isAcceptableOrUnknown(
          data['reference_image_url']!,
          _referenceImageUrlMeta,
        ),
      );
    }
    if (data.containsKey('reference_mode')) {
      context.handle(
        _referenceModeMeta,
        referenceMode.isAcceptableOrUnknown(
          data['reference_mode']!,
          _referenceModeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_referenceModeMeta);
    }
    if (data.containsKey('captured_at')) {
      context.handle(
        _capturedAtMeta,
        capturedAt.isAcceptableOrUnknown(data['captured_at']!, _capturedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_capturedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VisitRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VisitRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      planId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_id'],
      )!,
      pointId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}point_id'],
      )!,
      workId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}work_id'],
      )!,
      workTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}work_title'],
      ),
      workSubtitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}work_subtitle'],
      ),
      pointName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}point_name'],
      ),
      pointSubtitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}point_subtitle'],
      ),
      photoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_path'],
      )!,
      originalPhotoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_photo_path'],
      ),
      gradedPhotoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}graded_photo_path'],
      ),
      colorGradingMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_grading_mode'],
      ),
      colorGradingParamsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_grading_params_json'],
      ),
      colorGradingIntensity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}color_grading_intensity'],
      ),
      referenceImagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference_image_path'],
      ),
      referenceImageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference_image_url'],
      ),
      referenceMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference_mode'],
      )!,
      capturedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}captured_at'],
      )!,
    );
  }

  @override
  $VisitRecordsTable createAlias(String alias) {
    return $VisitRecordsTable(attachedDatabase, alias);
  }
}

class VisitRecord extends DataClass implements Insertable<VisitRecord> {
  final String id;
  final String planId;
  final String pointId;
  final String workId;
  final String? workTitle;
  final String? workSubtitle;
  final String? pointName;
  final String? pointSubtitle;
  final String photoPath;
  final String? originalPhotoPath;
  final String? gradedPhotoPath;
  final String? colorGradingMode;
  final String? colorGradingParamsJson;
  final double? colorGradingIntensity;
  final String? referenceImagePath;
  final String? referenceImageUrl;
  final String referenceMode;
  final DateTime capturedAt;
  const VisitRecord({
    required this.id,
    required this.planId,
    required this.pointId,
    required this.workId,
    this.workTitle,
    this.workSubtitle,
    this.pointName,
    this.pointSubtitle,
    required this.photoPath,
    this.originalPhotoPath,
    this.gradedPhotoPath,
    this.colorGradingMode,
    this.colorGradingParamsJson,
    this.colorGradingIntensity,
    this.referenceImagePath,
    this.referenceImageUrl,
    required this.referenceMode,
    required this.capturedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['plan_id'] = Variable<String>(planId);
    map['point_id'] = Variable<String>(pointId);
    map['work_id'] = Variable<String>(workId);
    if (!nullToAbsent || workTitle != null) {
      map['work_title'] = Variable<String>(workTitle);
    }
    if (!nullToAbsent || workSubtitle != null) {
      map['work_subtitle'] = Variable<String>(workSubtitle);
    }
    if (!nullToAbsent || pointName != null) {
      map['point_name'] = Variable<String>(pointName);
    }
    if (!nullToAbsent || pointSubtitle != null) {
      map['point_subtitle'] = Variable<String>(pointSubtitle);
    }
    map['photo_path'] = Variable<String>(photoPath);
    if (!nullToAbsent || originalPhotoPath != null) {
      map['original_photo_path'] = Variable<String>(originalPhotoPath);
    }
    if (!nullToAbsent || gradedPhotoPath != null) {
      map['graded_photo_path'] = Variable<String>(gradedPhotoPath);
    }
    if (!nullToAbsent || colorGradingMode != null) {
      map['color_grading_mode'] = Variable<String>(colorGradingMode);
    }
    if (!nullToAbsent || colorGradingParamsJson != null) {
      map['color_grading_params_json'] = Variable<String>(
        colorGradingParamsJson,
      );
    }
    if (!nullToAbsent || colorGradingIntensity != null) {
      map['color_grading_intensity'] = Variable<double>(colorGradingIntensity);
    }
    if (!nullToAbsent || referenceImagePath != null) {
      map['reference_image_path'] = Variable<String>(referenceImagePath);
    }
    if (!nullToAbsent || referenceImageUrl != null) {
      map['reference_image_url'] = Variable<String>(referenceImageUrl);
    }
    map['reference_mode'] = Variable<String>(referenceMode);
    map['captured_at'] = Variable<DateTime>(capturedAt);
    return map;
  }

  VisitRecordsCompanion toCompanion(bool nullToAbsent) {
    return VisitRecordsCompanion(
      id: Value(id),
      planId: Value(planId),
      pointId: Value(pointId),
      workId: Value(workId),
      workTitle: workTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(workTitle),
      workSubtitle: workSubtitle == null && nullToAbsent
          ? const Value.absent()
          : Value(workSubtitle),
      pointName: pointName == null && nullToAbsent
          ? const Value.absent()
          : Value(pointName),
      pointSubtitle: pointSubtitle == null && nullToAbsent
          ? const Value.absent()
          : Value(pointSubtitle),
      photoPath: Value(photoPath),
      originalPhotoPath: originalPhotoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(originalPhotoPath),
      gradedPhotoPath: gradedPhotoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(gradedPhotoPath),
      colorGradingMode: colorGradingMode == null && nullToAbsent
          ? const Value.absent()
          : Value(colorGradingMode),
      colorGradingParamsJson: colorGradingParamsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(colorGradingParamsJson),
      colorGradingIntensity: colorGradingIntensity == null && nullToAbsent
          ? const Value.absent()
          : Value(colorGradingIntensity),
      referenceImagePath: referenceImagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceImagePath),
      referenceImageUrl: referenceImageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceImageUrl),
      referenceMode: Value(referenceMode),
      capturedAt: Value(capturedAt),
    );
  }

  factory VisitRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VisitRecord(
      id: serializer.fromJson<String>(json['id']),
      planId: serializer.fromJson<String>(json['planId']),
      pointId: serializer.fromJson<String>(json['pointId']),
      workId: serializer.fromJson<String>(json['workId']),
      workTitle: serializer.fromJson<String?>(json['workTitle']),
      workSubtitle: serializer.fromJson<String?>(json['workSubtitle']),
      pointName: serializer.fromJson<String?>(json['pointName']),
      pointSubtitle: serializer.fromJson<String?>(json['pointSubtitle']),
      photoPath: serializer.fromJson<String>(json['photoPath']),
      originalPhotoPath: serializer.fromJson<String?>(
        json['originalPhotoPath'],
      ),
      gradedPhotoPath: serializer.fromJson<String?>(json['gradedPhotoPath']),
      colorGradingMode: serializer.fromJson<String?>(json['colorGradingMode']),
      colorGradingParamsJson: serializer.fromJson<String?>(
        json['colorGradingParamsJson'],
      ),
      colorGradingIntensity: serializer.fromJson<double?>(
        json['colorGradingIntensity'],
      ),
      referenceImagePath: serializer.fromJson<String?>(
        json['referenceImagePath'],
      ),
      referenceImageUrl: serializer.fromJson<String?>(
        json['referenceImageUrl'],
      ),
      referenceMode: serializer.fromJson<String>(json['referenceMode']),
      capturedAt: serializer.fromJson<DateTime>(json['capturedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'planId': serializer.toJson<String>(planId),
      'pointId': serializer.toJson<String>(pointId),
      'workId': serializer.toJson<String>(workId),
      'workTitle': serializer.toJson<String?>(workTitle),
      'workSubtitle': serializer.toJson<String?>(workSubtitle),
      'pointName': serializer.toJson<String?>(pointName),
      'pointSubtitle': serializer.toJson<String?>(pointSubtitle),
      'photoPath': serializer.toJson<String>(photoPath),
      'originalPhotoPath': serializer.toJson<String?>(originalPhotoPath),
      'gradedPhotoPath': serializer.toJson<String?>(gradedPhotoPath),
      'colorGradingMode': serializer.toJson<String?>(colorGradingMode),
      'colorGradingParamsJson': serializer.toJson<String?>(
        colorGradingParamsJson,
      ),
      'colorGradingIntensity': serializer.toJson<double?>(
        colorGradingIntensity,
      ),
      'referenceImagePath': serializer.toJson<String?>(referenceImagePath),
      'referenceImageUrl': serializer.toJson<String?>(referenceImageUrl),
      'referenceMode': serializer.toJson<String>(referenceMode),
      'capturedAt': serializer.toJson<DateTime>(capturedAt),
    };
  }

  VisitRecord copyWith({
    String? id,
    String? planId,
    String? pointId,
    String? workId,
    Value<String?> workTitle = const Value.absent(),
    Value<String?> workSubtitle = const Value.absent(),
    Value<String?> pointName = const Value.absent(),
    Value<String?> pointSubtitle = const Value.absent(),
    String? photoPath,
    Value<String?> originalPhotoPath = const Value.absent(),
    Value<String?> gradedPhotoPath = const Value.absent(),
    Value<String?> colorGradingMode = const Value.absent(),
    Value<String?> colorGradingParamsJson = const Value.absent(),
    Value<double?> colorGradingIntensity = const Value.absent(),
    Value<String?> referenceImagePath = const Value.absent(),
    Value<String?> referenceImageUrl = const Value.absent(),
    String? referenceMode,
    DateTime? capturedAt,
  }) => VisitRecord(
    id: id ?? this.id,
    planId: planId ?? this.planId,
    pointId: pointId ?? this.pointId,
    workId: workId ?? this.workId,
    workTitle: workTitle.present ? workTitle.value : this.workTitle,
    workSubtitle: workSubtitle.present ? workSubtitle.value : this.workSubtitle,
    pointName: pointName.present ? pointName.value : this.pointName,
    pointSubtitle: pointSubtitle.present
        ? pointSubtitle.value
        : this.pointSubtitle,
    photoPath: photoPath ?? this.photoPath,
    originalPhotoPath: originalPhotoPath.present
        ? originalPhotoPath.value
        : this.originalPhotoPath,
    gradedPhotoPath: gradedPhotoPath.present
        ? gradedPhotoPath.value
        : this.gradedPhotoPath,
    colorGradingMode: colorGradingMode.present
        ? colorGradingMode.value
        : this.colorGradingMode,
    colorGradingParamsJson: colorGradingParamsJson.present
        ? colorGradingParamsJson.value
        : this.colorGradingParamsJson,
    colorGradingIntensity: colorGradingIntensity.present
        ? colorGradingIntensity.value
        : this.colorGradingIntensity,
    referenceImagePath: referenceImagePath.present
        ? referenceImagePath.value
        : this.referenceImagePath,
    referenceImageUrl: referenceImageUrl.present
        ? referenceImageUrl.value
        : this.referenceImageUrl,
    referenceMode: referenceMode ?? this.referenceMode,
    capturedAt: capturedAt ?? this.capturedAt,
  );
  VisitRecord copyWithCompanion(VisitRecordsCompanion data) {
    return VisitRecord(
      id: data.id.present ? data.id.value : this.id,
      planId: data.planId.present ? data.planId.value : this.planId,
      pointId: data.pointId.present ? data.pointId.value : this.pointId,
      workId: data.workId.present ? data.workId.value : this.workId,
      workTitle: data.workTitle.present ? data.workTitle.value : this.workTitle,
      workSubtitle: data.workSubtitle.present
          ? data.workSubtitle.value
          : this.workSubtitle,
      pointName: data.pointName.present ? data.pointName.value : this.pointName,
      pointSubtitle: data.pointSubtitle.present
          ? data.pointSubtitle.value
          : this.pointSubtitle,
      photoPath: data.photoPath.present ? data.photoPath.value : this.photoPath,
      originalPhotoPath: data.originalPhotoPath.present
          ? data.originalPhotoPath.value
          : this.originalPhotoPath,
      gradedPhotoPath: data.gradedPhotoPath.present
          ? data.gradedPhotoPath.value
          : this.gradedPhotoPath,
      colorGradingMode: data.colorGradingMode.present
          ? data.colorGradingMode.value
          : this.colorGradingMode,
      colorGradingParamsJson: data.colorGradingParamsJson.present
          ? data.colorGradingParamsJson.value
          : this.colorGradingParamsJson,
      colorGradingIntensity: data.colorGradingIntensity.present
          ? data.colorGradingIntensity.value
          : this.colorGradingIntensity,
      referenceImagePath: data.referenceImagePath.present
          ? data.referenceImagePath.value
          : this.referenceImagePath,
      referenceImageUrl: data.referenceImageUrl.present
          ? data.referenceImageUrl.value
          : this.referenceImageUrl,
      referenceMode: data.referenceMode.present
          ? data.referenceMode.value
          : this.referenceMode,
      capturedAt: data.capturedAt.present
          ? data.capturedAt.value
          : this.capturedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VisitRecord(')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('pointId: $pointId, ')
          ..write('workId: $workId, ')
          ..write('workTitle: $workTitle, ')
          ..write('workSubtitle: $workSubtitle, ')
          ..write('pointName: $pointName, ')
          ..write('pointSubtitle: $pointSubtitle, ')
          ..write('photoPath: $photoPath, ')
          ..write('originalPhotoPath: $originalPhotoPath, ')
          ..write('gradedPhotoPath: $gradedPhotoPath, ')
          ..write('colorGradingMode: $colorGradingMode, ')
          ..write('colorGradingParamsJson: $colorGradingParamsJson, ')
          ..write('colorGradingIntensity: $colorGradingIntensity, ')
          ..write('referenceImagePath: $referenceImagePath, ')
          ..write('referenceImageUrl: $referenceImageUrl, ')
          ..write('referenceMode: $referenceMode, ')
          ..write('capturedAt: $capturedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    planId,
    pointId,
    workId,
    workTitle,
    workSubtitle,
    pointName,
    pointSubtitle,
    photoPath,
    originalPhotoPath,
    gradedPhotoPath,
    colorGradingMode,
    colorGradingParamsJson,
    colorGradingIntensity,
    referenceImagePath,
    referenceImageUrl,
    referenceMode,
    capturedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VisitRecord &&
          other.id == this.id &&
          other.planId == this.planId &&
          other.pointId == this.pointId &&
          other.workId == this.workId &&
          other.workTitle == this.workTitle &&
          other.workSubtitle == this.workSubtitle &&
          other.pointName == this.pointName &&
          other.pointSubtitle == this.pointSubtitle &&
          other.photoPath == this.photoPath &&
          other.originalPhotoPath == this.originalPhotoPath &&
          other.gradedPhotoPath == this.gradedPhotoPath &&
          other.colorGradingMode == this.colorGradingMode &&
          other.colorGradingParamsJson == this.colorGradingParamsJson &&
          other.colorGradingIntensity == this.colorGradingIntensity &&
          other.referenceImagePath == this.referenceImagePath &&
          other.referenceImageUrl == this.referenceImageUrl &&
          other.referenceMode == this.referenceMode &&
          other.capturedAt == this.capturedAt);
}

class VisitRecordsCompanion extends UpdateCompanion<VisitRecord> {
  final Value<String> id;
  final Value<String> planId;
  final Value<String> pointId;
  final Value<String> workId;
  final Value<String?> workTitle;
  final Value<String?> workSubtitle;
  final Value<String?> pointName;
  final Value<String?> pointSubtitle;
  final Value<String> photoPath;
  final Value<String?> originalPhotoPath;
  final Value<String?> gradedPhotoPath;
  final Value<String?> colorGradingMode;
  final Value<String?> colorGradingParamsJson;
  final Value<double?> colorGradingIntensity;
  final Value<String?> referenceImagePath;
  final Value<String?> referenceImageUrl;
  final Value<String> referenceMode;
  final Value<DateTime> capturedAt;
  final Value<int> rowid;
  const VisitRecordsCompanion({
    this.id = const Value.absent(),
    this.planId = const Value.absent(),
    this.pointId = const Value.absent(),
    this.workId = const Value.absent(),
    this.workTitle = const Value.absent(),
    this.workSubtitle = const Value.absent(),
    this.pointName = const Value.absent(),
    this.pointSubtitle = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.originalPhotoPath = const Value.absent(),
    this.gradedPhotoPath = const Value.absent(),
    this.colorGradingMode = const Value.absent(),
    this.colorGradingParamsJson = const Value.absent(),
    this.colorGradingIntensity = const Value.absent(),
    this.referenceImagePath = const Value.absent(),
    this.referenceImageUrl = const Value.absent(),
    this.referenceMode = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VisitRecordsCompanion.insert({
    required String id,
    required String planId,
    required String pointId,
    required String workId,
    this.workTitle = const Value.absent(),
    this.workSubtitle = const Value.absent(),
    this.pointName = const Value.absent(),
    this.pointSubtitle = const Value.absent(),
    required String photoPath,
    this.originalPhotoPath = const Value.absent(),
    this.gradedPhotoPath = const Value.absent(),
    this.colorGradingMode = const Value.absent(),
    this.colorGradingParamsJson = const Value.absent(),
    this.colorGradingIntensity = const Value.absent(),
    this.referenceImagePath = const Value.absent(),
    this.referenceImageUrl = const Value.absent(),
    required String referenceMode,
    required DateTime capturedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       planId = Value(planId),
       pointId = Value(pointId),
       workId = Value(workId),
       photoPath = Value(photoPath),
       referenceMode = Value(referenceMode),
       capturedAt = Value(capturedAt);
  static Insertable<VisitRecord> custom({
    Expression<String>? id,
    Expression<String>? planId,
    Expression<String>? pointId,
    Expression<String>? workId,
    Expression<String>? workTitle,
    Expression<String>? workSubtitle,
    Expression<String>? pointName,
    Expression<String>? pointSubtitle,
    Expression<String>? photoPath,
    Expression<String>? originalPhotoPath,
    Expression<String>? gradedPhotoPath,
    Expression<String>? colorGradingMode,
    Expression<String>? colorGradingParamsJson,
    Expression<double>? colorGradingIntensity,
    Expression<String>? referenceImagePath,
    Expression<String>? referenceImageUrl,
    Expression<String>? referenceMode,
    Expression<DateTime>? capturedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (planId != null) 'plan_id': planId,
      if (pointId != null) 'point_id': pointId,
      if (workId != null) 'work_id': workId,
      if (workTitle != null) 'work_title': workTitle,
      if (workSubtitle != null) 'work_subtitle': workSubtitle,
      if (pointName != null) 'point_name': pointName,
      if (pointSubtitle != null) 'point_subtitle': pointSubtitle,
      if (photoPath != null) 'photo_path': photoPath,
      if (originalPhotoPath != null) 'original_photo_path': originalPhotoPath,
      if (gradedPhotoPath != null) 'graded_photo_path': gradedPhotoPath,
      if (colorGradingMode != null) 'color_grading_mode': colorGradingMode,
      if (colorGradingParamsJson != null)
        'color_grading_params_json': colorGradingParamsJson,
      if (colorGradingIntensity != null)
        'color_grading_intensity': colorGradingIntensity,
      if (referenceImagePath != null)
        'reference_image_path': referenceImagePath,
      if (referenceImageUrl != null) 'reference_image_url': referenceImageUrl,
      if (referenceMode != null) 'reference_mode': referenceMode,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VisitRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? planId,
    Value<String>? pointId,
    Value<String>? workId,
    Value<String?>? workTitle,
    Value<String?>? workSubtitle,
    Value<String?>? pointName,
    Value<String?>? pointSubtitle,
    Value<String>? photoPath,
    Value<String?>? originalPhotoPath,
    Value<String?>? gradedPhotoPath,
    Value<String?>? colorGradingMode,
    Value<String?>? colorGradingParamsJson,
    Value<double?>? colorGradingIntensity,
    Value<String?>? referenceImagePath,
    Value<String?>? referenceImageUrl,
    Value<String>? referenceMode,
    Value<DateTime>? capturedAt,
    Value<int>? rowid,
  }) {
    return VisitRecordsCompanion(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      pointId: pointId ?? this.pointId,
      workId: workId ?? this.workId,
      workTitle: workTitle ?? this.workTitle,
      workSubtitle: workSubtitle ?? this.workSubtitle,
      pointName: pointName ?? this.pointName,
      pointSubtitle: pointSubtitle ?? this.pointSubtitle,
      photoPath: photoPath ?? this.photoPath,
      originalPhotoPath: originalPhotoPath ?? this.originalPhotoPath,
      gradedPhotoPath: gradedPhotoPath ?? this.gradedPhotoPath,
      colorGradingMode: colorGradingMode ?? this.colorGradingMode,
      colorGradingParamsJson:
          colorGradingParamsJson ?? this.colorGradingParamsJson,
      colorGradingIntensity:
          colorGradingIntensity ?? this.colorGradingIntensity,
      referenceImagePath: referenceImagePath ?? this.referenceImagePath,
      referenceImageUrl: referenceImageUrl ?? this.referenceImageUrl,
      referenceMode: referenceMode ?? this.referenceMode,
      capturedAt: capturedAt ?? this.capturedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<String>(planId.value);
    }
    if (pointId.present) {
      map['point_id'] = Variable<String>(pointId.value);
    }
    if (workId.present) {
      map['work_id'] = Variable<String>(workId.value);
    }
    if (workTitle.present) {
      map['work_title'] = Variable<String>(workTitle.value);
    }
    if (workSubtitle.present) {
      map['work_subtitle'] = Variable<String>(workSubtitle.value);
    }
    if (pointName.present) {
      map['point_name'] = Variable<String>(pointName.value);
    }
    if (pointSubtitle.present) {
      map['point_subtitle'] = Variable<String>(pointSubtitle.value);
    }
    if (photoPath.present) {
      map['photo_path'] = Variable<String>(photoPath.value);
    }
    if (originalPhotoPath.present) {
      map['original_photo_path'] = Variable<String>(originalPhotoPath.value);
    }
    if (gradedPhotoPath.present) {
      map['graded_photo_path'] = Variable<String>(gradedPhotoPath.value);
    }
    if (colorGradingMode.present) {
      map['color_grading_mode'] = Variable<String>(colorGradingMode.value);
    }
    if (colorGradingParamsJson.present) {
      map['color_grading_params_json'] = Variable<String>(
        colorGradingParamsJson.value,
      );
    }
    if (colorGradingIntensity.present) {
      map['color_grading_intensity'] = Variable<double>(
        colorGradingIntensity.value,
      );
    }
    if (referenceImagePath.present) {
      map['reference_image_path'] = Variable<String>(referenceImagePath.value);
    }
    if (referenceImageUrl.present) {
      map['reference_image_url'] = Variable<String>(referenceImageUrl.value);
    }
    if (referenceMode.present) {
      map['reference_mode'] = Variable<String>(referenceMode.value);
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<DateTime>(capturedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VisitRecordsCompanion(')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('pointId: $pointId, ')
          ..write('workId: $workId, ')
          ..write('workTitle: $workTitle, ')
          ..write('workSubtitle: $workSubtitle, ')
          ..write('pointName: $pointName, ')
          ..write('pointSubtitle: $pointSubtitle, ')
          ..write('photoPath: $photoPath, ')
          ..write('originalPhotoPath: $originalPhotoPath, ')
          ..write('gradedPhotoPath: $gradedPhotoPath, ')
          ..write('colorGradingMode: $colorGradingMode, ')
          ..write('colorGradingParamsJson: $colorGradingParamsJson, ')
          ..write('colorGradingIntensity: $colorGradingIntensity, ')
          ..write('referenceImagePath: $referenceImagePath, ')
          ..write('referenceImageUrl: $referenceImageUrl, ')
          ..write('referenceMode: $referenceMode, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsEntriesTable extends AppSettingsEntries
    with TableInfo<$AppSettingsEntriesTable, AppSettingsEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uiScaleMeta = const VerificationMeta(
    'uiScale',
  );
  @override
  late final GeneratedColumn<double> uiScale = GeneratedColumn<double>(
    'ui_scale',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.0),
  );
  static const VerificationMeta _fontScaleMeta = const VerificationMeta(
    'fontScale',
  );
  @override
  late final GeneratedColumn<double> fontScale = GeneratedColumn<double>(
    'font_scale',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.0),
  );
  static const VerificationMeta _themeModeMeta = const VerificationMeta(
    'themeMode',
  );
  @override
  late final GeneratedColumn<String> themeMode = GeneratedColumn<String>(
    'theme_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('light'),
  );
  static const VerificationMeta _cameraAspectRatioMeta = const VerificationMeta(
    'cameraAspectRatio',
  );
  @override
  late final GeneratedColumn<String> cameraAspectRatio =
      GeneratedColumn<String>(
        'camera_aspect_ratio',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('auto'),
      );
  static const VerificationMeta _cameraCaptureAspectRatioMeta =
      const VerificationMeta('cameraCaptureAspectRatio');
  @override
  late final GeneratedColumn<String> cameraCaptureAspectRatio =
      GeneratedColumn<String>(
        'camera_capture_aspect_ratio',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('auto'),
      );
  static const VerificationMeta _cameraMinZoomMeta = const VerificationMeta(
    'cameraMinZoom',
  );
  @override
  late final GeneratedColumn<double> cameraMinZoom = GeneratedColumn<double>(
    'camera_min_zoom',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.6),
  );
  static const VerificationMeta _cameraMaxZoomMeta = const VerificationMeta(
    'cameraMaxZoom',
  );
  @override
  late final GeneratedColumn<double> cameraMaxZoom = GeneratedColumn<double>(
    'camera_max_zoom',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(5.0),
  );
  static const VerificationMeta _referenceImageScaleMeta =
      const VerificationMeta('referenceImageScale');
  @override
  late final GeneratedColumn<double> referenceImageScale =
      GeneratedColumn<double>(
        'reference_image_scale',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(1.0),
      );
  static const VerificationMeta _nearestAssignDistanceMetersMeta =
      const VerificationMeta('nearestAssignDistanceMeters');
  @override
  late final GeneratedColumn<double> nearestAssignDistanceMeters =
      GeneratedColumn<double>(
        'nearest_assign_distance_meters',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(350.0),
      );
  static const VerificationMeta _themePaletteMeta = const VerificationMeta(
    'themePalette',
  );
  @override
  late final GeneratedColumn<String> themePalette = GeneratedColumn<String>(
    'theme_palette',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('classicGreen'),
  );
  static const VerificationMeta _mapTileProviderMeta = const VerificationMeta(
    'mapTileProvider',
  );
  @override
  late final GeneratedColumn<String> mapTileProvider = GeneratedColumn<String>(
    'map_tile_provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('openFreeMap'),
  );
  static const VerificationMeta _openFreeMapStyleMeta = const VerificationMeta(
    'openFreeMapStyle',
  );
  @override
  late final GeneratedColumn<String> openFreeMapStyle = GeneratedColumn<String>(
    'open_free_map_style',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('liberty'),
  );
  static const VerificationMeta _anitabiImageSourceMeta =
      const VerificationMeta('anitabiImageSource');
  @override
  late final GeneratedColumn<String> anitabiImageSource =
      GeneratedColumn<String>(
        'anitabi_image_source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('auto'),
      );
  static const VerificationMeta _navigationAppMeta = const VerificationMeta(
    'navigationApp',
  );
  @override
  late final GeneratedColumn<String> navigationApp = GeneratedColumn<String>(
    'navigation_app',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('googleMaps'),
  );
  static const VerificationMeta _customXyzTileUrlMeta = const VerificationMeta(
    'customXyzTileUrl',
  );
  @override
  late final GeneratedColumn<String> customXyzTileUrl = GeneratedColumn<String>(
    'custom_xyz_tile_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _customMapLibreStyleUrlMeta =
      const VerificationMeta('customMapLibreStyleUrl');
  @override
  late final GeneratedColumn<String> customMapLibreStyleUrl =
      GeneratedColumn<String>(
        'custom_map_libre_style_url',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant(''),
      );
  static const VerificationMeta _saveVisitPhotoToGalleryMeta =
      const VerificationMeta('saveVisitPhotoToGallery');
  @override
  late final GeneratedColumn<bool> saveVisitPhotoToGallery =
      GeneratedColumn<bool>(
        'save_visit_photo_to_gallery',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("save_visit_photo_to_gallery" IN (0, 1))',
        ),
        defaultValue: const Constant(true),
      );
  static const VerificationMeta _autoSaveComparisonToGalleryMeta =
      const VerificationMeta('autoSaveComparisonToGallery');
  @override
  late final GeneratedColumn<bool> autoSaveComparisonToGallery =
      GeneratedColumn<bool>(
        'auto_save_comparison_to_gallery',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("auto_save_comparison_to_gallery" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _comparisonShowPilgrimNameMeta =
      const VerificationMeta('comparisonShowPilgrimName');
  @override
  late final GeneratedColumn<bool> comparisonShowPilgrimName =
      GeneratedColumn<bool>(
        'comparison_show_pilgrim_name',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("comparison_show_pilgrim_name" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _comparisonPilgrimNameMeta =
      const VerificationMeta('comparisonPilgrimName');
  @override
  late final GeneratedColumn<String> comparisonPilgrimName =
      GeneratedColumn<String>(
        'comparison_pilgrim_name',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant(''),
      );
  static const VerificationMeta _customThemeColorNameMeta =
      const VerificationMeta('customThemeColorName');
  @override
  late final GeneratedColumn<String> customThemeColorName =
      GeneratedColumn<String>(
        'custom_theme_color_name',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('自定义'),
      );
  static const VerificationMeta _customThemeColorValueMeta =
      const VerificationMeta('customThemeColorValue');
  @override
  late final GeneratedColumn<int> customThemeColorValue = GeneratedColumn<int>(
    'custom_theme_color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0xFF16C6A8),
  );
  static const VerificationMeta _customThemeColorsJsonMeta =
      const VerificationMeta('customThemeColorsJson');
  @override
  late final GeneratedColumn<String> customThemeColorsJson =
      GeneratedColumn<String>(
        'custom_theme_colors_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _customCameraAspectRatioWidthMeta =
      const VerificationMeta('customCameraAspectRatioWidth');
  @override
  late final GeneratedColumn<double> customCameraAspectRatioWidth =
      GeneratedColumn<double>(
        'custom_camera_aspect_ratio_width',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(1.0),
      );
  static const VerificationMeta _customCameraAspectRatioHeightMeta =
      const VerificationMeta('customCameraAspectRatioHeight');
  @override
  late final GeneratedColumn<double> customCameraAspectRatioHeight =
      GeneratedColumn<double>(
        'custom_camera_aspect_ratio_height',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(1.0),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uiScale,
    fontScale,
    themeMode,
    cameraAspectRatio,
    cameraCaptureAspectRatio,
    cameraMinZoom,
    cameraMaxZoom,
    referenceImageScale,
    nearestAssignDistanceMeters,
    themePalette,
    mapTileProvider,
    openFreeMapStyle,
    anitabiImageSource,
    navigationApp,
    customXyzTileUrl,
    customMapLibreStyleUrl,
    saveVisitPhotoToGallery,
    autoSaveComparisonToGallery,
    comparisonShowPilgrimName,
    comparisonPilgrimName,
    customThemeColorName,
    customThemeColorValue,
    customThemeColorsJson,
    customCameraAspectRatioWidth,
    customCameraAspectRatioHeight,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSettingsEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('ui_scale')) {
      context.handle(
        _uiScaleMeta,
        uiScale.isAcceptableOrUnknown(data['ui_scale']!, _uiScaleMeta),
      );
    }
    if (data.containsKey('font_scale')) {
      context.handle(
        _fontScaleMeta,
        fontScale.isAcceptableOrUnknown(data['font_scale']!, _fontScaleMeta),
      );
    }
    if (data.containsKey('theme_mode')) {
      context.handle(
        _themeModeMeta,
        themeMode.isAcceptableOrUnknown(data['theme_mode']!, _themeModeMeta),
      );
    }
    if (data.containsKey('camera_aspect_ratio')) {
      context.handle(
        _cameraAspectRatioMeta,
        cameraAspectRatio.isAcceptableOrUnknown(
          data['camera_aspect_ratio']!,
          _cameraAspectRatioMeta,
        ),
      );
    }
    if (data.containsKey('camera_capture_aspect_ratio')) {
      context.handle(
        _cameraCaptureAspectRatioMeta,
        cameraCaptureAspectRatio.isAcceptableOrUnknown(
          data['camera_capture_aspect_ratio']!,
          _cameraCaptureAspectRatioMeta,
        ),
      );
    }
    if (data.containsKey('camera_min_zoom')) {
      context.handle(
        _cameraMinZoomMeta,
        cameraMinZoom.isAcceptableOrUnknown(
          data['camera_min_zoom']!,
          _cameraMinZoomMeta,
        ),
      );
    }
    if (data.containsKey('camera_max_zoom')) {
      context.handle(
        _cameraMaxZoomMeta,
        cameraMaxZoom.isAcceptableOrUnknown(
          data['camera_max_zoom']!,
          _cameraMaxZoomMeta,
        ),
      );
    }
    if (data.containsKey('reference_image_scale')) {
      context.handle(
        _referenceImageScaleMeta,
        referenceImageScale.isAcceptableOrUnknown(
          data['reference_image_scale']!,
          _referenceImageScaleMeta,
        ),
      );
    }
    if (data.containsKey('nearest_assign_distance_meters')) {
      context.handle(
        _nearestAssignDistanceMetersMeta,
        nearestAssignDistanceMeters.isAcceptableOrUnknown(
          data['nearest_assign_distance_meters']!,
          _nearestAssignDistanceMetersMeta,
        ),
      );
    }
    if (data.containsKey('theme_palette')) {
      context.handle(
        _themePaletteMeta,
        themePalette.isAcceptableOrUnknown(
          data['theme_palette']!,
          _themePaletteMeta,
        ),
      );
    }
    if (data.containsKey('map_tile_provider')) {
      context.handle(
        _mapTileProviderMeta,
        mapTileProvider.isAcceptableOrUnknown(
          data['map_tile_provider']!,
          _mapTileProviderMeta,
        ),
      );
    }
    if (data.containsKey('open_free_map_style')) {
      context.handle(
        _openFreeMapStyleMeta,
        openFreeMapStyle.isAcceptableOrUnknown(
          data['open_free_map_style']!,
          _openFreeMapStyleMeta,
        ),
      );
    }
    if (data.containsKey('anitabi_image_source')) {
      context.handle(
        _anitabiImageSourceMeta,
        anitabiImageSource.isAcceptableOrUnknown(
          data['anitabi_image_source']!,
          _anitabiImageSourceMeta,
        ),
      );
    }
    if (data.containsKey('navigation_app')) {
      context.handle(
        _navigationAppMeta,
        navigationApp.isAcceptableOrUnknown(
          data['navigation_app']!,
          _navigationAppMeta,
        ),
      );
    }
    if (data.containsKey('custom_xyz_tile_url')) {
      context.handle(
        _customXyzTileUrlMeta,
        customXyzTileUrl.isAcceptableOrUnknown(
          data['custom_xyz_tile_url']!,
          _customXyzTileUrlMeta,
        ),
      );
    }
    if (data.containsKey('custom_map_libre_style_url')) {
      context.handle(
        _customMapLibreStyleUrlMeta,
        customMapLibreStyleUrl.isAcceptableOrUnknown(
          data['custom_map_libre_style_url']!,
          _customMapLibreStyleUrlMeta,
        ),
      );
    }
    if (data.containsKey('save_visit_photo_to_gallery')) {
      context.handle(
        _saveVisitPhotoToGalleryMeta,
        saveVisitPhotoToGallery.isAcceptableOrUnknown(
          data['save_visit_photo_to_gallery']!,
          _saveVisitPhotoToGalleryMeta,
        ),
      );
    }
    if (data.containsKey('auto_save_comparison_to_gallery')) {
      context.handle(
        _autoSaveComparisonToGalleryMeta,
        autoSaveComparisonToGallery.isAcceptableOrUnknown(
          data['auto_save_comparison_to_gallery']!,
          _autoSaveComparisonToGalleryMeta,
        ),
      );
    }
    if (data.containsKey('comparison_show_pilgrim_name')) {
      context.handle(
        _comparisonShowPilgrimNameMeta,
        comparisonShowPilgrimName.isAcceptableOrUnknown(
          data['comparison_show_pilgrim_name']!,
          _comparisonShowPilgrimNameMeta,
        ),
      );
    }
    if (data.containsKey('comparison_pilgrim_name')) {
      context.handle(
        _comparisonPilgrimNameMeta,
        comparisonPilgrimName.isAcceptableOrUnknown(
          data['comparison_pilgrim_name']!,
          _comparisonPilgrimNameMeta,
        ),
      );
    }
    if (data.containsKey('custom_theme_color_name')) {
      context.handle(
        _customThemeColorNameMeta,
        customThemeColorName.isAcceptableOrUnknown(
          data['custom_theme_color_name']!,
          _customThemeColorNameMeta,
        ),
      );
    }
    if (data.containsKey('custom_theme_color_value')) {
      context.handle(
        _customThemeColorValueMeta,
        customThemeColorValue.isAcceptableOrUnknown(
          data['custom_theme_color_value']!,
          _customThemeColorValueMeta,
        ),
      );
    }
    if (data.containsKey('custom_theme_colors_json')) {
      context.handle(
        _customThemeColorsJsonMeta,
        customThemeColorsJson.isAcceptableOrUnknown(
          data['custom_theme_colors_json']!,
          _customThemeColorsJsonMeta,
        ),
      );
    }
    if (data.containsKey('custom_camera_aspect_ratio_width')) {
      context.handle(
        _customCameraAspectRatioWidthMeta,
        customCameraAspectRatioWidth.isAcceptableOrUnknown(
          data['custom_camera_aspect_ratio_width']!,
          _customCameraAspectRatioWidthMeta,
        ),
      );
    }
    if (data.containsKey('custom_camera_aspect_ratio_height')) {
      context.handle(
        _customCameraAspectRatioHeightMeta,
        customCameraAspectRatioHeight.isAcceptableOrUnknown(
          data['custom_camera_aspect_ratio_height']!,
          _customCameraAspectRatioHeightMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppSettingsEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSettingsEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      uiScale: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ui_scale'],
      )!,
      fontScale: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}font_scale'],
      )!,
      themeMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme_mode'],
      )!,
      cameraAspectRatio: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}camera_aspect_ratio'],
      )!,
      cameraCaptureAspectRatio: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}camera_capture_aspect_ratio'],
      )!,
      cameraMinZoom: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}camera_min_zoom'],
      )!,
      cameraMaxZoom: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}camera_max_zoom'],
      )!,
      referenceImageScale: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}reference_image_scale'],
      )!,
      nearestAssignDistanceMeters: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}nearest_assign_distance_meters'],
      )!,
      themePalette: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme_palette'],
      )!,
      mapTileProvider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}map_tile_provider'],
      )!,
      openFreeMapStyle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}open_free_map_style'],
      )!,
      anitabiImageSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}anitabi_image_source'],
      )!,
      navigationApp: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}navigation_app'],
      )!,
      customXyzTileUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_xyz_tile_url'],
      )!,
      customMapLibreStyleUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_map_libre_style_url'],
      )!,
      saveVisitPhotoToGallery: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}save_visit_photo_to_gallery'],
      )!,
      autoSaveComparisonToGallery: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_save_comparison_to_gallery'],
      )!,
      comparisonShowPilgrimName: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}comparison_show_pilgrim_name'],
      )!,
      comparisonPilgrimName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comparison_pilgrim_name'],
      )!,
      customThemeColorName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_theme_color_name'],
      )!,
      customThemeColorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}custom_theme_color_value'],
      )!,
      customThemeColorsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_theme_colors_json'],
      )!,
      customCameraAspectRatioWidth: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}custom_camera_aspect_ratio_width'],
      )!,
      customCameraAspectRatioHeight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}custom_camera_aspect_ratio_height'],
      )!,
    );
  }

  @override
  $AppSettingsEntriesTable createAlias(String alias) {
    return $AppSettingsEntriesTable(attachedDatabase, alias);
  }
}

class AppSettingsEntry extends DataClass
    implements Insertable<AppSettingsEntry> {
  final String id;
  final double uiScale;
  final double fontScale;
  final String themeMode;
  final String cameraAspectRatio;
  final String cameraCaptureAspectRatio;
  final double cameraMinZoom;
  final double cameraMaxZoom;
  final double referenceImageScale;
  final double nearestAssignDistanceMeters;
  final String themePalette;
  final String mapTileProvider;
  final String openFreeMapStyle;
  final String anitabiImageSource;
  final String navigationApp;
  final String customXyzTileUrl;
  final String customMapLibreStyleUrl;
  final bool saveVisitPhotoToGallery;
  final bool autoSaveComparisonToGallery;
  final bool comparisonShowPilgrimName;
  final String comparisonPilgrimName;
  final String customThemeColorName;
  final int customThemeColorValue;
  final String customThemeColorsJson;
  final double customCameraAspectRatioWidth;
  final double customCameraAspectRatioHeight;
  const AppSettingsEntry({
    required this.id,
    required this.uiScale,
    required this.fontScale,
    required this.themeMode,
    required this.cameraAspectRatio,
    required this.cameraCaptureAspectRatio,
    required this.cameraMinZoom,
    required this.cameraMaxZoom,
    required this.referenceImageScale,
    required this.nearestAssignDistanceMeters,
    required this.themePalette,
    required this.mapTileProvider,
    required this.openFreeMapStyle,
    required this.anitabiImageSource,
    required this.navigationApp,
    required this.customXyzTileUrl,
    required this.customMapLibreStyleUrl,
    required this.saveVisitPhotoToGallery,
    required this.autoSaveComparisonToGallery,
    required this.comparisonShowPilgrimName,
    required this.comparisonPilgrimName,
    required this.customThemeColorName,
    required this.customThemeColorValue,
    required this.customThemeColorsJson,
    required this.customCameraAspectRatioWidth,
    required this.customCameraAspectRatioHeight,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['ui_scale'] = Variable<double>(uiScale);
    map['font_scale'] = Variable<double>(fontScale);
    map['theme_mode'] = Variable<String>(themeMode);
    map['camera_aspect_ratio'] = Variable<String>(cameraAspectRatio);
    map['camera_capture_aspect_ratio'] = Variable<String>(
      cameraCaptureAspectRatio,
    );
    map['camera_min_zoom'] = Variable<double>(cameraMinZoom);
    map['camera_max_zoom'] = Variable<double>(cameraMaxZoom);
    map['reference_image_scale'] = Variable<double>(referenceImageScale);
    map['nearest_assign_distance_meters'] = Variable<double>(
      nearestAssignDistanceMeters,
    );
    map['theme_palette'] = Variable<String>(themePalette);
    map['map_tile_provider'] = Variable<String>(mapTileProvider);
    map['open_free_map_style'] = Variable<String>(openFreeMapStyle);
    map['anitabi_image_source'] = Variable<String>(anitabiImageSource);
    map['navigation_app'] = Variable<String>(navigationApp);
    map['custom_xyz_tile_url'] = Variable<String>(customXyzTileUrl);
    map['custom_map_libre_style_url'] = Variable<String>(
      customMapLibreStyleUrl,
    );
    map['save_visit_photo_to_gallery'] = Variable<bool>(
      saveVisitPhotoToGallery,
    );
    map['auto_save_comparison_to_gallery'] = Variable<bool>(
      autoSaveComparisonToGallery,
    );
    map['comparison_show_pilgrim_name'] = Variable<bool>(
      comparisonShowPilgrimName,
    );
    map['comparison_pilgrim_name'] = Variable<String>(comparisonPilgrimName);
    map['custom_theme_color_name'] = Variable<String>(customThemeColorName);
    map['custom_theme_color_value'] = Variable<int>(customThemeColorValue);
    map['custom_theme_colors_json'] = Variable<String>(customThemeColorsJson);
    map['custom_camera_aspect_ratio_width'] = Variable<double>(
      customCameraAspectRatioWidth,
    );
    map['custom_camera_aspect_ratio_height'] = Variable<double>(
      customCameraAspectRatioHeight,
    );
    return map;
  }

  AppSettingsEntriesCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsEntriesCompanion(
      id: Value(id),
      uiScale: Value(uiScale),
      fontScale: Value(fontScale),
      themeMode: Value(themeMode),
      cameraAspectRatio: Value(cameraAspectRatio),
      cameraCaptureAspectRatio: Value(cameraCaptureAspectRatio),
      cameraMinZoom: Value(cameraMinZoom),
      cameraMaxZoom: Value(cameraMaxZoom),
      referenceImageScale: Value(referenceImageScale),
      nearestAssignDistanceMeters: Value(nearestAssignDistanceMeters),
      themePalette: Value(themePalette),
      mapTileProvider: Value(mapTileProvider),
      openFreeMapStyle: Value(openFreeMapStyle),
      anitabiImageSource: Value(anitabiImageSource),
      navigationApp: Value(navigationApp),
      customXyzTileUrl: Value(customXyzTileUrl),
      customMapLibreStyleUrl: Value(customMapLibreStyleUrl),
      saveVisitPhotoToGallery: Value(saveVisitPhotoToGallery),
      autoSaveComparisonToGallery: Value(autoSaveComparisonToGallery),
      comparisonShowPilgrimName: Value(comparisonShowPilgrimName),
      comparisonPilgrimName: Value(comparisonPilgrimName),
      customThemeColorName: Value(customThemeColorName),
      customThemeColorValue: Value(customThemeColorValue),
      customThemeColorsJson: Value(customThemeColorsJson),
      customCameraAspectRatioWidth: Value(customCameraAspectRatioWidth),
      customCameraAspectRatioHeight: Value(customCameraAspectRatioHeight),
    );
  }

  factory AppSettingsEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSettingsEntry(
      id: serializer.fromJson<String>(json['id']),
      uiScale: serializer.fromJson<double>(json['uiScale']),
      fontScale: serializer.fromJson<double>(json['fontScale']),
      themeMode: serializer.fromJson<String>(json['themeMode']),
      cameraAspectRatio: serializer.fromJson<String>(json['cameraAspectRatio']),
      cameraCaptureAspectRatio: serializer.fromJson<String>(
        json['cameraCaptureAspectRatio'],
      ),
      cameraMinZoom: serializer.fromJson<double>(json['cameraMinZoom']),
      cameraMaxZoom: serializer.fromJson<double>(json['cameraMaxZoom']),
      referenceImageScale: serializer.fromJson<double>(
        json['referenceImageScale'],
      ),
      nearestAssignDistanceMeters: serializer.fromJson<double>(
        json['nearestAssignDistanceMeters'],
      ),
      themePalette: serializer.fromJson<String>(json['themePalette']),
      mapTileProvider: serializer.fromJson<String>(json['mapTileProvider']),
      openFreeMapStyle: serializer.fromJson<String>(json['openFreeMapStyle']),
      anitabiImageSource: serializer.fromJson<String>(
        json['anitabiImageSource'],
      ),
      navigationApp: serializer.fromJson<String>(json['navigationApp']),
      customXyzTileUrl: serializer.fromJson<String>(json['customXyzTileUrl']),
      customMapLibreStyleUrl: serializer.fromJson<String>(
        json['customMapLibreStyleUrl'],
      ),
      saveVisitPhotoToGallery: serializer.fromJson<bool>(
        json['saveVisitPhotoToGallery'],
      ),
      autoSaveComparisonToGallery: serializer.fromJson<bool>(
        json['autoSaveComparisonToGallery'],
      ),
      comparisonShowPilgrimName: serializer.fromJson<bool>(
        json['comparisonShowPilgrimName'],
      ),
      comparisonPilgrimName: serializer.fromJson<String>(
        json['comparisonPilgrimName'],
      ),
      customThemeColorName: serializer.fromJson<String>(
        json['customThemeColorName'],
      ),
      customThemeColorValue: serializer.fromJson<int>(
        json['customThemeColorValue'],
      ),
      customThemeColorsJson: serializer.fromJson<String>(
        json['customThemeColorsJson'],
      ),
      customCameraAspectRatioWidth: serializer.fromJson<double>(
        json['customCameraAspectRatioWidth'],
      ),
      customCameraAspectRatioHeight: serializer.fromJson<double>(
        json['customCameraAspectRatioHeight'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'uiScale': serializer.toJson<double>(uiScale),
      'fontScale': serializer.toJson<double>(fontScale),
      'themeMode': serializer.toJson<String>(themeMode),
      'cameraAspectRatio': serializer.toJson<String>(cameraAspectRatio),
      'cameraCaptureAspectRatio': serializer.toJson<String>(
        cameraCaptureAspectRatio,
      ),
      'cameraMinZoom': serializer.toJson<double>(cameraMinZoom),
      'cameraMaxZoom': serializer.toJson<double>(cameraMaxZoom),
      'referenceImageScale': serializer.toJson<double>(referenceImageScale),
      'nearestAssignDistanceMeters': serializer.toJson<double>(
        nearestAssignDistanceMeters,
      ),
      'themePalette': serializer.toJson<String>(themePalette),
      'mapTileProvider': serializer.toJson<String>(mapTileProvider),
      'openFreeMapStyle': serializer.toJson<String>(openFreeMapStyle),
      'anitabiImageSource': serializer.toJson<String>(anitabiImageSource),
      'navigationApp': serializer.toJson<String>(navigationApp),
      'customXyzTileUrl': serializer.toJson<String>(customXyzTileUrl),
      'customMapLibreStyleUrl': serializer.toJson<String>(
        customMapLibreStyleUrl,
      ),
      'saveVisitPhotoToGallery': serializer.toJson<bool>(
        saveVisitPhotoToGallery,
      ),
      'autoSaveComparisonToGallery': serializer.toJson<bool>(
        autoSaveComparisonToGallery,
      ),
      'comparisonShowPilgrimName': serializer.toJson<bool>(
        comparisonShowPilgrimName,
      ),
      'comparisonPilgrimName': serializer.toJson<String>(comparisonPilgrimName),
      'customThemeColorName': serializer.toJson<String>(customThemeColorName),
      'customThemeColorValue': serializer.toJson<int>(customThemeColorValue),
      'customThemeColorsJson': serializer.toJson<String>(customThemeColorsJson),
      'customCameraAspectRatioWidth': serializer.toJson<double>(
        customCameraAspectRatioWidth,
      ),
      'customCameraAspectRatioHeight': serializer.toJson<double>(
        customCameraAspectRatioHeight,
      ),
    };
  }

  AppSettingsEntry copyWith({
    String? id,
    double? uiScale,
    double? fontScale,
    String? themeMode,
    String? cameraAspectRatio,
    String? cameraCaptureAspectRatio,
    double? cameraMinZoom,
    double? cameraMaxZoom,
    double? referenceImageScale,
    double? nearestAssignDistanceMeters,
    String? themePalette,
    String? mapTileProvider,
    String? openFreeMapStyle,
    String? anitabiImageSource,
    String? navigationApp,
    String? customXyzTileUrl,
    String? customMapLibreStyleUrl,
    bool? saveVisitPhotoToGallery,
    bool? autoSaveComparisonToGallery,
    bool? comparisonShowPilgrimName,
    String? comparisonPilgrimName,
    String? customThemeColorName,
    int? customThemeColorValue,
    String? customThemeColorsJson,
    double? customCameraAspectRatioWidth,
    double? customCameraAspectRatioHeight,
  }) => AppSettingsEntry(
    id: id ?? this.id,
    uiScale: uiScale ?? this.uiScale,
    fontScale: fontScale ?? this.fontScale,
    themeMode: themeMode ?? this.themeMode,
    cameraAspectRatio: cameraAspectRatio ?? this.cameraAspectRatio,
    cameraCaptureAspectRatio:
        cameraCaptureAspectRatio ?? this.cameraCaptureAspectRatio,
    cameraMinZoom: cameraMinZoom ?? this.cameraMinZoom,
    cameraMaxZoom: cameraMaxZoom ?? this.cameraMaxZoom,
    referenceImageScale: referenceImageScale ?? this.referenceImageScale,
    nearestAssignDistanceMeters:
        nearestAssignDistanceMeters ?? this.nearestAssignDistanceMeters,
    themePalette: themePalette ?? this.themePalette,
    mapTileProvider: mapTileProvider ?? this.mapTileProvider,
    openFreeMapStyle: openFreeMapStyle ?? this.openFreeMapStyle,
    anitabiImageSource: anitabiImageSource ?? this.anitabiImageSource,
    navigationApp: navigationApp ?? this.navigationApp,
    customXyzTileUrl: customXyzTileUrl ?? this.customXyzTileUrl,
    customMapLibreStyleUrl:
        customMapLibreStyleUrl ?? this.customMapLibreStyleUrl,
    saveVisitPhotoToGallery:
        saveVisitPhotoToGallery ?? this.saveVisitPhotoToGallery,
    autoSaveComparisonToGallery:
        autoSaveComparisonToGallery ?? this.autoSaveComparisonToGallery,
    comparisonShowPilgrimName:
        comparisonShowPilgrimName ?? this.comparisonShowPilgrimName,
    comparisonPilgrimName: comparisonPilgrimName ?? this.comparisonPilgrimName,
    customThemeColorName: customThemeColorName ?? this.customThemeColorName,
    customThemeColorValue: customThemeColorValue ?? this.customThemeColorValue,
    customThemeColorsJson: customThemeColorsJson ?? this.customThemeColorsJson,
    customCameraAspectRatioWidth:
        customCameraAspectRatioWidth ?? this.customCameraAspectRatioWidth,
    customCameraAspectRatioHeight:
        customCameraAspectRatioHeight ?? this.customCameraAspectRatioHeight,
  );
  AppSettingsEntry copyWithCompanion(AppSettingsEntriesCompanion data) {
    return AppSettingsEntry(
      id: data.id.present ? data.id.value : this.id,
      uiScale: data.uiScale.present ? data.uiScale.value : this.uiScale,
      fontScale: data.fontScale.present ? data.fontScale.value : this.fontScale,
      themeMode: data.themeMode.present ? data.themeMode.value : this.themeMode,
      cameraAspectRatio: data.cameraAspectRatio.present
          ? data.cameraAspectRatio.value
          : this.cameraAspectRatio,
      cameraCaptureAspectRatio: data.cameraCaptureAspectRatio.present
          ? data.cameraCaptureAspectRatio.value
          : this.cameraCaptureAspectRatio,
      cameraMinZoom: data.cameraMinZoom.present
          ? data.cameraMinZoom.value
          : this.cameraMinZoom,
      cameraMaxZoom: data.cameraMaxZoom.present
          ? data.cameraMaxZoom.value
          : this.cameraMaxZoom,
      referenceImageScale: data.referenceImageScale.present
          ? data.referenceImageScale.value
          : this.referenceImageScale,
      nearestAssignDistanceMeters: data.nearestAssignDistanceMeters.present
          ? data.nearestAssignDistanceMeters.value
          : this.nearestAssignDistanceMeters,
      themePalette: data.themePalette.present
          ? data.themePalette.value
          : this.themePalette,
      mapTileProvider: data.mapTileProvider.present
          ? data.mapTileProvider.value
          : this.mapTileProvider,
      openFreeMapStyle: data.openFreeMapStyle.present
          ? data.openFreeMapStyle.value
          : this.openFreeMapStyle,
      anitabiImageSource: data.anitabiImageSource.present
          ? data.anitabiImageSource.value
          : this.anitabiImageSource,
      navigationApp: data.navigationApp.present
          ? data.navigationApp.value
          : this.navigationApp,
      customXyzTileUrl: data.customXyzTileUrl.present
          ? data.customXyzTileUrl.value
          : this.customXyzTileUrl,
      customMapLibreStyleUrl: data.customMapLibreStyleUrl.present
          ? data.customMapLibreStyleUrl.value
          : this.customMapLibreStyleUrl,
      saveVisitPhotoToGallery: data.saveVisitPhotoToGallery.present
          ? data.saveVisitPhotoToGallery.value
          : this.saveVisitPhotoToGallery,
      autoSaveComparisonToGallery: data.autoSaveComparisonToGallery.present
          ? data.autoSaveComparisonToGallery.value
          : this.autoSaveComparisonToGallery,
      comparisonShowPilgrimName: data.comparisonShowPilgrimName.present
          ? data.comparisonShowPilgrimName.value
          : this.comparisonShowPilgrimName,
      comparisonPilgrimName: data.comparisonPilgrimName.present
          ? data.comparisonPilgrimName.value
          : this.comparisonPilgrimName,
      customThemeColorName: data.customThemeColorName.present
          ? data.customThemeColorName.value
          : this.customThemeColorName,
      customThemeColorValue: data.customThemeColorValue.present
          ? data.customThemeColorValue.value
          : this.customThemeColorValue,
      customThemeColorsJson: data.customThemeColorsJson.present
          ? data.customThemeColorsJson.value
          : this.customThemeColorsJson,
      customCameraAspectRatioWidth: data.customCameraAspectRatioWidth.present
          ? data.customCameraAspectRatioWidth.value
          : this.customCameraAspectRatioWidth,
      customCameraAspectRatioHeight: data.customCameraAspectRatioHeight.present
          ? data.customCameraAspectRatioHeight.value
          : this.customCameraAspectRatioHeight,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsEntry(')
          ..write('id: $id, ')
          ..write('uiScale: $uiScale, ')
          ..write('fontScale: $fontScale, ')
          ..write('themeMode: $themeMode, ')
          ..write('cameraAspectRatio: $cameraAspectRatio, ')
          ..write('cameraCaptureAspectRatio: $cameraCaptureAspectRatio, ')
          ..write('cameraMinZoom: $cameraMinZoom, ')
          ..write('cameraMaxZoom: $cameraMaxZoom, ')
          ..write('referenceImageScale: $referenceImageScale, ')
          ..write('nearestAssignDistanceMeters: $nearestAssignDistanceMeters, ')
          ..write('themePalette: $themePalette, ')
          ..write('mapTileProvider: $mapTileProvider, ')
          ..write('openFreeMapStyle: $openFreeMapStyle, ')
          ..write('anitabiImageSource: $anitabiImageSource, ')
          ..write('navigationApp: $navigationApp, ')
          ..write('customXyzTileUrl: $customXyzTileUrl, ')
          ..write('customMapLibreStyleUrl: $customMapLibreStyleUrl, ')
          ..write('saveVisitPhotoToGallery: $saveVisitPhotoToGallery, ')
          ..write('autoSaveComparisonToGallery: $autoSaveComparisonToGallery, ')
          ..write('comparisonShowPilgrimName: $comparisonShowPilgrimName, ')
          ..write('comparisonPilgrimName: $comparisonPilgrimName, ')
          ..write('customThemeColorName: $customThemeColorName, ')
          ..write('customThemeColorValue: $customThemeColorValue, ')
          ..write('customThemeColorsJson: $customThemeColorsJson, ')
          ..write(
            'customCameraAspectRatioWidth: $customCameraAspectRatioWidth, ',
          )
          ..write(
            'customCameraAspectRatioHeight: $customCameraAspectRatioHeight',
          )
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    uiScale,
    fontScale,
    themeMode,
    cameraAspectRatio,
    cameraCaptureAspectRatio,
    cameraMinZoom,
    cameraMaxZoom,
    referenceImageScale,
    nearestAssignDistanceMeters,
    themePalette,
    mapTileProvider,
    openFreeMapStyle,
    anitabiImageSource,
    navigationApp,
    customXyzTileUrl,
    customMapLibreStyleUrl,
    saveVisitPhotoToGallery,
    autoSaveComparisonToGallery,
    comparisonShowPilgrimName,
    comparisonPilgrimName,
    customThemeColorName,
    customThemeColorValue,
    customThemeColorsJson,
    customCameraAspectRatioWidth,
    customCameraAspectRatioHeight,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettingsEntry &&
          other.id == this.id &&
          other.uiScale == this.uiScale &&
          other.fontScale == this.fontScale &&
          other.themeMode == this.themeMode &&
          other.cameraAspectRatio == this.cameraAspectRatio &&
          other.cameraCaptureAspectRatio == this.cameraCaptureAspectRatio &&
          other.cameraMinZoom == this.cameraMinZoom &&
          other.cameraMaxZoom == this.cameraMaxZoom &&
          other.referenceImageScale == this.referenceImageScale &&
          other.nearestAssignDistanceMeters ==
              this.nearestAssignDistanceMeters &&
          other.themePalette == this.themePalette &&
          other.mapTileProvider == this.mapTileProvider &&
          other.openFreeMapStyle == this.openFreeMapStyle &&
          other.anitabiImageSource == this.anitabiImageSource &&
          other.navigationApp == this.navigationApp &&
          other.customXyzTileUrl == this.customXyzTileUrl &&
          other.customMapLibreStyleUrl == this.customMapLibreStyleUrl &&
          other.saveVisitPhotoToGallery == this.saveVisitPhotoToGallery &&
          other.autoSaveComparisonToGallery ==
              this.autoSaveComparisonToGallery &&
          other.comparisonShowPilgrimName == this.comparisonShowPilgrimName &&
          other.comparisonPilgrimName == this.comparisonPilgrimName &&
          other.customThemeColorName == this.customThemeColorName &&
          other.customThemeColorValue == this.customThemeColorValue &&
          other.customThemeColorsJson == this.customThemeColorsJson &&
          other.customCameraAspectRatioWidth ==
              this.customCameraAspectRatioWidth &&
          other.customCameraAspectRatioHeight ==
              this.customCameraAspectRatioHeight);
}

class AppSettingsEntriesCompanion extends UpdateCompanion<AppSettingsEntry> {
  final Value<String> id;
  final Value<double> uiScale;
  final Value<double> fontScale;
  final Value<String> themeMode;
  final Value<String> cameraAspectRatio;
  final Value<String> cameraCaptureAspectRatio;
  final Value<double> cameraMinZoom;
  final Value<double> cameraMaxZoom;
  final Value<double> referenceImageScale;
  final Value<double> nearestAssignDistanceMeters;
  final Value<String> themePalette;
  final Value<String> mapTileProvider;
  final Value<String> openFreeMapStyle;
  final Value<String> anitabiImageSource;
  final Value<String> navigationApp;
  final Value<String> customXyzTileUrl;
  final Value<String> customMapLibreStyleUrl;
  final Value<bool> saveVisitPhotoToGallery;
  final Value<bool> autoSaveComparisonToGallery;
  final Value<bool> comparisonShowPilgrimName;
  final Value<String> comparisonPilgrimName;
  final Value<String> customThemeColorName;
  final Value<int> customThemeColorValue;
  final Value<String> customThemeColorsJson;
  final Value<double> customCameraAspectRatioWidth;
  final Value<double> customCameraAspectRatioHeight;
  final Value<int> rowid;
  const AppSettingsEntriesCompanion({
    this.id = const Value.absent(),
    this.uiScale = const Value.absent(),
    this.fontScale = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.cameraAspectRatio = const Value.absent(),
    this.cameraCaptureAspectRatio = const Value.absent(),
    this.cameraMinZoom = const Value.absent(),
    this.cameraMaxZoom = const Value.absent(),
    this.referenceImageScale = const Value.absent(),
    this.nearestAssignDistanceMeters = const Value.absent(),
    this.themePalette = const Value.absent(),
    this.mapTileProvider = const Value.absent(),
    this.openFreeMapStyle = const Value.absent(),
    this.anitabiImageSource = const Value.absent(),
    this.navigationApp = const Value.absent(),
    this.customXyzTileUrl = const Value.absent(),
    this.customMapLibreStyleUrl = const Value.absent(),
    this.saveVisitPhotoToGallery = const Value.absent(),
    this.autoSaveComparisonToGallery = const Value.absent(),
    this.comparisonShowPilgrimName = const Value.absent(),
    this.comparisonPilgrimName = const Value.absent(),
    this.customThemeColorName = const Value.absent(),
    this.customThemeColorValue = const Value.absent(),
    this.customThemeColorsJson = const Value.absent(),
    this.customCameraAspectRatioWidth = const Value.absent(),
    this.customCameraAspectRatioHeight = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsEntriesCompanion.insert({
    required String id,
    this.uiScale = const Value.absent(),
    this.fontScale = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.cameraAspectRatio = const Value.absent(),
    this.cameraCaptureAspectRatio = const Value.absent(),
    this.cameraMinZoom = const Value.absent(),
    this.cameraMaxZoom = const Value.absent(),
    this.referenceImageScale = const Value.absent(),
    this.nearestAssignDistanceMeters = const Value.absent(),
    this.themePalette = const Value.absent(),
    this.mapTileProvider = const Value.absent(),
    this.openFreeMapStyle = const Value.absent(),
    this.anitabiImageSource = const Value.absent(),
    this.navigationApp = const Value.absent(),
    this.customXyzTileUrl = const Value.absent(),
    this.customMapLibreStyleUrl = const Value.absent(),
    this.saveVisitPhotoToGallery = const Value.absent(),
    this.autoSaveComparisonToGallery = const Value.absent(),
    this.comparisonShowPilgrimName = const Value.absent(),
    this.comparisonPilgrimName = const Value.absent(),
    this.customThemeColorName = const Value.absent(),
    this.customThemeColorValue = const Value.absent(),
    this.customThemeColorsJson = const Value.absent(),
    this.customCameraAspectRatioWidth = const Value.absent(),
    this.customCameraAspectRatioHeight = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<AppSettingsEntry> custom({
    Expression<String>? id,
    Expression<double>? uiScale,
    Expression<double>? fontScale,
    Expression<String>? themeMode,
    Expression<String>? cameraAspectRatio,
    Expression<String>? cameraCaptureAspectRatio,
    Expression<double>? cameraMinZoom,
    Expression<double>? cameraMaxZoom,
    Expression<double>? referenceImageScale,
    Expression<double>? nearestAssignDistanceMeters,
    Expression<String>? themePalette,
    Expression<String>? mapTileProvider,
    Expression<String>? openFreeMapStyle,
    Expression<String>? anitabiImageSource,
    Expression<String>? navigationApp,
    Expression<String>? customXyzTileUrl,
    Expression<String>? customMapLibreStyleUrl,
    Expression<bool>? saveVisitPhotoToGallery,
    Expression<bool>? autoSaveComparisonToGallery,
    Expression<bool>? comparisonShowPilgrimName,
    Expression<String>? comparisonPilgrimName,
    Expression<String>? customThemeColorName,
    Expression<int>? customThemeColorValue,
    Expression<String>? customThemeColorsJson,
    Expression<double>? customCameraAspectRatioWidth,
    Expression<double>? customCameraAspectRatioHeight,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uiScale != null) 'ui_scale': uiScale,
      if (fontScale != null) 'font_scale': fontScale,
      if (themeMode != null) 'theme_mode': themeMode,
      if (cameraAspectRatio != null) 'camera_aspect_ratio': cameraAspectRatio,
      if (cameraCaptureAspectRatio != null)
        'camera_capture_aspect_ratio': cameraCaptureAspectRatio,
      if (cameraMinZoom != null) 'camera_min_zoom': cameraMinZoom,
      if (cameraMaxZoom != null) 'camera_max_zoom': cameraMaxZoom,
      if (referenceImageScale != null)
        'reference_image_scale': referenceImageScale,
      if (nearestAssignDistanceMeters != null)
        'nearest_assign_distance_meters': nearestAssignDistanceMeters,
      if (themePalette != null) 'theme_palette': themePalette,
      if (mapTileProvider != null) 'map_tile_provider': mapTileProvider,
      if (openFreeMapStyle != null) 'open_free_map_style': openFreeMapStyle,
      if (anitabiImageSource != null)
        'anitabi_image_source': anitabiImageSource,
      if (navigationApp != null) 'navigation_app': navigationApp,
      if (customXyzTileUrl != null) 'custom_xyz_tile_url': customXyzTileUrl,
      if (customMapLibreStyleUrl != null)
        'custom_map_libre_style_url': customMapLibreStyleUrl,
      if (saveVisitPhotoToGallery != null)
        'save_visit_photo_to_gallery': saveVisitPhotoToGallery,
      if (autoSaveComparisonToGallery != null)
        'auto_save_comparison_to_gallery': autoSaveComparisonToGallery,
      if (comparisonShowPilgrimName != null)
        'comparison_show_pilgrim_name': comparisonShowPilgrimName,
      if (comparisonPilgrimName != null)
        'comparison_pilgrim_name': comparisonPilgrimName,
      if (customThemeColorName != null)
        'custom_theme_color_name': customThemeColorName,
      if (customThemeColorValue != null)
        'custom_theme_color_value': customThemeColorValue,
      if (customThemeColorsJson != null)
        'custom_theme_colors_json': customThemeColorsJson,
      if (customCameraAspectRatioWidth != null)
        'custom_camera_aspect_ratio_width': customCameraAspectRatioWidth,
      if (customCameraAspectRatioHeight != null)
        'custom_camera_aspect_ratio_height': customCameraAspectRatioHeight,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsEntriesCompanion copyWith({
    Value<String>? id,
    Value<double>? uiScale,
    Value<double>? fontScale,
    Value<String>? themeMode,
    Value<String>? cameraAspectRatio,
    Value<String>? cameraCaptureAspectRatio,
    Value<double>? cameraMinZoom,
    Value<double>? cameraMaxZoom,
    Value<double>? referenceImageScale,
    Value<double>? nearestAssignDistanceMeters,
    Value<String>? themePalette,
    Value<String>? mapTileProvider,
    Value<String>? openFreeMapStyle,
    Value<String>? anitabiImageSource,
    Value<String>? navigationApp,
    Value<String>? customXyzTileUrl,
    Value<String>? customMapLibreStyleUrl,
    Value<bool>? saveVisitPhotoToGallery,
    Value<bool>? autoSaveComparisonToGallery,
    Value<bool>? comparisonShowPilgrimName,
    Value<String>? comparisonPilgrimName,
    Value<String>? customThemeColorName,
    Value<int>? customThemeColorValue,
    Value<String>? customThemeColorsJson,
    Value<double>? customCameraAspectRatioWidth,
    Value<double>? customCameraAspectRatioHeight,
    Value<int>? rowid,
  }) {
    return AppSettingsEntriesCompanion(
      id: id ?? this.id,
      uiScale: uiScale ?? this.uiScale,
      fontScale: fontScale ?? this.fontScale,
      themeMode: themeMode ?? this.themeMode,
      cameraAspectRatio: cameraAspectRatio ?? this.cameraAspectRatio,
      cameraCaptureAspectRatio:
          cameraCaptureAspectRatio ?? this.cameraCaptureAspectRatio,
      cameraMinZoom: cameraMinZoom ?? this.cameraMinZoom,
      cameraMaxZoom: cameraMaxZoom ?? this.cameraMaxZoom,
      referenceImageScale: referenceImageScale ?? this.referenceImageScale,
      nearestAssignDistanceMeters:
          nearestAssignDistanceMeters ?? this.nearestAssignDistanceMeters,
      themePalette: themePalette ?? this.themePalette,
      mapTileProvider: mapTileProvider ?? this.mapTileProvider,
      openFreeMapStyle: openFreeMapStyle ?? this.openFreeMapStyle,
      anitabiImageSource: anitabiImageSource ?? this.anitabiImageSource,
      navigationApp: navigationApp ?? this.navigationApp,
      customXyzTileUrl: customXyzTileUrl ?? this.customXyzTileUrl,
      customMapLibreStyleUrl:
          customMapLibreStyleUrl ?? this.customMapLibreStyleUrl,
      saveVisitPhotoToGallery:
          saveVisitPhotoToGallery ?? this.saveVisitPhotoToGallery,
      autoSaveComparisonToGallery:
          autoSaveComparisonToGallery ?? this.autoSaveComparisonToGallery,
      comparisonShowPilgrimName:
          comparisonShowPilgrimName ?? this.comparisonShowPilgrimName,
      comparisonPilgrimName:
          comparisonPilgrimName ?? this.comparisonPilgrimName,
      customThemeColorName: customThemeColorName ?? this.customThemeColorName,
      customThemeColorValue:
          customThemeColorValue ?? this.customThemeColorValue,
      customThemeColorsJson:
          customThemeColorsJson ?? this.customThemeColorsJson,
      customCameraAspectRatioWidth:
          customCameraAspectRatioWidth ?? this.customCameraAspectRatioWidth,
      customCameraAspectRatioHeight:
          customCameraAspectRatioHeight ?? this.customCameraAspectRatioHeight,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (uiScale.present) {
      map['ui_scale'] = Variable<double>(uiScale.value);
    }
    if (fontScale.present) {
      map['font_scale'] = Variable<double>(fontScale.value);
    }
    if (themeMode.present) {
      map['theme_mode'] = Variable<String>(themeMode.value);
    }
    if (cameraAspectRatio.present) {
      map['camera_aspect_ratio'] = Variable<String>(cameraAspectRatio.value);
    }
    if (cameraCaptureAspectRatio.present) {
      map['camera_capture_aspect_ratio'] = Variable<String>(
        cameraCaptureAspectRatio.value,
      );
    }
    if (cameraMinZoom.present) {
      map['camera_min_zoom'] = Variable<double>(cameraMinZoom.value);
    }
    if (cameraMaxZoom.present) {
      map['camera_max_zoom'] = Variable<double>(cameraMaxZoom.value);
    }
    if (referenceImageScale.present) {
      map['reference_image_scale'] = Variable<double>(
        referenceImageScale.value,
      );
    }
    if (nearestAssignDistanceMeters.present) {
      map['nearest_assign_distance_meters'] = Variable<double>(
        nearestAssignDistanceMeters.value,
      );
    }
    if (themePalette.present) {
      map['theme_palette'] = Variable<String>(themePalette.value);
    }
    if (mapTileProvider.present) {
      map['map_tile_provider'] = Variable<String>(mapTileProvider.value);
    }
    if (openFreeMapStyle.present) {
      map['open_free_map_style'] = Variable<String>(openFreeMapStyle.value);
    }
    if (anitabiImageSource.present) {
      map['anitabi_image_source'] = Variable<String>(anitabiImageSource.value);
    }
    if (navigationApp.present) {
      map['navigation_app'] = Variable<String>(navigationApp.value);
    }
    if (customXyzTileUrl.present) {
      map['custom_xyz_tile_url'] = Variable<String>(customXyzTileUrl.value);
    }
    if (customMapLibreStyleUrl.present) {
      map['custom_map_libre_style_url'] = Variable<String>(
        customMapLibreStyleUrl.value,
      );
    }
    if (saveVisitPhotoToGallery.present) {
      map['save_visit_photo_to_gallery'] = Variable<bool>(
        saveVisitPhotoToGallery.value,
      );
    }
    if (autoSaveComparisonToGallery.present) {
      map['auto_save_comparison_to_gallery'] = Variable<bool>(
        autoSaveComparisonToGallery.value,
      );
    }
    if (comparisonShowPilgrimName.present) {
      map['comparison_show_pilgrim_name'] = Variable<bool>(
        comparisonShowPilgrimName.value,
      );
    }
    if (comparisonPilgrimName.present) {
      map['comparison_pilgrim_name'] = Variable<String>(
        comparisonPilgrimName.value,
      );
    }
    if (customThemeColorName.present) {
      map['custom_theme_color_name'] = Variable<String>(
        customThemeColorName.value,
      );
    }
    if (customThemeColorValue.present) {
      map['custom_theme_color_value'] = Variable<int>(
        customThemeColorValue.value,
      );
    }
    if (customThemeColorsJson.present) {
      map['custom_theme_colors_json'] = Variable<String>(
        customThemeColorsJson.value,
      );
    }
    if (customCameraAspectRatioWidth.present) {
      map['custom_camera_aspect_ratio_width'] = Variable<double>(
        customCameraAspectRatioWidth.value,
      );
    }
    if (customCameraAspectRatioHeight.present) {
      map['custom_camera_aspect_ratio_height'] = Variable<double>(
        customCameraAspectRatioHeight.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsEntriesCompanion(')
          ..write('id: $id, ')
          ..write('uiScale: $uiScale, ')
          ..write('fontScale: $fontScale, ')
          ..write('themeMode: $themeMode, ')
          ..write('cameraAspectRatio: $cameraAspectRatio, ')
          ..write('cameraCaptureAspectRatio: $cameraCaptureAspectRatio, ')
          ..write('cameraMinZoom: $cameraMinZoom, ')
          ..write('cameraMaxZoom: $cameraMaxZoom, ')
          ..write('referenceImageScale: $referenceImageScale, ')
          ..write('nearestAssignDistanceMeters: $nearestAssignDistanceMeters, ')
          ..write('themePalette: $themePalette, ')
          ..write('mapTileProvider: $mapTileProvider, ')
          ..write('openFreeMapStyle: $openFreeMapStyle, ')
          ..write('anitabiImageSource: $anitabiImageSource, ')
          ..write('navigationApp: $navigationApp, ')
          ..write('customXyzTileUrl: $customXyzTileUrl, ')
          ..write('customMapLibreStyleUrl: $customMapLibreStyleUrl, ')
          ..write('saveVisitPhotoToGallery: $saveVisitPhotoToGallery, ')
          ..write('autoSaveComparisonToGallery: $autoSaveComparisonToGallery, ')
          ..write('comparisonShowPilgrimName: $comparisonShowPilgrimName, ')
          ..write('comparisonPilgrimName: $comparisonPilgrimName, ')
          ..write('customThemeColorName: $customThemeColorName, ')
          ..write('customThemeColorValue: $customThemeColorValue, ')
          ..write('customThemeColorsJson: $customThemeColorsJson, ')
          ..write(
            'customCameraAspectRatioWidth: $customCameraAspectRatioWidth, ',
          )
          ..write(
            'customCameraAspectRatioHeight: $customCameraAspectRatioHeight, ',
          )
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PlansTable plans = $PlansTable(this);
  late final $PlanGroupsTable planGroups = $PlanGroupsTable(this);
  late final $WorksTable works = $WorksTable(this);
  late final $PointsTable points = $PointsTable(this);
  late final $VisitRecordsTable visitRecords = $VisitRecordsTable(this);
  late final $AppSettingsEntriesTable appSettingsEntries =
      $AppSettingsEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    plans,
    planGroups,
    works,
    points,
    visitRecords,
    appSettingsEntries,
  ];
}

typedef $$PlansTableCreateCompanionBuilder =
    PlansCompanion Function({
      required String id,
      required String name,
      required String area,
      Value<String?> currentGroupId,
      Value<bool> active,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$PlansTableUpdateCompanionBuilder =
    PlansCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> area,
      Value<String?> currentGroupId,
      Value<bool> active,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$PlansTableReferences
    extends BaseReferences<_$AppDatabase, $PlansTable, Plan> {
  $$PlansTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PlanGroupsTable, List<PlanGroup>>
  _planGroupsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.planGroups,
    aliasName: $_aliasNameGenerator(db.plans.id, db.planGroups.planId),
  );

  $$PlanGroupsTableProcessedTableManager get planGroupsRefs {
    final manager = $$PlanGroupsTableTableManager(
      $_db,
      $_db.planGroups,
    ).filter((f) => f.planId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_planGroupsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$WorksTable, List<Work>> _worksRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.works,
    aliasName: $_aliasNameGenerator(db.plans.id, db.works.planId),
  );

  $$WorksTableProcessedTableManager get worksRefs {
    final manager = $$WorksTableTableManager(
      $_db,
      $_db.works,
    ).filter((f) => f.planId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_worksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PointsTable, List<Point>> _pointsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.points,
    aliasName: $_aliasNameGenerator(db.plans.id, db.points.planId),
  );

  $$PointsTableProcessedTableManager get pointsRefs {
    final manager = $$PointsTableTableManager(
      $_db,
      $_db.points,
    ).filter((f) => f.planId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_pointsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PlansTableFilterComposer extends Composer<_$AppDatabase, $PlansTable> {
  $$PlansTableFilterComposer({
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

  ColumnFilters<String> get area => $composableBuilder(
    column: $table.area,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currentGroupId => $composableBuilder(
    column: $table.currentGroupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> planGroupsRefs(
    Expression<bool> Function($$PlanGroupsTableFilterComposer f) f,
  ) {
    final $$PlanGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.planGroups,
      getReferencedColumn: (t) => t.planId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlanGroupsTableFilterComposer(
            $db: $db,
            $table: $db.planGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> worksRefs(
    Expression<bool> Function($$WorksTableFilterComposer f) f,
  ) {
    final $$WorksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.works,
      getReferencedColumn: (t) => t.planId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorksTableFilterComposer(
            $db: $db,
            $table: $db.works,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> pointsRefs(
    Expression<bool> Function($$PointsTableFilterComposer f) f,
  ) {
    final $$PointsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.points,
      getReferencedColumn: (t) => t.planId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PointsTableFilterComposer(
            $db: $db,
            $table: $db.points,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlansTableOrderingComposer
    extends Composer<_$AppDatabase, $PlansTable> {
  $$PlansTableOrderingComposer({
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

  ColumnOrderings<String> get area => $composableBuilder(
    column: $table.area,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentGroupId => $composableBuilder(
    column: $table.currentGroupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlansTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlansTable> {
  $$PlansTableAnnotationComposer({
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

  GeneratedColumn<String> get area =>
      $composableBuilder(column: $table.area, builder: (column) => column);

  GeneratedColumn<String> get currentGroupId => $composableBuilder(
    column: $table.currentGroupId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> planGroupsRefs<T extends Object>(
    Expression<T> Function($$PlanGroupsTableAnnotationComposer a) f,
  ) {
    final $$PlanGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.planGroups,
      getReferencedColumn: (t) => t.planId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlanGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.planGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> worksRefs<T extends Object>(
    Expression<T> Function($$WorksTableAnnotationComposer a) f,
  ) {
    final $$WorksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.works,
      getReferencedColumn: (t) => t.planId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorksTableAnnotationComposer(
            $db: $db,
            $table: $db.works,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> pointsRefs<T extends Object>(
    Expression<T> Function($$PointsTableAnnotationComposer a) f,
  ) {
    final $$PointsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.points,
      getReferencedColumn: (t) => t.planId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PointsTableAnnotationComposer(
            $db: $db,
            $table: $db.points,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlansTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlansTable,
          Plan,
          $$PlansTableFilterComposer,
          $$PlansTableOrderingComposer,
          $$PlansTableAnnotationComposer,
          $$PlansTableCreateCompanionBuilder,
          $$PlansTableUpdateCompanionBuilder,
          (Plan, $$PlansTableReferences),
          Plan,
          PrefetchHooks Function({
            bool planGroupsRefs,
            bool worksRefs,
            bool pointsRefs,
          })
        > {
  $$PlansTableTableManager(_$AppDatabase db, $PlansTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> area = const Value.absent(),
                Value<String?> currentGroupId = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlansCompanion(
                id: id,
                name: name,
                area: area,
                currentGroupId: currentGroupId,
                active: active,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String area,
                Value<String?> currentGroupId = const Value.absent(),
                Value<bool> active = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PlansCompanion.insert(
                id: id,
                name: name,
                area: area,
                currentGroupId: currentGroupId,
                active: active,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$PlansTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                planGroupsRefs = false,
                worksRefs = false,
                pointsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (planGroupsRefs) db.planGroups,
                    if (worksRefs) db.works,
                    if (pointsRefs) db.points,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (planGroupsRefs)
                        await $_getPrefetchedData<Plan, $PlansTable, PlanGroup>(
                          currentTable: table,
                          referencedTable: $$PlansTableReferences
                              ._planGroupsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlansTableReferences(
                                db,
                                table,
                                p0,
                              ).planGroupsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.planId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (worksRefs)
                        await $_getPrefetchedData<Plan, $PlansTable, Work>(
                          currentTable: table,
                          referencedTable: $$PlansTableReferences
                              ._worksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlansTableReferences(db, table, p0).worksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.planId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (pointsRefs)
                        await $_getPrefetchedData<Plan, $PlansTable, Point>(
                          currentTable: table,
                          referencedTable: $$PlansTableReferences
                              ._pointsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlansTableReferences(db, table, p0).pointsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.planId == item.id,
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

typedef $$PlansTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlansTable,
      Plan,
      $$PlansTableFilterComposer,
      $$PlansTableOrderingComposer,
      $$PlansTableAnnotationComposer,
      $$PlansTableCreateCompanionBuilder,
      $$PlansTableUpdateCompanionBuilder,
      (Plan, $$PlansTableReferences),
      Plan,
      PrefetchHooks Function({
        bool planGroupsRefs,
        bool worksRefs,
        bool pointsRefs,
      })
    >;
typedef $$PlanGroupsTableCreateCompanionBuilder =
    PlanGroupsCompanion Function({
      required String id,
      required String planId,
      required String name,
      Value<int> orderIndex,
      Value<String> orderMode,
      Value<String?> anchorName,
      Value<double?> anchorLatitude,
      Value<double?> anchorLongitude,
      Value<String?> anchorPointId,
      Value<String?> note,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$PlanGroupsTableUpdateCompanionBuilder =
    PlanGroupsCompanion Function({
      Value<String> id,
      Value<String> planId,
      Value<String> name,
      Value<int> orderIndex,
      Value<String> orderMode,
      Value<String?> anchorName,
      Value<double?> anchorLatitude,
      Value<double?> anchorLongitude,
      Value<String?> anchorPointId,
      Value<String?> note,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$PlanGroupsTableReferences
    extends BaseReferences<_$AppDatabase, $PlanGroupsTable, PlanGroup> {
  $$PlanGroupsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PlansTable _planIdTable(_$AppDatabase db) => db.plans.createAlias(
    $_aliasNameGenerator(db.planGroups.planId, db.plans.id),
  );

  $$PlansTableProcessedTableManager get planId {
    final $_column = $_itemColumn<String>('plan_id')!;

    final manager = $$PlansTableTableManager(
      $_db,
      $_db.plans,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_planIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PointsTable, List<Point>> _pointsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.points,
    aliasName: $_aliasNameGenerator(db.planGroups.id, db.points.groupId),
  );

  $$PointsTableProcessedTableManager get pointsRefs {
    final manager = $$PointsTableTableManager(
      $_db,
      $_db.points,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_pointsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PlanGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $PlanGroupsTable> {
  $$PlanGroupsTableFilterComposer({
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

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get orderMode => $composableBuilder(
    column: $table.orderMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get anchorName => $composableBuilder(
    column: $table.anchorName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get anchorLatitude => $composableBuilder(
    column: $table.anchorLatitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get anchorLongitude => $composableBuilder(
    column: $table.anchorLongitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get anchorPointId => $composableBuilder(
    column: $table.anchorPointId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PlansTableFilterComposer get planId {
    final $$PlansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlansTableFilterComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> pointsRefs(
    Expression<bool> Function($$PointsTableFilterComposer f) f,
  ) {
    final $$PointsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.points,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PointsTableFilterComposer(
            $db: $db,
            $table: $db.points,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlanGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlanGroupsTable> {
  $$PlanGroupsTableOrderingComposer({
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

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get orderMode => $composableBuilder(
    column: $table.orderMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get anchorName => $composableBuilder(
    column: $table.anchorName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get anchorLatitude => $composableBuilder(
    column: $table.anchorLatitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get anchorLongitude => $composableBuilder(
    column: $table.anchorLongitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get anchorPointId => $composableBuilder(
    column: $table.anchorPointId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlansTableOrderingComposer get planId {
    final $$PlansTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlansTableOrderingComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlanGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlanGroupsTable> {
  $$PlanGroupsTableAnnotationComposer({
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

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get orderMode =>
      $composableBuilder(column: $table.orderMode, builder: (column) => column);

  GeneratedColumn<String> get anchorName => $composableBuilder(
    column: $table.anchorName,
    builder: (column) => column,
  );

  GeneratedColumn<double> get anchorLatitude => $composableBuilder(
    column: $table.anchorLatitude,
    builder: (column) => column,
  );

  GeneratedColumn<double> get anchorLongitude => $composableBuilder(
    column: $table.anchorLongitude,
    builder: (column) => column,
  );

  GeneratedColumn<String> get anchorPointId => $composableBuilder(
    column: $table.anchorPointId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$PlansTableAnnotationComposer get planId {
    final $$PlansTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlansTableAnnotationComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> pointsRefs<T extends Object>(
    Expression<T> Function($$PointsTableAnnotationComposer a) f,
  ) {
    final $$PointsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.points,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PointsTableAnnotationComposer(
            $db: $db,
            $table: $db.points,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlanGroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlanGroupsTable,
          PlanGroup,
          $$PlanGroupsTableFilterComposer,
          $$PlanGroupsTableOrderingComposer,
          $$PlanGroupsTableAnnotationComposer,
          $$PlanGroupsTableCreateCompanionBuilder,
          $$PlanGroupsTableUpdateCompanionBuilder,
          (PlanGroup, $$PlanGroupsTableReferences),
          PlanGroup,
          PrefetchHooks Function({bool planId, bool pointsRefs})
        > {
  $$PlanGroupsTableTableManager(_$AppDatabase db, $PlanGroupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlanGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlanGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlanGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> planId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<String> orderMode = const Value.absent(),
                Value<String?> anchorName = const Value.absent(),
                Value<double?> anchorLatitude = const Value.absent(),
                Value<double?> anchorLongitude = const Value.absent(),
                Value<String?> anchorPointId = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlanGroupsCompanion(
                id: id,
                planId: planId,
                name: name,
                orderIndex: orderIndex,
                orderMode: orderMode,
                anchorName: anchorName,
                anchorLatitude: anchorLatitude,
                anchorLongitude: anchorLongitude,
                anchorPointId: anchorPointId,
                note: note,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String planId,
                required String name,
                Value<int> orderIndex = const Value.absent(),
                Value<String> orderMode = const Value.absent(),
                Value<String?> anchorName = const Value.absent(),
                Value<double?> anchorLatitude = const Value.absent(),
                Value<double?> anchorLongitude = const Value.absent(),
                Value<String?> anchorPointId = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => PlanGroupsCompanion.insert(
                id: id,
                planId: planId,
                name: name,
                orderIndex: orderIndex,
                orderMode: orderMode,
                anchorName: anchorName,
                anchorLatitude: anchorLatitude,
                anchorLongitude: anchorLongitude,
                anchorPointId: anchorPointId,
                note: note,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PlanGroupsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({planId = false, pointsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (pointsRefs) db.points],
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
                    if (planId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.planId,
                                referencedTable: $$PlanGroupsTableReferences
                                    ._planIdTable(db),
                                referencedColumn: $$PlanGroupsTableReferences
                                    ._planIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (pointsRefs)
                    await $_getPrefetchedData<
                      PlanGroup,
                      $PlanGroupsTable,
                      Point
                    >(
                      currentTable: table,
                      referencedTable: $$PlanGroupsTableReferences
                          ._pointsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PlanGroupsTableReferences(db, table, p0).pointsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.groupId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PlanGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlanGroupsTable,
      PlanGroup,
      $$PlanGroupsTableFilterComposer,
      $$PlanGroupsTableOrderingComposer,
      $$PlanGroupsTableAnnotationComposer,
      $$PlanGroupsTableCreateCompanionBuilder,
      $$PlanGroupsTableUpdateCompanionBuilder,
      (PlanGroup, $$PlanGroupsTableReferences),
      PlanGroup,
      PrefetchHooks Function({bool planId, bool pointsRefs})
    >;
typedef $$WorksTableCreateCompanionBuilder =
    WorksCompanion Function({
      required String id,
      required String planId,
      Value<int?> bangumiId,
      required String title,
      required String subtitle,
      required String city,
      required String source,
      Value<int> rowid,
    });
typedef $$WorksTableUpdateCompanionBuilder =
    WorksCompanion Function({
      Value<String> id,
      Value<String> planId,
      Value<int?> bangumiId,
      Value<String> title,
      Value<String> subtitle,
      Value<String> city,
      Value<String> source,
      Value<int> rowid,
    });

final class $$WorksTableReferences
    extends BaseReferences<_$AppDatabase, $WorksTable, Work> {
  $$WorksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PlansTable _planIdTable(_$AppDatabase db) =>
      db.plans.createAlias($_aliasNameGenerator(db.works.planId, db.plans.id));

  $$PlansTableProcessedTableManager get planId {
    final $_column = $_itemColumn<String>('plan_id')!;

    final manager = $$PlansTableTableManager(
      $_db,
      $_db.plans,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_planIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PointsTable, List<Point>> _pointsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.points,
    aliasName: $_aliasNameGenerator(db.works.id, db.points.workId),
  );

  $$PointsTableProcessedTableManager get pointsRefs {
    final manager = $$PointsTableTableManager(
      $_db,
      $_db.points,
    ).filter((f) => f.workId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_pointsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WorksTableFilterComposer extends Composer<_$AppDatabase, $WorksTable> {
  $$WorksTableFilterComposer({
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

  ColumnFilters<int> get bangumiId => $composableBuilder(
    column: $table.bangumiId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subtitle => $composableBuilder(
    column: $table.subtitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  $$PlansTableFilterComposer get planId {
    final $$PlansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlansTableFilterComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> pointsRefs(
    Expression<bool> Function($$PointsTableFilterComposer f) f,
  ) {
    final $$PointsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.points,
      getReferencedColumn: (t) => t.workId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PointsTableFilterComposer(
            $db: $db,
            $table: $db.points,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorksTableOrderingComposer
    extends Composer<_$AppDatabase, $WorksTable> {
  $$WorksTableOrderingComposer({
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

  ColumnOrderings<int> get bangumiId => $composableBuilder(
    column: $table.bangumiId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subtitle => $composableBuilder(
    column: $table.subtitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlansTableOrderingComposer get planId {
    final $$PlansTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlansTableOrderingComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorksTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorksTable> {
  $$WorksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get bangumiId =>
      $composableBuilder(column: $table.bangumiId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get subtitle =>
      $composableBuilder(column: $table.subtitle, builder: (column) => column);

  GeneratedColumn<String> get city =>
      $composableBuilder(column: $table.city, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  $$PlansTableAnnotationComposer get planId {
    final $$PlansTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlansTableAnnotationComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> pointsRefs<T extends Object>(
    Expression<T> Function($$PointsTableAnnotationComposer a) f,
  ) {
    final $$PointsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.points,
      getReferencedColumn: (t) => t.workId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PointsTableAnnotationComposer(
            $db: $db,
            $table: $db.points,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorksTable,
          Work,
          $$WorksTableFilterComposer,
          $$WorksTableOrderingComposer,
          $$WorksTableAnnotationComposer,
          $$WorksTableCreateCompanionBuilder,
          $$WorksTableUpdateCompanionBuilder,
          (Work, $$WorksTableReferences),
          Work,
          PrefetchHooks Function({bool planId, bool pointsRefs})
        > {
  $$WorksTableTableManager(_$AppDatabase db, $WorksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> planId = const Value.absent(),
                Value<int?> bangumiId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> subtitle = const Value.absent(),
                Value<String> city = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorksCompanion(
                id: id,
                planId: planId,
                bangumiId: bangumiId,
                title: title,
                subtitle: subtitle,
                city: city,
                source: source,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String planId,
                Value<int?> bangumiId = const Value.absent(),
                required String title,
                required String subtitle,
                required String city,
                required String source,
                Value<int> rowid = const Value.absent(),
              }) => WorksCompanion.insert(
                id: id,
                planId: planId,
                bangumiId: bangumiId,
                title: title,
                subtitle: subtitle,
                city: city,
                source: source,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$WorksTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({planId = false, pointsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (pointsRefs) db.points],
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
                    if (planId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.planId,
                                referencedTable: $$WorksTableReferences
                                    ._planIdTable(db),
                                referencedColumn: $$WorksTableReferences
                                    ._planIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (pointsRefs)
                    await $_getPrefetchedData<Work, $WorksTable, Point>(
                      currentTable: table,
                      referencedTable: $$WorksTableReferences._pointsRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$WorksTableReferences(db, table, p0).pointsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.workId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$WorksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorksTable,
      Work,
      $$WorksTableFilterComposer,
      $$WorksTableOrderingComposer,
      $$WorksTableAnnotationComposer,
      $$WorksTableCreateCompanionBuilder,
      $$WorksTableUpdateCompanionBuilder,
      (Work, $$WorksTableReferences),
      Work,
      PrefetchHooks Function({bool planId, bool pointsRefs})
    >;
typedef $$PointsTableCreateCompanionBuilder =
    PointsCompanion Function({
      required String id,
      required String planId,
      required String workId,
      required String name,
      required String subtitle,
      required double latitude,
      required double longitude,
      required String episodeLabel,
      required String referenceLabel,
      required String source,
      Value<String?> sourceId,
      Value<String?> referenceImageUrl,
      Value<String?> referenceThumbnailPath,
      Value<String?> referenceFullImagePath,
      Value<String?> sourceUrl,
      Value<String?> note,
      Value<String?> groupId,
      Value<int?> groupOrderIndex,
      Value<int> sortOrder,
      Value<bool> isCurrent,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });
typedef $$PointsTableUpdateCompanionBuilder =
    PointsCompanion Function({
      Value<String> id,
      Value<String> planId,
      Value<String> workId,
      Value<String> name,
      Value<String> subtitle,
      Value<double> latitude,
      Value<double> longitude,
      Value<String> episodeLabel,
      Value<String> referenceLabel,
      Value<String> source,
      Value<String?> sourceId,
      Value<String?> referenceImageUrl,
      Value<String?> referenceThumbnailPath,
      Value<String?> referenceFullImagePath,
      Value<String?> sourceUrl,
      Value<String?> note,
      Value<String?> groupId,
      Value<int?> groupOrderIndex,
      Value<int> sortOrder,
      Value<bool> isCurrent,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });

final class $$PointsTableReferences
    extends BaseReferences<_$AppDatabase, $PointsTable, Point> {
  $$PointsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PlansTable _planIdTable(_$AppDatabase db) =>
      db.plans.createAlias($_aliasNameGenerator(db.points.planId, db.plans.id));

  $$PlansTableProcessedTableManager get planId {
    final $_column = $_itemColumn<String>('plan_id')!;

    final manager = $$PlansTableTableManager(
      $_db,
      $_db.plans,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_planIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $WorksTable _workIdTable(_$AppDatabase db) =>
      db.works.createAlias($_aliasNameGenerator(db.points.workId, db.works.id));

  $$WorksTableProcessedTableManager get workId {
    final $_column = $_itemColumn<String>('work_id')!;

    final manager = $$WorksTableTableManager(
      $_db,
      $_db.works,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_workIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PlanGroupsTable _groupIdTable(_$AppDatabase db) => db.planGroups
      .createAlias($_aliasNameGenerator(db.points.groupId, db.planGroups.id));

  $$PlanGroupsTableProcessedTableManager? get groupId {
    final $_column = $_itemColumn<String>('group_id');
    if ($_column == null) return null;
    final manager = $$PlanGroupsTableTableManager(
      $_db,
      $_db.planGroups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PointsTableFilterComposer
    extends Composer<_$AppDatabase, $PointsTable> {
  $$PointsTableFilterComposer({
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

  ColumnFilters<String> get subtitle => $composableBuilder(
    column: $table.subtitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get episodeLabel => $composableBuilder(
    column: $table.episodeLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get referenceLabel => $composableBuilder(
    column: $table.referenceLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get referenceImageUrl => $composableBuilder(
    column: $table.referenceImageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get referenceThumbnailPath => $composableBuilder(
    column: $table.referenceThumbnailPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get referenceFullImagePath => $composableBuilder(
    column: $table.referenceFullImagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get groupOrderIndex => $composableBuilder(
    column: $table.groupOrderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCurrent => $composableBuilder(
    column: $table.isCurrent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PlansTableFilterComposer get planId {
    final $$PlansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlansTableFilterComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorksTableFilterComposer get workId {
    final $$WorksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workId,
      referencedTable: $db.works,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorksTableFilterComposer(
            $db: $db,
            $table: $db.works,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlanGroupsTableFilterComposer get groupId {
    final $$PlanGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.planGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlanGroupsTableFilterComposer(
            $db: $db,
            $table: $db.planGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PointsTableOrderingComposer
    extends Composer<_$AppDatabase, $PointsTable> {
  $$PointsTableOrderingComposer({
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

  ColumnOrderings<String> get subtitle => $composableBuilder(
    column: $table.subtitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get episodeLabel => $composableBuilder(
    column: $table.episodeLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get referenceLabel => $composableBuilder(
    column: $table.referenceLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get referenceImageUrl => $composableBuilder(
    column: $table.referenceImageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get referenceThumbnailPath => $composableBuilder(
    column: $table.referenceThumbnailPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get referenceFullImagePath => $composableBuilder(
    column: $table.referenceFullImagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get groupOrderIndex => $composableBuilder(
    column: $table.groupOrderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCurrent => $composableBuilder(
    column: $table.isCurrent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlansTableOrderingComposer get planId {
    final $$PlansTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlansTableOrderingComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorksTableOrderingComposer get workId {
    final $$WorksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workId,
      referencedTable: $db.works,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorksTableOrderingComposer(
            $db: $db,
            $table: $db.works,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlanGroupsTableOrderingComposer get groupId {
    final $$PlanGroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.planGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlanGroupsTableOrderingComposer(
            $db: $db,
            $table: $db.planGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PointsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PointsTable> {
  $$PointsTableAnnotationComposer({
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

  GeneratedColumn<String> get subtitle =>
      $composableBuilder(column: $table.subtitle, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<String> get episodeLabel => $composableBuilder(
    column: $table.episodeLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get referenceLabel => $composableBuilder(
    column: $table.referenceLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get referenceImageUrl => $composableBuilder(
    column: $table.referenceImageUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get referenceThumbnailPath => $composableBuilder(
    column: $table.referenceThumbnailPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get referenceFullImagePath => $composableBuilder(
    column: $table.referenceFullImagePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get groupOrderIndex => $composableBuilder(
    column: $table.groupOrderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get isCurrent =>
      $composableBuilder(column: $table.isCurrent, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  $$PlansTableAnnotationComposer get planId {
    final $$PlansTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlansTableAnnotationComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorksTableAnnotationComposer get workId {
    final $$WorksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workId,
      referencedTable: $db.works,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorksTableAnnotationComposer(
            $db: $db,
            $table: $db.works,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlanGroupsTableAnnotationComposer get groupId {
    final $$PlanGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.planGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlanGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.planGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PointsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PointsTable,
          Point,
          $$PointsTableFilterComposer,
          $$PointsTableOrderingComposer,
          $$PointsTableAnnotationComposer,
          $$PointsTableCreateCompanionBuilder,
          $$PointsTableUpdateCompanionBuilder,
          (Point, $$PointsTableReferences),
          Point,
          PrefetchHooks Function({bool planId, bool workId, bool groupId})
        > {
  $$PointsTableTableManager(_$AppDatabase db, $PointsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PointsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> planId = const Value.absent(),
                Value<String> workId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> subtitle = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<String> episodeLabel = const Value.absent(),
                Value<String> referenceLabel = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> sourceId = const Value.absent(),
                Value<String?> referenceImageUrl = const Value.absent(),
                Value<String?> referenceThumbnailPath = const Value.absent(),
                Value<String?> referenceFullImagePath = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<int?> groupOrderIndex = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isCurrent = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PointsCompanion(
                id: id,
                planId: planId,
                workId: workId,
                name: name,
                subtitle: subtitle,
                latitude: latitude,
                longitude: longitude,
                episodeLabel: episodeLabel,
                referenceLabel: referenceLabel,
                source: source,
                sourceId: sourceId,
                referenceImageUrl: referenceImageUrl,
                referenceThumbnailPath: referenceThumbnailPath,
                referenceFullImagePath: referenceFullImagePath,
                sourceUrl: sourceUrl,
                note: note,
                groupId: groupId,
                groupOrderIndex: groupOrderIndex,
                sortOrder: sortOrder,
                isCurrent: isCurrent,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String planId,
                required String workId,
                required String name,
                required String subtitle,
                required double latitude,
                required double longitude,
                required String episodeLabel,
                required String referenceLabel,
                required String source,
                Value<String?> sourceId = const Value.absent(),
                Value<String?> referenceImageUrl = const Value.absent(),
                Value<String?> referenceThumbnailPath = const Value.absent(),
                Value<String?> referenceFullImagePath = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<int?> groupOrderIndex = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isCurrent = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PointsCompanion.insert(
                id: id,
                planId: planId,
                workId: workId,
                name: name,
                subtitle: subtitle,
                latitude: latitude,
                longitude: longitude,
                episodeLabel: episodeLabel,
                referenceLabel: referenceLabel,
                source: source,
                sourceId: sourceId,
                referenceImageUrl: referenceImageUrl,
                referenceThumbnailPath: referenceThumbnailPath,
                referenceFullImagePath: referenceFullImagePath,
                sourceUrl: sourceUrl,
                note: note,
                groupId: groupId,
                groupOrderIndex: groupOrderIndex,
                sortOrder: sortOrder,
                isCurrent: isCurrent,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$PointsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({planId = false, workId = false, groupId = false}) {
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
                        if (planId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.planId,
                                    referencedTable: $$PointsTableReferences
                                        ._planIdTable(db),
                                    referencedColumn: $$PointsTableReferences
                                        ._planIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (workId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.workId,
                                    referencedTable: $$PointsTableReferences
                                        ._workIdTable(db),
                                    referencedColumn: $$PointsTableReferences
                                        ._workIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (groupId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.groupId,
                                    referencedTable: $$PointsTableReferences
                                        ._groupIdTable(db),
                                    referencedColumn: $$PointsTableReferences
                                        ._groupIdTable(db)
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

typedef $$PointsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PointsTable,
      Point,
      $$PointsTableFilterComposer,
      $$PointsTableOrderingComposer,
      $$PointsTableAnnotationComposer,
      $$PointsTableCreateCompanionBuilder,
      $$PointsTableUpdateCompanionBuilder,
      (Point, $$PointsTableReferences),
      Point,
      PrefetchHooks Function({bool planId, bool workId, bool groupId})
    >;
typedef $$VisitRecordsTableCreateCompanionBuilder =
    VisitRecordsCompanion Function({
      required String id,
      required String planId,
      required String pointId,
      required String workId,
      Value<String?> workTitle,
      Value<String?> workSubtitle,
      Value<String?> pointName,
      Value<String?> pointSubtitle,
      required String photoPath,
      Value<String?> originalPhotoPath,
      Value<String?> gradedPhotoPath,
      Value<String?> colorGradingMode,
      Value<String?> colorGradingParamsJson,
      Value<double?> colorGradingIntensity,
      Value<String?> referenceImagePath,
      Value<String?> referenceImageUrl,
      required String referenceMode,
      required DateTime capturedAt,
      Value<int> rowid,
    });
typedef $$VisitRecordsTableUpdateCompanionBuilder =
    VisitRecordsCompanion Function({
      Value<String> id,
      Value<String> planId,
      Value<String> pointId,
      Value<String> workId,
      Value<String?> workTitle,
      Value<String?> workSubtitle,
      Value<String?> pointName,
      Value<String?> pointSubtitle,
      Value<String> photoPath,
      Value<String?> originalPhotoPath,
      Value<String?> gradedPhotoPath,
      Value<String?> colorGradingMode,
      Value<String?> colorGradingParamsJson,
      Value<double?> colorGradingIntensity,
      Value<String?> referenceImagePath,
      Value<String?> referenceImageUrl,
      Value<String> referenceMode,
      Value<DateTime> capturedAt,
      Value<int> rowid,
    });

class $$VisitRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $VisitRecordsTable> {
  $$VisitRecordsTableFilterComposer({
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

  ColumnFilters<String> get planId => $composableBuilder(
    column: $table.planId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pointId => $composableBuilder(
    column: $table.pointId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workId => $composableBuilder(
    column: $table.workId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workTitle => $composableBuilder(
    column: $table.workTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workSubtitle => $composableBuilder(
    column: $table.workSubtitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pointName => $composableBuilder(
    column: $table.pointName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pointSubtitle => $composableBuilder(
    column: $table.pointSubtitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalPhotoPath => $composableBuilder(
    column: $table.originalPhotoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gradedPhotoPath => $composableBuilder(
    column: $table.gradedPhotoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorGradingMode => $composableBuilder(
    column: $table.colorGradingMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorGradingParamsJson => $composableBuilder(
    column: $table.colorGradingParamsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get colorGradingIntensity => $composableBuilder(
    column: $table.colorGradingIntensity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get referenceImagePath => $composableBuilder(
    column: $table.referenceImagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get referenceImageUrl => $composableBuilder(
    column: $table.referenceImageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get referenceMode => $composableBuilder(
    column: $table.referenceMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VisitRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $VisitRecordsTable> {
  $$VisitRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get planId => $composableBuilder(
    column: $table.planId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pointId => $composableBuilder(
    column: $table.pointId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workId => $composableBuilder(
    column: $table.workId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workTitle => $composableBuilder(
    column: $table.workTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workSubtitle => $composableBuilder(
    column: $table.workSubtitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pointName => $composableBuilder(
    column: $table.pointName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pointSubtitle => $composableBuilder(
    column: $table.pointSubtitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalPhotoPath => $composableBuilder(
    column: $table.originalPhotoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gradedPhotoPath => $composableBuilder(
    column: $table.gradedPhotoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorGradingMode => $composableBuilder(
    column: $table.colorGradingMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorGradingParamsJson => $composableBuilder(
    column: $table.colorGradingParamsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get colorGradingIntensity => $composableBuilder(
    column: $table.colorGradingIntensity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get referenceImagePath => $composableBuilder(
    column: $table.referenceImagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get referenceImageUrl => $composableBuilder(
    column: $table.referenceImageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get referenceMode => $composableBuilder(
    column: $table.referenceMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VisitRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $VisitRecordsTable> {
  $$VisitRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get planId =>
      $composableBuilder(column: $table.planId, builder: (column) => column);

  GeneratedColumn<String> get pointId =>
      $composableBuilder(column: $table.pointId, builder: (column) => column);

  GeneratedColumn<String> get workId =>
      $composableBuilder(column: $table.workId, builder: (column) => column);

  GeneratedColumn<String> get workTitle =>
      $composableBuilder(column: $table.workTitle, builder: (column) => column);

  GeneratedColumn<String> get workSubtitle => $composableBuilder(
    column: $table.workSubtitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pointName =>
      $composableBuilder(column: $table.pointName, builder: (column) => column);

  GeneratedColumn<String> get pointSubtitle => $composableBuilder(
    column: $table.pointSubtitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get photoPath =>
      $composableBuilder(column: $table.photoPath, builder: (column) => column);

  GeneratedColumn<String> get originalPhotoPath => $composableBuilder(
    column: $table.originalPhotoPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get gradedPhotoPath => $composableBuilder(
    column: $table.gradedPhotoPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get colorGradingMode => $composableBuilder(
    column: $table.colorGradingMode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get colorGradingParamsJson => $composableBuilder(
    column: $table.colorGradingParamsJson,
    builder: (column) => column,
  );

  GeneratedColumn<double> get colorGradingIntensity => $composableBuilder(
    column: $table.colorGradingIntensity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get referenceImagePath => $composableBuilder(
    column: $table.referenceImagePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get referenceImageUrl => $composableBuilder(
    column: $table.referenceImageUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get referenceMode => $composableBuilder(
    column: $table.referenceMode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => column,
  );
}

class $$VisitRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VisitRecordsTable,
          VisitRecord,
          $$VisitRecordsTableFilterComposer,
          $$VisitRecordsTableOrderingComposer,
          $$VisitRecordsTableAnnotationComposer,
          $$VisitRecordsTableCreateCompanionBuilder,
          $$VisitRecordsTableUpdateCompanionBuilder,
          (
            VisitRecord,
            BaseReferences<_$AppDatabase, $VisitRecordsTable, VisitRecord>,
          ),
          VisitRecord,
          PrefetchHooks Function()
        > {
  $$VisitRecordsTableTableManager(_$AppDatabase db, $VisitRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VisitRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VisitRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VisitRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> planId = const Value.absent(),
                Value<String> pointId = const Value.absent(),
                Value<String> workId = const Value.absent(),
                Value<String?> workTitle = const Value.absent(),
                Value<String?> workSubtitle = const Value.absent(),
                Value<String?> pointName = const Value.absent(),
                Value<String?> pointSubtitle = const Value.absent(),
                Value<String> photoPath = const Value.absent(),
                Value<String?> originalPhotoPath = const Value.absent(),
                Value<String?> gradedPhotoPath = const Value.absent(),
                Value<String?> colorGradingMode = const Value.absent(),
                Value<String?> colorGradingParamsJson = const Value.absent(),
                Value<double?> colorGradingIntensity = const Value.absent(),
                Value<String?> referenceImagePath = const Value.absent(),
                Value<String?> referenceImageUrl = const Value.absent(),
                Value<String> referenceMode = const Value.absent(),
                Value<DateTime> capturedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VisitRecordsCompanion(
                id: id,
                planId: planId,
                pointId: pointId,
                workId: workId,
                workTitle: workTitle,
                workSubtitle: workSubtitle,
                pointName: pointName,
                pointSubtitle: pointSubtitle,
                photoPath: photoPath,
                originalPhotoPath: originalPhotoPath,
                gradedPhotoPath: gradedPhotoPath,
                colorGradingMode: colorGradingMode,
                colorGradingParamsJson: colorGradingParamsJson,
                colorGradingIntensity: colorGradingIntensity,
                referenceImagePath: referenceImagePath,
                referenceImageUrl: referenceImageUrl,
                referenceMode: referenceMode,
                capturedAt: capturedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String planId,
                required String pointId,
                required String workId,
                Value<String?> workTitle = const Value.absent(),
                Value<String?> workSubtitle = const Value.absent(),
                Value<String?> pointName = const Value.absent(),
                Value<String?> pointSubtitle = const Value.absent(),
                required String photoPath,
                Value<String?> originalPhotoPath = const Value.absent(),
                Value<String?> gradedPhotoPath = const Value.absent(),
                Value<String?> colorGradingMode = const Value.absent(),
                Value<String?> colorGradingParamsJson = const Value.absent(),
                Value<double?> colorGradingIntensity = const Value.absent(),
                Value<String?> referenceImagePath = const Value.absent(),
                Value<String?> referenceImageUrl = const Value.absent(),
                required String referenceMode,
                required DateTime capturedAt,
                Value<int> rowid = const Value.absent(),
              }) => VisitRecordsCompanion.insert(
                id: id,
                planId: planId,
                pointId: pointId,
                workId: workId,
                workTitle: workTitle,
                workSubtitle: workSubtitle,
                pointName: pointName,
                pointSubtitle: pointSubtitle,
                photoPath: photoPath,
                originalPhotoPath: originalPhotoPath,
                gradedPhotoPath: gradedPhotoPath,
                colorGradingMode: colorGradingMode,
                colorGradingParamsJson: colorGradingParamsJson,
                colorGradingIntensity: colorGradingIntensity,
                referenceImagePath: referenceImagePath,
                referenceImageUrl: referenceImageUrl,
                referenceMode: referenceMode,
                capturedAt: capturedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VisitRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VisitRecordsTable,
      VisitRecord,
      $$VisitRecordsTableFilterComposer,
      $$VisitRecordsTableOrderingComposer,
      $$VisitRecordsTableAnnotationComposer,
      $$VisitRecordsTableCreateCompanionBuilder,
      $$VisitRecordsTableUpdateCompanionBuilder,
      (
        VisitRecord,
        BaseReferences<_$AppDatabase, $VisitRecordsTable, VisitRecord>,
      ),
      VisitRecord,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsEntriesTableCreateCompanionBuilder =
    AppSettingsEntriesCompanion Function({
      required String id,
      Value<double> uiScale,
      Value<double> fontScale,
      Value<String> themeMode,
      Value<String> cameraAspectRatio,
      Value<String> cameraCaptureAspectRatio,
      Value<double> cameraMinZoom,
      Value<double> cameraMaxZoom,
      Value<double> referenceImageScale,
      Value<double> nearestAssignDistanceMeters,
      Value<String> themePalette,
      Value<String> mapTileProvider,
      Value<String> openFreeMapStyle,
      Value<String> anitabiImageSource,
      Value<String> navigationApp,
      Value<String> customXyzTileUrl,
      Value<String> customMapLibreStyleUrl,
      Value<bool> saveVisitPhotoToGallery,
      Value<bool> autoSaveComparisonToGallery,
      Value<bool> comparisonShowPilgrimName,
      Value<String> comparisonPilgrimName,
      Value<String> customThemeColorName,
      Value<int> customThemeColorValue,
      Value<String> customThemeColorsJson,
      Value<double> customCameraAspectRatioWidth,
      Value<double> customCameraAspectRatioHeight,
      Value<int> rowid,
    });
typedef $$AppSettingsEntriesTableUpdateCompanionBuilder =
    AppSettingsEntriesCompanion Function({
      Value<String> id,
      Value<double> uiScale,
      Value<double> fontScale,
      Value<String> themeMode,
      Value<String> cameraAspectRatio,
      Value<String> cameraCaptureAspectRatio,
      Value<double> cameraMinZoom,
      Value<double> cameraMaxZoom,
      Value<double> referenceImageScale,
      Value<double> nearestAssignDistanceMeters,
      Value<String> themePalette,
      Value<String> mapTileProvider,
      Value<String> openFreeMapStyle,
      Value<String> anitabiImageSource,
      Value<String> navigationApp,
      Value<String> customXyzTileUrl,
      Value<String> customMapLibreStyleUrl,
      Value<bool> saveVisitPhotoToGallery,
      Value<bool> autoSaveComparisonToGallery,
      Value<bool> comparisonShowPilgrimName,
      Value<String> comparisonPilgrimName,
      Value<String> customThemeColorName,
      Value<int> customThemeColorValue,
      Value<String> customThemeColorsJson,
      Value<double> customCameraAspectRatioWidth,
      Value<double> customCameraAspectRatioHeight,
      Value<int> rowid,
    });

class $$AppSettingsEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsEntriesTable> {
  $$AppSettingsEntriesTableFilterComposer({
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

  ColumnFilters<double> get uiScale => $composableBuilder(
    column: $table.uiScale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fontScale => $composableBuilder(
    column: $table.fontScale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cameraAspectRatio => $composableBuilder(
    column: $table.cameraAspectRatio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cameraCaptureAspectRatio => $composableBuilder(
    column: $table.cameraCaptureAspectRatio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get cameraMinZoom => $composableBuilder(
    column: $table.cameraMinZoom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get cameraMaxZoom => $composableBuilder(
    column: $table.cameraMaxZoom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get referenceImageScale => $composableBuilder(
    column: $table.referenceImageScale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get nearestAssignDistanceMeters => $composableBuilder(
    column: $table.nearestAssignDistanceMeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get themePalette => $composableBuilder(
    column: $table.themePalette,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mapTileProvider => $composableBuilder(
    column: $table.mapTileProvider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get openFreeMapStyle => $composableBuilder(
    column: $table.openFreeMapStyle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get anitabiImageSource => $composableBuilder(
    column: $table.anitabiImageSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get navigationApp => $composableBuilder(
    column: $table.navigationApp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customXyzTileUrl => $composableBuilder(
    column: $table.customXyzTileUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customMapLibreStyleUrl => $composableBuilder(
    column: $table.customMapLibreStyleUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get saveVisitPhotoToGallery => $composableBuilder(
    column: $table.saveVisitPhotoToGallery,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoSaveComparisonToGallery => $composableBuilder(
    column: $table.autoSaveComparisonToGallery,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get comparisonShowPilgrimName => $composableBuilder(
    column: $table.comparisonShowPilgrimName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comparisonPilgrimName => $composableBuilder(
    column: $table.comparisonPilgrimName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customThemeColorName => $composableBuilder(
    column: $table.customThemeColorName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get customThemeColorValue => $composableBuilder(
    column: $table.customThemeColorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customThemeColorsJson => $composableBuilder(
    column: $table.customThemeColorsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get customCameraAspectRatioWidth => $composableBuilder(
    column: $table.customCameraAspectRatioWidth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get customCameraAspectRatioHeight => $composableBuilder(
    column: $table.customCameraAspectRatioHeight,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsEntriesTable> {
  $$AppSettingsEntriesTableOrderingComposer({
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

  ColumnOrderings<double> get uiScale => $composableBuilder(
    column: $table.uiScale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fontScale => $composableBuilder(
    column: $table.fontScale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cameraAspectRatio => $composableBuilder(
    column: $table.cameraAspectRatio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cameraCaptureAspectRatio => $composableBuilder(
    column: $table.cameraCaptureAspectRatio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get cameraMinZoom => $composableBuilder(
    column: $table.cameraMinZoom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get cameraMaxZoom => $composableBuilder(
    column: $table.cameraMaxZoom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get referenceImageScale => $composableBuilder(
    column: $table.referenceImageScale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get nearestAssignDistanceMeters => $composableBuilder(
    column: $table.nearestAssignDistanceMeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themePalette => $composableBuilder(
    column: $table.themePalette,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mapTileProvider => $composableBuilder(
    column: $table.mapTileProvider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get openFreeMapStyle => $composableBuilder(
    column: $table.openFreeMapStyle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get anitabiImageSource => $composableBuilder(
    column: $table.anitabiImageSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get navigationApp => $composableBuilder(
    column: $table.navigationApp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customXyzTileUrl => $composableBuilder(
    column: $table.customXyzTileUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customMapLibreStyleUrl => $composableBuilder(
    column: $table.customMapLibreStyleUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get saveVisitPhotoToGallery => $composableBuilder(
    column: $table.saveVisitPhotoToGallery,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoSaveComparisonToGallery => $composableBuilder(
    column: $table.autoSaveComparisonToGallery,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get comparisonShowPilgrimName => $composableBuilder(
    column: $table.comparisonShowPilgrimName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comparisonPilgrimName => $composableBuilder(
    column: $table.comparisonPilgrimName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customThemeColorName => $composableBuilder(
    column: $table.customThemeColorName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get customThemeColorValue => $composableBuilder(
    column: $table.customThemeColorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customThemeColorsJson => $composableBuilder(
    column: $table.customThemeColorsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get customCameraAspectRatioWidth =>
      $composableBuilder(
        column: $table.customCameraAspectRatioWidth,
        builder: (column) => ColumnOrderings(column),
      );

  ColumnOrderings<double> get customCameraAspectRatioHeight =>
      $composableBuilder(
        column: $table.customCameraAspectRatioHeight,
        builder: (column) => ColumnOrderings(column),
      );
}

class $$AppSettingsEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsEntriesTable> {
  $$AppSettingsEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get uiScale =>
      $composableBuilder(column: $table.uiScale, builder: (column) => column);

  GeneratedColumn<double> get fontScale =>
      $composableBuilder(column: $table.fontScale, builder: (column) => column);

  GeneratedColumn<String> get themeMode =>
      $composableBuilder(column: $table.themeMode, builder: (column) => column);

  GeneratedColumn<String> get cameraAspectRatio => $composableBuilder(
    column: $table.cameraAspectRatio,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cameraCaptureAspectRatio => $composableBuilder(
    column: $table.cameraCaptureAspectRatio,
    builder: (column) => column,
  );

  GeneratedColumn<double> get cameraMinZoom => $composableBuilder(
    column: $table.cameraMinZoom,
    builder: (column) => column,
  );

  GeneratedColumn<double> get cameraMaxZoom => $composableBuilder(
    column: $table.cameraMaxZoom,
    builder: (column) => column,
  );

  GeneratedColumn<double> get referenceImageScale => $composableBuilder(
    column: $table.referenceImageScale,
    builder: (column) => column,
  );

  GeneratedColumn<double> get nearestAssignDistanceMeters => $composableBuilder(
    column: $table.nearestAssignDistanceMeters,
    builder: (column) => column,
  );

  GeneratedColumn<String> get themePalette => $composableBuilder(
    column: $table.themePalette,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mapTileProvider => $composableBuilder(
    column: $table.mapTileProvider,
    builder: (column) => column,
  );

  GeneratedColumn<String> get openFreeMapStyle => $composableBuilder(
    column: $table.openFreeMapStyle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get anitabiImageSource => $composableBuilder(
    column: $table.anitabiImageSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get navigationApp => $composableBuilder(
    column: $table.navigationApp,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customXyzTileUrl => $composableBuilder(
    column: $table.customXyzTileUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customMapLibreStyleUrl => $composableBuilder(
    column: $table.customMapLibreStyleUrl,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get saveVisitPhotoToGallery => $composableBuilder(
    column: $table.saveVisitPhotoToGallery,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get autoSaveComparisonToGallery => $composableBuilder(
    column: $table.autoSaveComparisonToGallery,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get comparisonShowPilgrimName => $composableBuilder(
    column: $table.comparisonShowPilgrimName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get comparisonPilgrimName => $composableBuilder(
    column: $table.comparisonPilgrimName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customThemeColorName => $composableBuilder(
    column: $table.customThemeColorName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get customThemeColorValue => $composableBuilder(
    column: $table.customThemeColorValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customThemeColorsJson => $composableBuilder(
    column: $table.customThemeColorsJson,
    builder: (column) => column,
  );

  GeneratedColumn<double> get customCameraAspectRatioWidth =>
      $composableBuilder(
        column: $table.customCameraAspectRatioWidth,
        builder: (column) => column,
      );

  GeneratedColumn<double> get customCameraAspectRatioHeight =>
      $composableBuilder(
        column: $table.customCameraAspectRatioHeight,
        builder: (column) => column,
      );
}

class $$AppSettingsEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsEntriesTable,
          AppSettingsEntry,
          $$AppSettingsEntriesTableFilterComposer,
          $$AppSettingsEntriesTableOrderingComposer,
          $$AppSettingsEntriesTableAnnotationComposer,
          $$AppSettingsEntriesTableCreateCompanionBuilder,
          $$AppSettingsEntriesTableUpdateCompanionBuilder,
          (
            AppSettingsEntry,
            BaseReferences<
              _$AppDatabase,
              $AppSettingsEntriesTable,
              AppSettingsEntry
            >,
          ),
          AppSettingsEntry,
          PrefetchHooks Function()
        > {
  $$AppSettingsEntriesTableTableManager(
    _$AppDatabase db,
    $AppSettingsEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<double> uiScale = const Value.absent(),
                Value<double> fontScale = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<String> cameraAspectRatio = const Value.absent(),
                Value<String> cameraCaptureAspectRatio = const Value.absent(),
                Value<double> cameraMinZoom = const Value.absent(),
                Value<double> cameraMaxZoom = const Value.absent(),
                Value<double> referenceImageScale = const Value.absent(),
                Value<double> nearestAssignDistanceMeters =
                    const Value.absent(),
                Value<String> themePalette = const Value.absent(),
                Value<String> mapTileProvider = const Value.absent(),
                Value<String> openFreeMapStyle = const Value.absent(),
                Value<String> anitabiImageSource = const Value.absent(),
                Value<String> navigationApp = const Value.absent(),
                Value<String> customXyzTileUrl = const Value.absent(),
                Value<String> customMapLibreStyleUrl = const Value.absent(),
                Value<bool> saveVisitPhotoToGallery = const Value.absent(),
                Value<bool> autoSaveComparisonToGallery = const Value.absent(),
                Value<bool> comparisonShowPilgrimName = const Value.absent(),
                Value<String> comparisonPilgrimName = const Value.absent(),
                Value<String> customThemeColorName = const Value.absent(),
                Value<int> customThemeColorValue = const Value.absent(),
                Value<String> customThemeColorsJson = const Value.absent(),
                Value<double> customCameraAspectRatioWidth =
                    const Value.absent(),
                Value<double> customCameraAspectRatioHeight =
                    const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsEntriesCompanion(
                id: id,
                uiScale: uiScale,
                fontScale: fontScale,
                themeMode: themeMode,
                cameraAspectRatio: cameraAspectRatio,
                cameraCaptureAspectRatio: cameraCaptureAspectRatio,
                cameraMinZoom: cameraMinZoom,
                cameraMaxZoom: cameraMaxZoom,
                referenceImageScale: referenceImageScale,
                nearestAssignDistanceMeters: nearestAssignDistanceMeters,
                themePalette: themePalette,
                mapTileProvider: mapTileProvider,
                openFreeMapStyle: openFreeMapStyle,
                anitabiImageSource: anitabiImageSource,
                navigationApp: navigationApp,
                customXyzTileUrl: customXyzTileUrl,
                customMapLibreStyleUrl: customMapLibreStyleUrl,
                saveVisitPhotoToGallery: saveVisitPhotoToGallery,
                autoSaveComparisonToGallery: autoSaveComparisonToGallery,
                comparisonShowPilgrimName: comparisonShowPilgrimName,
                comparisonPilgrimName: comparisonPilgrimName,
                customThemeColorName: customThemeColorName,
                customThemeColorValue: customThemeColorValue,
                customThemeColorsJson: customThemeColorsJson,
                customCameraAspectRatioWidth: customCameraAspectRatioWidth,
                customCameraAspectRatioHeight: customCameraAspectRatioHeight,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<double> uiScale = const Value.absent(),
                Value<double> fontScale = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<String> cameraAspectRatio = const Value.absent(),
                Value<String> cameraCaptureAspectRatio = const Value.absent(),
                Value<double> cameraMinZoom = const Value.absent(),
                Value<double> cameraMaxZoom = const Value.absent(),
                Value<double> referenceImageScale = const Value.absent(),
                Value<double> nearestAssignDistanceMeters =
                    const Value.absent(),
                Value<String> themePalette = const Value.absent(),
                Value<String> mapTileProvider = const Value.absent(),
                Value<String> openFreeMapStyle = const Value.absent(),
                Value<String> anitabiImageSource = const Value.absent(),
                Value<String> navigationApp = const Value.absent(),
                Value<String> customXyzTileUrl = const Value.absent(),
                Value<String> customMapLibreStyleUrl = const Value.absent(),
                Value<bool> saveVisitPhotoToGallery = const Value.absent(),
                Value<bool> autoSaveComparisonToGallery = const Value.absent(),
                Value<bool> comparisonShowPilgrimName = const Value.absent(),
                Value<String> comparisonPilgrimName = const Value.absent(),
                Value<String> customThemeColorName = const Value.absent(),
                Value<int> customThemeColorValue = const Value.absent(),
                Value<String> customThemeColorsJson = const Value.absent(),
                Value<double> customCameraAspectRatioWidth =
                    const Value.absent(),
                Value<double> customCameraAspectRatioHeight =
                    const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsEntriesCompanion.insert(
                id: id,
                uiScale: uiScale,
                fontScale: fontScale,
                themeMode: themeMode,
                cameraAspectRatio: cameraAspectRatio,
                cameraCaptureAspectRatio: cameraCaptureAspectRatio,
                cameraMinZoom: cameraMinZoom,
                cameraMaxZoom: cameraMaxZoom,
                referenceImageScale: referenceImageScale,
                nearestAssignDistanceMeters: nearestAssignDistanceMeters,
                themePalette: themePalette,
                mapTileProvider: mapTileProvider,
                openFreeMapStyle: openFreeMapStyle,
                anitabiImageSource: anitabiImageSource,
                navigationApp: navigationApp,
                customXyzTileUrl: customXyzTileUrl,
                customMapLibreStyleUrl: customMapLibreStyleUrl,
                saveVisitPhotoToGallery: saveVisitPhotoToGallery,
                autoSaveComparisonToGallery: autoSaveComparisonToGallery,
                comparisonShowPilgrimName: comparisonShowPilgrimName,
                comparisonPilgrimName: comparisonPilgrimName,
                customThemeColorName: customThemeColorName,
                customThemeColorValue: customThemeColorValue,
                customThemeColorsJson: customThemeColorsJson,
                customCameraAspectRatioWidth: customCameraAspectRatioWidth,
                customCameraAspectRatioHeight: customCameraAspectRatioHeight,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsEntriesTable,
      AppSettingsEntry,
      $$AppSettingsEntriesTableFilterComposer,
      $$AppSettingsEntriesTableOrderingComposer,
      $$AppSettingsEntriesTableAnnotationComposer,
      $$AppSettingsEntriesTableCreateCompanionBuilder,
      $$AppSettingsEntriesTableUpdateCompanionBuilder,
      (
        AppSettingsEntry,
        BaseReferences<
          _$AppDatabase,
          $AppSettingsEntriesTable,
          AppSettingsEntry
        >,
      ),
      AppSettingsEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PlansTableTableManager get plans =>
      $$PlansTableTableManager(_db, _db.plans);
  $$PlanGroupsTableTableManager get planGroups =>
      $$PlanGroupsTableTableManager(_db, _db.planGroups);
  $$WorksTableTableManager get works =>
      $$WorksTableTableManager(_db, _db.works);
  $$PointsTableTableManager get points =>
      $$PointsTableTableManager(_db, _db.points);
  $$VisitRecordsTableTableManager get visitRecords =>
      $$VisitRecordsTableTableManager(_db, _db.visitRecords);
  $$AppSettingsEntriesTableTableManager get appSettingsEntries =>
      $$AppSettingsEntriesTableTableManager(_db, _db.appSettingsEntries);
}
