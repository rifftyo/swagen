// ignore_for_file: avoid_print

import 'dart:io';

Future<void> formatGeneratedCode() async {
  print('🎨 Formatting generated code...');

  final result = await Process.run('dart', [
    'format',
    'lib/features',
    'lib/core',
  ], runInShell: true);

  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    throw Exception('Failed to format code');
  }

  stdout.write(result.stdout);
  print('✅ Code formatted successfully\n');
}
