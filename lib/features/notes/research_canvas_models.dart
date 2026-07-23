import 'package:uuid/uuid.dart';

enum ResearchCanvasItemType { note, text, group }

class ResearchCanvasItem {
  const ResearchCanvasItem({
    required this.id,
    required this.type,
    required this.title,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.colorValue,
    this.noteId,
    this.body = '',
  });

  static const double minX = 24;
  static const double minY = 24;
  static const double maxX = 3300;
  static const double maxY = 2200;
  static const double minWidth = 180;
  static const double minHeight = 110;
  static const double maxWidth = 920;
  static const double maxHeight = 720;

  final String id;
  final ResearchCanvasItemType type;
  final String? noteId;
  final String title;
  final String body;
  final double x;
  final double y;
  final double width;
  final double height;
  final int colorValue;

  bool get isGroup => type == ResearchCanvasItemType.group;

  ResearchCanvasItem copyWith({
    String? id,
    ResearchCanvasItemType? type,
    String? noteId,
    bool clearNoteId = false,
    String? title,
    String? body,
    double? x,
    double? y,
    double? width,
    double? height,
    int? colorValue,
  }) {
    return ResearchCanvasItem.normalized(
      id: id ?? this.id,
      type: type ?? this.type,
      noteId: clearNoteId ? null : noteId ?? this.noteId,
      title: title ?? this.title,
      body: body ?? this.body,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  factory ResearchCanvasItem.normalized({
    required String id,
    required ResearchCanvasItemType type,
    String? noteId,
    required String title,
    String body = '',
    required double x,
    required double y,
    required double width,
    required double height,
    required int colorValue,
  }) {
    final safeType = type;
    final safeTitle = _limit(title.trim(), 120);
    final safeBody = _limit(body.trim(), 4000);
    final safeWidth = width.clamp(minWidth, maxWidth).toDouble();
    final safeHeight = height.clamp(minHeight, maxHeight).toDouble();
    return ResearchCanvasItem(
      id: id.trim(),
      type: safeType,
      noteId: safeType == ResearchCanvasItemType.note ? noteId?.trim() : null,
      title:
          safeTitle.isEmpty
              ? switch (safeType) {
                ResearchCanvasItemType.note => 'Заметка',
                ResearchCanvasItemType.text => 'Карточка',
                ResearchCanvasItemType.group => 'Область',
              }
              : safeTitle,
      body: safeBody,
      x: x.clamp(minX, maxX - safeWidth).toDouble(),
      y: y.clamp(minY, maxY - safeHeight).toDouble(),
      width: safeWidth,
      height: safeHeight,
      colorValue: _safeColorValue(colorValue),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'type': type.name,
    'noteId': noteId,
    'title': title,
    'body': body,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'colorValue': colorValue,
  };

  static ResearchCanvasItem? fromJson(Map<String, Object?> json) {
    final id = json['id']?.toString().trim() ?? '';
    if (id.isEmpty) return null;
    final rawType = json['type']?.toString();
    final type =
        ResearchCanvasItemType.values
            .where((value) => value.name == rawType)
            .firstOrNull;
    if (type == null) return null;
    final item = ResearchCanvasItem.normalized(
      id: id,
      type: type,
      noteId: json['noteId']?.toString(),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      x: _readDouble(json['x'], fallback: 120),
      y: _readDouble(json['y'], fallback: 120),
      width: _readDouble(
        json['width'],
        fallback: type == ResearchCanvasItemType.group ? 560 : 260,
      ),
      height: _readDouble(
        json['height'],
        fallback: type == ResearchCanvasItemType.group ? 360 : 170,
      ),
      colorValue: _readInt(json['colorValue'], fallback: 0xFF6750A4),
    );
    if (item.type == ResearchCanvasItemType.note &&
        (item.noteId == null || item.noteId!.isEmpty)) {
      return null;
    }
    return item;
  }
}

class ResearchCanvasConnection {
  const ResearchCanvasConnection({
    required this.id,
    required this.sourceItemId,
    required this.targetItemId,
    this.label = '',
  });

  final String id;
  final String sourceItemId;
  final String targetItemId;
  final String label;

  ResearchCanvasConnection copyWith({String? label}) {
    return ResearchCanvasConnection(
      id: id,
      sourceItemId: sourceItemId,
      targetItemId: targetItemId,
      label: _limit(label ?? this.label, 80),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'sourceItemId': sourceItemId,
    'targetItemId': targetItemId,
    'label': label,
  };

  static ResearchCanvasConnection? fromJson(Map<String, Object?> json) {
    final id = json['id']?.toString().trim() ?? '';
    final source = json['sourceItemId']?.toString().trim() ?? '';
    final target = json['targetItemId']?.toString().trim() ?? '';
    if (id.isEmpty || source.isEmpty || target.isEmpty || source == target) {
      return null;
    }
    return ResearchCanvasConnection(
      id: id,
      sourceItemId: source,
      targetItemId: target,
      label: _limit(json['label']?.toString().trim() ?? '', 80),
    );
  }
}

class ResearchCanvas {
  const ResearchCanvas({
    required this.id,
    required this.name,
    required this.emoji,
    required this.items,
    required this.connections,
    required this.updatedAt,
    this.projectId,
  });

  static const int maxCanvases = 12;
  static const int maxItems = 240;
  static const int maxConnections = 480;

  final String id;
  final String name;
  final String emoji;
  final String? projectId;
  final List<ResearchCanvasItem> items;
  final List<ResearchCanvasConnection> connections;
  final DateTime updatedAt;

  static ResearchCanvas empty({
    required String id,
    String name = 'Исследование',
    String emoji = '🧭',
    String? projectId,
  }) {
    return ResearchCanvas(
      id: id,
      name: name,
      emoji: emoji,
      projectId: projectId,
      items: const <ResearchCanvasItem>[],
      connections: const <ResearchCanvasConnection>[],
      updatedAt: DateTime.now(),
    );
  }

  ResearchCanvas copyWith({
    String? id,
    String? name,
    String? emoji,
    String? projectId,
    bool clearProjectId = false,
    List<ResearchCanvasItem>? items,
    List<ResearchCanvasConnection>? connections,
    DateTime? updatedAt,
  }) {
    return ResearchCanvas.normalized(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      projectId: clearProjectId ? null : projectId ?? this.projectId,
      items: items ?? this.items,
      connections: connections ?? this.connections,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  ResearchCanvasItem? itemById(String itemId) {
    for (final item in items) {
      if (item.id == itemId) return item;
    }
    return null;
  }

  bool containsNote(String noteId) {
    return items.any(
      (item) =>
          item.type == ResearchCanvasItemType.note && item.noteId == noteId,
    );
  }

  factory ResearchCanvas.normalized({
    required String id,
    required String name,
    required String emoji,
    String? projectId,
    required Iterable<ResearchCanvasItem> items,
    required Iterable<ResearchCanvasConnection> connections,
    DateTime? updatedAt,
  }) {
    final safeItems = <ResearchCanvasItem>[];
    final itemIds = <String>{};
    for (final item in items) {
      if (safeItems.length >= maxItems || !itemIds.add(item.id)) continue;
      safeItems.add(item);
    }
    final itemIdSet = safeItems.map((item) => item.id).toSet();
    final safeConnections = <ResearchCanvasConnection>[];
    final connectionKeys = <String>{};
    for (final connection in connections) {
      if (safeConnections.length >= maxConnections ||
          !itemIdSet.contains(connection.sourceItemId) ||
          !itemIdSet.contains(connection.targetItemId)) {
        continue;
      }
      final key = '${connection.sourceItemId}\u0000${connection.targetItemId}';
      if (!connectionKeys.add(key)) continue;
      safeConnections.add(connection);
    }
    final safeName = _limit(name.trim(), 64);
    final safeEmoji = _limit(emoji.trim(), 8);
    return ResearchCanvas(
      id: id.trim(),
      name: safeName.isEmpty ? 'Исследование' : safeName,
      emoji: safeEmoji.isEmpty ? '🧭' : safeEmoji,
      projectId: projectId?.trim().isEmpty == true ? null : projectId?.trim(),
      items: List<ResearchCanvasItem>.unmodifiable(safeItems),
      connections: List<ResearchCanvasConnection>.unmodifiable(safeConnections),
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  ResearchCanvas duplicate({required String newId}) {
    const uuid = Uuid();
    final itemIdMap = <String, String>{
      for (final item in items) item.id: uuid.v4(),
    };
    return ResearchCanvas.normalized(
      id: newId,
      name: _copyName(name),
      emoji: emoji,
      projectId: projectId,
      items: <ResearchCanvasItem>[
        for (final item in items)
          item.copyWith(id: itemIdMap[item.id], x: item.x + 24, y: item.y + 24),
      ],
      connections: <ResearchCanvasConnection>[
        for (final connection in connections)
          ResearchCanvasConnection(
            id: uuid.v4(),
            sourceItemId: itemIdMap[connection.sourceItemId]!,
            targetItemId: itemIdMap[connection.targetItemId]!,
            label: connection.label,
          ),
      ],
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'emoji': emoji,
    'projectId': projectId,
    'items': items.map((item) => item.toJson()).toList(growable: false),
    'connections': connections
        .map((connection) => connection.toJson())
        .toList(growable: false),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static ResearchCanvas? fromJson(Map<String, Object?> json) {
    final id = json['id']?.toString().trim() ?? '';
    if (id.isEmpty) return null;
    final items = <ResearchCanvasItem>[];
    final rawItems = json['items'];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is! Map) continue;
        final item = ResearchCanvasItem.fromJson(<String, Object?>{
          for (final entry in raw.entries) entry.key.toString(): entry.value,
        });
        if (item != null) items.add(item);
      }
    }
    final connections = <ResearchCanvasConnection>[];
    final rawConnections = json['connections'];
    if (rawConnections is List) {
      for (final raw in rawConnections) {
        if (raw is! Map) continue;
        final connection = ResearchCanvasConnection.fromJson(<String, Object?>{
          for (final entry in raw.entries) entry.key.toString(): entry.value,
        });
        if (connection != null) connections.add(connection);
      }
    }
    return ResearchCanvas.normalized(
      id: id,
      name: json['name']?.toString() ?? '',
      emoji: json['emoji']?.toString() ?? '',
      projectId: json['projectId']?.toString(),
      items: items,
      connections: connections,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }
}

class ResearchCanvasPreferences {
  const ResearchCanvasPreferences({
    required this.activeCanvasId,
    required this.canvases,
  });

  final String activeCanvasId;
  final List<ResearchCanvas> canvases;

  factory ResearchCanvasPreferences.defaults() {
    final canvas = ResearchCanvas.empty(id: 'research-default');
    return ResearchCanvasPreferences(
      activeCanvasId: canvas.id,
      canvases: <ResearchCanvas>[canvas],
    );
  }

  ResearchCanvas get activeCanvas {
    for (final canvas in canvases) {
      if (canvas.id == activeCanvasId) return canvas;
    }
    return canvases.first;
  }

  ResearchCanvasPreferences copyWith({
    String? activeCanvasId,
    List<ResearchCanvas>? canvases,
  }) {
    return ResearchCanvasPreferences.normalized(
      activeCanvasId: activeCanvasId ?? this.activeCanvasId,
      canvases: canvases ?? this.canvases,
    );
  }

  ResearchCanvasPreferences replaceCanvas(ResearchCanvas canvas) {
    final next = <ResearchCanvas>[
      for (final current in canvases)
        if (current.id == canvas.id) canvas else current,
    ];
    if (!next.any((current) => current.id == canvas.id)) {
      next.add(canvas);
    }
    return copyWith(canvases: next);
  }

  factory ResearchCanvasPreferences.normalized({
    required String activeCanvasId,
    required Iterable<ResearchCanvas> canvases,
  }) {
    final safe = <ResearchCanvas>[];
    final ids = <String>{};
    for (final canvas in canvases) {
      if (safe.length >= ResearchCanvas.maxCanvases ||
          canvas.id.isEmpty ||
          !ids.add(canvas.id)) {
        continue;
      }
      safe.add(canvas);
    }
    if (safe.isEmpty) return ResearchCanvasPreferences.defaults();
    final active =
        ids.contains(activeCanvasId) ? activeCanvasId : safe.first.id;
    return ResearchCanvasPreferences(
      activeCanvasId: active,
      canvases: List<ResearchCanvas>.unmodifiable(safe),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'activeCanvasId': activeCanvasId,
    'canvases': canvases
        .map((canvas) => canvas.toJson())
        .toList(growable: false),
  };

  static ResearchCanvasPreferences fromJson(Map<String, Object?> json) {
    final canvases = <ResearchCanvas>[];
    final rawCanvases = json['canvases'];
    if (rawCanvases is List) {
      for (final raw in rawCanvases) {
        if (raw is! Map) continue;
        final canvas = ResearchCanvas.fromJson(<String, Object?>{
          for (final entry in raw.entries) entry.key.toString(): entry.value,
        });
        if (canvas != null) canvases.add(canvas);
      }
    }
    return ResearchCanvasPreferences.normalized(
      activeCanvasId: json['activeCanvasId']?.toString() ?? '',
      canvases: canvases,
    );
  }
}

double _readDouble(Object? value, {required double fallback}) {
  if (value is num && value.isFinite) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

int _safeColorValue(int value) {
  if (value < 0 || value > 0xFFFFFFFF) return 0xFF6750A4;
  return value;
}

int _readInt(Object? value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String _limit(String value, int maxLength) {
  return value.length <= maxLength ? value : value.substring(0, maxLength);
}

String _copyName(String name) {
  final base = name.trim().isEmpty ? 'Исследование' : name.trim();
  return _limit('Копия — $base', 64);
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
