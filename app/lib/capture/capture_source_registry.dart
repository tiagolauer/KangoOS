import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'window_snapshot.dart';

enum CaptureModality {
  metadata,
  clipboard,
  browser,
  visibleText,
  screenText,
  audio,
}

class CaptureSource {
  const CaptureSource({
    required this.id,
    required this.name,
    this.enabled = false,
    this.blocked = false,
    this.lastCapturedAt,
    this.modalities = const {},
  });

  final String id;
  final String name;
  final bool enabled;
  final bool blocked;
  final DateTime? lastCapturedAt;
  final Set<CaptureModality> modalities;

  bool get canCapture => enabled && !blocked;

  CaptureSource copyWith({
    String? name,
    bool? enabled,
    bool? blocked,
    DateTime? lastCapturedAt,
    Set<CaptureModality>? modalities,
  }) =>
      CaptureSource(
        id: id,
        name: name ?? this.name,
        enabled: enabled ?? this.enabled,
        blocked: blocked ?? this.blocked,
        lastCapturedAt: lastCapturedAt ?? this.lastCapturedAt,
        modalities: modalities ?? this.modalities,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'blocked': blocked,
        'lastCapturedAt': lastCapturedAt?.toUtc().toIso8601String(),
        'modalities': modalities.map((modality) => modality.name).toList(),
      };

  factory CaptureSource.fromJson(Map<String, Object?> json) {
    final modalityNames = (json['modalities'] as List<Object?>? ?? const [])
        .whereType<String>()
        .toSet();
    return CaptureSource(
      id: json['id'] as String,
      name: json['name'] as String,
      enabled: json['enabled'] as bool? ?? false,
      blocked: json['blocked'] as bool? ?? false,
      lastCapturedAt: switch (json['lastCapturedAt']) {
        final String value => DateTime.tryParse(value)?.toLocal(),
        _ => null,
      },
      modalities: CaptureModality.values
          .where((modality) => modalityNames.contains(modality.name))
          .toSet(),
    );
  }
}

class CaptureSourceRegistry {
  static const _sourcesKey = 'capture_known_sources_v1';

  Future<void> _pendingMutation = Future.value();

  Future<List<CaptureSource>> list() async {
    await _pendingMutation;
    return _read();
  }

  Future<CaptureSource> observe(WindowSnapshot snapshot) => _mutate(() async {
        final sources = await _read();
        final index =
            sources.indexWhere((source) => source.id == snapshot.appId);
        if (index == -1) {
          final source =
              CaptureSource(id: snapshot.appId, name: snapshot.appName);
          sources.add(source);
          await _write(sources);
          return source;
        }
        final current = sources[index];
        if (current.name == snapshot.appName) return current;
        final updated = current.copyWith(name: snapshot.appName);
        sources[index] = updated;
        await _write(sources);
        return updated;
      });

  Future<void> setEnabled(String id, bool enabled) =>
      _update(id, (source) => source.copyWith(enabled: enabled));

  Future<void> setBlocked(String id, bool blocked) =>
      _update(id, (source) => source.copyWith(blocked: blocked));

  Future<void> markCaptured(
    String id,
    DateTime capturedAt,
    Set<CaptureModality> modalities,
  ) =>
      _update(
        id,
        (source) => source.copyWith(
          lastCapturedAt: source.lastCapturedAt?.isAfter(capturedAt) == true
              ? source.lastCapturedAt
              : capturedAt,
          modalities: {...source.modalities, ...modalities},
        ),
      );

  Future<void> _update(
    String id,
    CaptureSource Function(CaptureSource source) update,
  ) =>
      _mutate(() async {
        final sources = await _read();
        final index = sources.indexWhere((source) => source.id == id);
        if (index == -1) throw StateError('Unknown capture source: $id');
        sources[index] = update(sources[index]);
        await _write(sources);
      });

  Future<List<CaptureSource>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_sourcesKey);
    if (encoded == null) return [];
    final decoded = jsonDecode(encoded) as List<Object?>;
    final sources = decoded
        .map(
          (entry) => CaptureSource.fromJson(
            (entry as Map<Object?, Object?>).cast<String, Object?>(),
          ),
        )
        .toList();
    sources.sort((left, right) => left.name.compareTo(right.name));
    return sources;
  }

  Future<void> _write(List<CaptureSource> sources) async {
    sources.sort((left, right) => left.name.compareTo(right.name));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _sourcesKey,
      jsonEncode(sources.map((source) => source.toJson()).toList()),
    );
  }

  Future<T> _mutate<T>(Future<T> Function() mutation) {
    final result = Completer<T>();
    _pendingMutation = _pendingMutation.then((_) async {
      try {
        result.complete(await mutation());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }
}
