// ignore_for_file: avoid_print

import 'dart:io';

void main() {
  generateCleanArchitectureFolders();
}

void generateCleanArchitectureFolders() {
  const coreFolders = [
    'lib/core',
    'lib/core/common',
    'lib/core/database',
    'lib/core/error',
    'lib/core/theme',
    'lib/core/utils',
  ];

  for (final path in coreFolders) {
    Directory(path).createSync(recursive: true);
  }

  stdout.write('Enter the number of features: ');
  final featureCountInput = stdin.readLineSync();
  final featureCount = int.tryParse(featureCountInput ?? '0') ?? 0;

  final existingFeatures = <String>{};

  for (int i = 1; i <= featureCount; i++) {
    stdout.write('Enter the name of feature #$i: ');
    final featureName = stdin.readLineSync()?.trim();

    if (featureName == null || featureName.isEmpty) {
      print('Feature name cannot be empty. Skipping this feature.');
      continue;
    }

    if (existingFeatures.contains(featureName) ||
        Directory('lib/features/$featureName').existsSync()) {
      print(
        '⚠ Feature name "$featureName" already exists. Skipping this feature.',
      );
      continue;
    }

    existingFeatures.add(featureName);

    final featureFolders = [
      'lib/features/$featureName',
      'lib/features/$featureName/data',
      'lib/features/$featureName/data/datasources',
      'lib/features/$featureName/data/models',
      'lib/features/$featureName/data/repositories',
      'lib/features/$featureName/domain',
      'lib/features/$featureName/domain/entities',
      'lib/features/$featureName/domain/repositories',
      'lib/features/$featureName/domain/usecases',
      'lib/features/$featureName/presentation',
      'lib/features/$featureName/presentation/state',
      'lib/features/$featureName/presentation/pages',
      'lib/features/$featureName/presentation/widgets',
    ];

    for (final path in featureFolders) {
      Directory(path).createSync(recursive: true);
    }

    print('✅ Folder structure for feature "$featureName" created.');
  }

  print('✅ All Clean Architecture folders have been created.');
}
