import 'dart:async';

import 'package:kangoos_core/kangoos_core.dart';

import '../runtime/runtime_service.dart';

const defaultCompactionLookback = Duration(days: 14);

class MemoryCompactionService implements RuntimeService {
  MemoryCompactionService({
    required this.hierarchy,
    this.interval = const Duration(hours: 6),
    this.lookback = defaultCompactionLookback,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final MemoryHierarchyService hierarchy;
  final Duration interval;
  final Duration lookback;
  final DateTime Function() now;
  Timer? _timer;
  bool _running = false;

  @override
  Future<void> start() async {
    if (_timer != null) return;
    await tick();
    _timer = Timer.periodic(interval, (_) => tick());
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  Future<HierarchyCompactionReport?> tick() async {
    if (_running) return null;
    _running = true;
    try {
      final current = now();
      final today = current.isUtc
          ? DateTime.utc(current.year, current.month, current.day)
          : DateTime(current.year, current.month, current.day);
      final rawStart = today.subtract(lookback);
      final start = rawStart.subtract(
        Duration(days: rawStart.weekday - DateTime.monday),
      );
      return hierarchy.compact(start, today);
    } finally {
      _running = false;
    }
  }
}
