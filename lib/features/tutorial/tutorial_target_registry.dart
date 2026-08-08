import 'package:flutter/material.dart';

/// Holds [GlobalKey]s for coach-mark targets on a single screen.
class TutorialTargetRegistry {
  TutorialTargetRegistry();

  final Map<String, GlobalKey> _keys = {};

  GlobalKey keyFor(String id) {
    return _keys.putIfAbsent(id, GlobalKey.new);
  }

  GlobalKey? tryKey(String id) => _keys[id];
}
