// ignore_for_file: avoid_print

import 'dart:io';

String getPackageName() {
  final pubspec = File('pubspec.yaml');

  if (!pubspec.existsSync()) {
    print('❌ pubspec.yaml not found');
    exit(1);
  }

  final lines = pubspec.readAsLinesSync();

  for (final line in lines) {
    if (line.startsWith('name:')) {
      return line.replaceFirst('name:', '').trim();
    }
  }

  print('❌ Package name not found in pubspec.yaml');
  exit(1);
}
