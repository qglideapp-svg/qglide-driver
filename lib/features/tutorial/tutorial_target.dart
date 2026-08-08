import 'package:flutter/material.dart';

import 'tutorial_target_registry.dart';

/// Wraps a widget with a [GlobalKey] used as a coach-mark spotlight target.
class TutorialTarget extends StatelessWidget {
  const TutorialTarget({
    super.key,
    required this.registry,
    required this.id,
    required this.child,
  });

  final TutorialTargetRegistry registry;
  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: registry.keyFor(id),
      child: child,
    );
  }
}
