import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final drawerControllerProvider = Provider<GlobalKey<ScaffoldState>>((ref) {
  return GlobalKey<ScaffoldState>();
});

void openDrawer(WidgetRef ref) {
  final key = ref.read(drawerControllerProvider);
  key.currentState?.openDrawer();
}
