// ignore_for_file: avoid_print

import 'dart:io';

Future<void> formatGeneratedCode() async {
  print('🎨 Formatting generated code...');

  final formatResult = await Process.run('dart', [
    'format',
    'lib/features',
    'lib/core',
    'lib/presentation',
    'lib/injection.dart',
  ], runInShell: true);

  if (formatResult.exitCode != 0) {
    stderr.write(formatResult.stderr);
    throw Exception('Failed to format code');
  }

  stdout.write(formatResult.stdout);
  print('✅ Code formatted successfully');

  print('🛠 Applying dart fixes...');
  final fixResult = await Process.run('dart', [
    'fix',
    '--apply',
  ], runInShell: true);

  if (fixResult.exitCode != 0) {
    stderr.write(fixResult.stderr);
    throw Exception('Failed to apply dart fixes');
  }

  stdout.write(fixResult.stdout);
  print('✅ Dart fixes applied successfully\n');
}
