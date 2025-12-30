// ignore_for_file: avoid_print

import 'dart:io';

Future<void> installDependencies(List<String> packages) async {
  print('📦 Installing dependencies...');

  final result = await Process.run('flutter', [
    'pub',
    'add',
    ...packages,
  ], runInShell: true);

  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    throw Exception('Failed to install dependencies');
  }

  stdout.write(result.stdout);
  print('✅ Dependencies installed successfully\n');
}
